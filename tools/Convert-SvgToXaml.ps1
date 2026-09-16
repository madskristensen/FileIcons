[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$InputPath,

    [Parameter(Mandatory)]
    [string]$OutputDirectory,

    [string[]]$Names,

    [hashtable]$NameMap = @{},

    [switch]$Force,

    [string]$CatalogPath,

    [string]$SourceBaseUrl,

    [string]$License
)

$ErrorActionPreference = "Stop"
$invariant = [System.Globalization.CultureInfo]::InvariantCulture

if ($CatalogPath -and (-not $SourceBaseUrl -or -not $License)) {
    throw "Catalog migration requires both -SourceBaseUrl and -License."
}
if (($SourceBaseUrl -or $License) -and -not $CatalogPath) {
    throw "-SourceBaseUrl and -License can only be used with -CatalogPath."
}

function Get-Style {
    param(
        [System.Xml.XmlElement]$Element,
        [hashtable]$Inherited
    )

    $style = @{}
    foreach ($key in $Inherited.Keys) {
        $style[$key] = $Inherited[$key]
    }

    foreach ($name in "fill", "fill-rule", "fill-opacity", "opacity", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin", "stroke-opacity") {
        if ($Element.HasAttribute($name)) {
            $style[$name] = $Element.GetAttribute($name)
        }
    }

    if ($Element.HasAttribute("style")) {
        foreach ($declaration in $Element.GetAttribute("style").Split(";")) {
            $parts = $declaration.Split(":", 2)
            if ($parts.Count -eq 2) {
                $style[$parts[0].Trim()] = $parts[1].Trim()
            }
        }
    }

    return $style
}

function Convert-Number {
    param([string]$Value)

    return [double]::Parse($Value, [System.Globalization.NumberStyles]::Float, $invariant)
}

function Format-Number {
    param([double]$Value)

    return $Value.ToString("0.################", $invariant)
}

function Escape-Xml {
    param([string]$Value)

    return [System.Security.SecurityElement]::Escape($Value)
}

function Get-TransformLines {
    param(
        [string]$Transform,
        [string]$ElementName
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $remaining = $Transform.Trim()
    while ($remaining) {
        if ($remaining -notmatch "^(translate|rotate)\s*\(([^)]*)\)\s*(.*)$") {
            throw "$ElementName uses unsupported transform='$Transform'."
        }

        $operation = $Matches[1]
        $values = @($Matches[2] -split "[,\s]+" | Where-Object { $_ })
        $remaining = $Matches[3].Trim()
        switch ($operation) {
            "translate" {
                if ($values.Count -lt 1 -or $values.Count -gt 2) {
                    throw "$ElementName uses invalid translate transform='$Transform'."
                }
                $x = Format-Number (Convert-Number $values[0])
                $y = if ($values.Count -eq 2) { Format-Number (Convert-Number $values[1]) } else { "0" }
                $lines.Add("<TranslateTransform X=`"$x`" Y=`"$y`" />")
            }
            "rotate" {
                if ($values.Count -notin 1, 3) {
                    throw "$ElementName uses invalid rotate transform='$Transform'."
                }
                $angle = Format-Number (Convert-Number $values[0])
                if ($values.Count -eq 3) {
                    $centerX = Format-Number (Convert-Number $values[1])
                    $centerY = Format-Number (Convert-Number $values[2])
                    $lines.Add("<RotateTransform Angle=`"$angle`" CenterX=`"$centerX`" CenterY=`"$centerY`" />")
                }
                else {
                    $lines.Add("<RotateTransform Angle=`"$angle`" />")
                }
            }
        }
    }

    return ,$lines
}

function Get-ShapeAttributes {
    param(
        [hashtable]$Style,
        [string]$ElementName
    )

    $attributes = [System.Collections.Generic.List[string]]::new()
    $fill = if ($Style.ContainsKey("fill")) { $Style["fill"] } else { "#000000" }
    $stroke = if ($Style.ContainsKey("stroke")) { $Style["stroke"] } else { $null }

    if ($fill -match "^url\(" -or $stroke -match "^url\(") {
        throw "$ElementName uses a paint server, which is not supported."
    }

    if ($fill -and $fill -ne "none") {
        $attributes.Add("Fill=`"$(Escape-Xml $fill)`"")
    }

    if ($stroke -and $stroke -ne "none") {
        $attributes.Add("Stroke=`"$(Escape-Xml $stroke)`"")
    }

    if ($Style.ContainsKey("stroke-width")) {
        $attributes.Add("StrokeThickness=`"$(Escape-Xml $Style["stroke-width"])`"")
    }

    if ($Style.ContainsKey("stroke-linecap")) {
        $lineCap = switch ($Style["stroke-linecap"]) {
            "butt" { "Flat" }
            "round" { "Round" }
            "square" { "Square" }
            default { throw "$ElementName uses unsupported stroke-linecap '$($Style["stroke-linecap"])'." }
        }
        $attributes.Add("StrokeStartLineCap=`"$lineCap`"")
        $attributes.Add("StrokeEndLineCap=`"$lineCap`"")
    }

    if ($Style.ContainsKey("stroke-linejoin")) {
        $lineJoin = switch ($Style["stroke-linejoin"]) {
            "miter" { "Miter" }
            "round" { "Round" }
            "bevel" { "Bevel" }
            default { throw "$ElementName uses unsupported stroke-linejoin '$($Style["stroke-linejoin"])'." }
        }
        $attributes.Add("StrokeLineJoin=`"$lineJoin`"")
    }

    $opacity = 1.0
    foreach ($name in "opacity", "fill-opacity") {
        if ($Style.ContainsKey($name)) {
            $opacity *= Convert-Number $Style[$name]
        }
    }

    if ($Style.ContainsKey("stroke-opacity") -and $stroke -and $stroke -ne "none") {
        throw "$ElementName uses stroke-opacity, which is not supported independently."
    }

    if ($opacity -ne 1.0) {
        $attributes.Add("Opacity=`"$(Format-Number $opacity)`"")
    }

    return ,$attributes
}

function Convert-Element {
    param(
        [System.Xml.XmlElement]$Element,
        [hashtable]$InheritedStyle,
        [System.Collections.Generic.List[string]]$Lines
    )

    if ($Element.HasAttribute("transform") -and $Element.LocalName -ne "ellipse") {
        throw "$($Element.LocalName) uses transform='$($Element.GetAttribute("transform"))', which is not supported."
    }

    if ($Element.HasAttribute("class")) {
        throw "$($Element.LocalName) uses a CSS class, which must be flattened first."
    }

    $style = Get-Style $Element $InheritedStyle
    switch ($Element.LocalName) {
        "title" { return }
        "defs" { return }
        "g" {
            foreach ($child in $Element.ChildNodes) {
                if ($child -is [System.Xml.XmlElement]) {
                    Convert-Element $child $style $Lines
                }
            }
            return
        }
        "path" {
            $data = $Element.GetAttribute("d")
            if (-not $data) {
                throw "path is missing its d attribute."
            }

            $fillRule = if ($style["fill-rule"] -eq "evenodd") { "F0" } else { "F1" }
            $attributes = Get-ShapeAttributes $style "path"
            $attributes.Insert(0, "Data=`"$(Escape-Xml "$fillRule $data")`"")
            $Lines.Add("    <Path $($attributes -join " ") />")
            return
        }
        "polygon" {
            $points = $Element.GetAttribute("points")
            if (-not $points) {
                throw "polygon is missing its points attribute."
            }

            $attributes = Get-ShapeAttributes $style "polygon"
            $attributes.Insert(0, "Points=`"$(Escape-Xml $points)`"")
            $Lines.Add("    <Polygon $($attributes -join " ") />")
            return
        }
        "rect" {
            foreach ($required in "width", "height") {
                if (-not $Element.HasAttribute($required)) {
                    throw "rect is missing its $required attribute."
                }
            }

            $x = if ($Element.HasAttribute("x")) { $Element.GetAttribute("x") } else { "0" }
            $y = if ($Element.HasAttribute("y")) { $Element.GetAttribute("y") } else { "0" }
            $attributes = Get-ShapeAttributes $style "rect"
            $attributes.Insert(0, "Height=`"$(Escape-Xml $Element.GetAttribute("height"))`"")
            $attributes.Insert(0, "Width=`"$(Escape-Xml $Element.GetAttribute("width"))`"")
            $attributes.Add("Canvas.Left=`"$(Escape-Xml $x)`"")
            $attributes.Add("Canvas.Top=`"$(Escape-Xml $y)`"")
            if ($Element.HasAttribute("rx")) {
                $attributes.Add("RadiusX=`"$(Escape-Xml $Element.GetAttribute("rx"))`"")
            }
            if ($Element.HasAttribute("ry")) {
                $attributes.Add("RadiusY=`"$(Escape-Xml $Element.GetAttribute("ry"))`"")
            }
            elseif ($Element.HasAttribute("rx")) {
                $attributes.Add("RadiusY=`"$(Escape-Xml $Element.GetAttribute("rx"))`"")
            }
            $Lines.Add("    <Rectangle $($attributes -join " ") />")
            return
        }
        "circle" {
            foreach ($required in "cx", "cy", "r") {
                if (-not $Element.HasAttribute($required)) {
                    throw "circle is missing its $required attribute."
                }
            }

            $cx = Convert-Number $Element.GetAttribute("cx")
            $cy = Convert-Number $Element.GetAttribute("cy")
            $radius = Convert-Number $Element.GetAttribute("r")
            $diameter = Format-Number (2 * $radius)
            $attributes = Get-ShapeAttributes $style "circle"
            $attributes.Insert(0, "Height=`"$diameter`"")
            $attributes.Insert(0, "Width=`"$diameter`"")
            $attributes.Add("Canvas.Left=`"$(Format-Number ($cx - $radius))`"")
            $attributes.Add("Canvas.Top=`"$(Format-Number ($cy - $radius))`"")
            $Lines.Add("    <Ellipse $($attributes -join " ") />")
            return
        }
        "ellipse" {
            foreach ($required in "cx", "cy", "rx", "ry") {
                if (-not $Element.HasAttribute($required)) {
                    throw "ellipse is missing its $required attribute."
                }
            }

            $cx = Convert-Number $Element.GetAttribute("cx")
            $cy = Convert-Number $Element.GetAttribute("cy")
            $radiusX = Convert-Number $Element.GetAttribute("rx")
            $radiusY = Convert-Number $Element.GetAttribute("ry")
            $attributes = Get-ShapeAttributes $style "ellipse"
            $attributes.Insert(0, "Height=`"$(Format-Number (2 * $radiusY))`"")
            $attributes.Insert(0, "Width=`"$(Format-Number (2 * $radiusX))`"")
            $attributes.Add("Canvas.Left=`"$(Format-Number ($cx - $radiusX))`"")
            $attributes.Add("Canvas.Top=`"$(Format-Number ($cy - $radiusY))`"")

            if (-not $Element.HasAttribute("transform")) {
                $Lines.Add("    <Ellipse $($attributes -join " ") />")
                return
            }

            $transformLines = Get-TransformLines $Element.GetAttribute("transform") "ellipse"
            $Lines.Add("    <Ellipse $($attributes -join " ")>")
            $Lines.Add("      <Ellipse.RenderTransform>")
            $Lines.Add("        <TransformGroup>")
            foreach ($transformLine in $transformLines) {
                $Lines.Add("          $transformLine")
            }
            $Lines.Add("        </TransformGroup>")
            $Lines.Add("      </Ellipse.RenderTransform>")
            $Lines.Add("    </Ellipse>")
            return
        }
        default {
            throw "Unsupported SVG element '$($Element.LocalName)'."
        }
    }
}

function Convert-File {
    param(
        [System.IO.FileInfo]$File,
        [string]$Destination
    )

    if ($File.BaseName -notlike "file_type_*") {
        throw "Only file_type_*.svg assets are supported. Folder icons are intentionally ignored: $($File.Name)"
    }

    [xml]$document = Get-Content $File.FullName -Raw
    $root = $document.DocumentElement
    if ($root.LocalName -ne "svg") {
        throw "Root element must be svg: $($File.FullName)"
    }

    if (-not $root.HasAttribute("viewBox")) {
        throw "SVG is missing its viewBox: $($File.FullName)"
    }

    $viewBox = @($root.GetAttribute("viewBox") -split "[,\s]+" | Where-Object { $_ })
    if ($viewBox.Count -ne 4) {
        throw "SVG viewBox must contain four numbers: $($File.FullName)"
    }

    $minX, $minY, $width, $height = $viewBox | ForEach-Object { Convert-Number $_ }
    if ($minX -ne 0 -or $minY -ne 0) {
        throw "Non-zero viewBox origins are not supported: $($File.FullName)"
    }
    if ($width -le 0 -or $height -le 0) {
        throw "SVG viewBox dimensions must be positive: $($File.FullName)"
    }
    if ($root.HasAttribute("transform") -or $root.HasAttribute("class")) {
        throw "The SVG root uses unsupported transform or class attributes: $($File.FullName)"
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('<Viewbox xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Width="16" Height="16">')
    $lines.Add("  <Canvas Width=`"$(Format-Number $width)`" Height=`"$(Format-Number $height)`">")
    $rootStyle = Get-Style $root @{}
    foreach ($child in $root.ChildNodes) {
        if ($child -is [System.Xml.XmlElement]) {
            Convert-Element $child $rootStyle $lines
        }
    }
    $lines.Add("  </Canvas>")
    $lines.Add("</Viewbox>")

    if ((Test-Path $Destination) -and -not $Force) {
        throw "Output already exists. Pass -Force to replace it: $Destination"
    }

    if ($PSCmdlet.ShouldProcess($Destination, "Convert $($File.Name) to WPF XAML")) {
        [System.IO.File]::WriteAllLines($Destination, $lines, [System.Text.UTF8Encoding]::new($false))
    }
}

$resolvedInput = Get-Item $InputPath
$null = New-Item $OutputDirectory -ItemType Directory -Force
$files = if ($resolvedInput.PSIsContainer) {
    @(Get-ChildItem $resolvedInput.FullName -Filter "file_type_*.svg" -File)
}
else {
    @($resolvedInput)
}

if ($Names) {
    $wanted = [System.Collections.Generic.HashSet[string]]::new($Names, [System.StringComparer]::OrdinalIgnoreCase)
    $files = @($files | Where-Object {
        $name = $_.BaseName -replace "^file_type_", ""
        $wanted.Contains($name)
    })
}

if (-not $files) {
    throw "No matching file_type_*.svg assets were found."
}

$converted = 0
$convertedFiles = [System.Collections.Generic.List[object]]::new()
$failures = [System.Collections.Generic.List[object]]::new()
foreach ($file in $files) {
    $sourceName = $file.BaseName -replace "^file_type_", ""
    $name = if ($NameMap.ContainsKey($sourceName)) { [string]$NameMap[$sourceName] } else { $sourceName }
    if ($name -notmatch "^[a-z0-9_-]+$") {
        throw "Mapped icon name contains unsupported characters: $name"
    }
    $destination = Join-Path $OutputDirectory "$name.xaml"
    try {
        Convert-File $file $destination
        $converted++
        $convertedFiles.Add([pscustomobject]@{
            Name = $name
            SourceFile = $file
            Destination = $destination
        })
    }
    catch {
        $failures.Add([pscustomobject]@{
            File = $file.Name
            Error = $_.Exception.Message
        })
    }
}

Write-Host "Converted $converted of $($files.Count) file icons."
if ($failures.Count) {
    $failures | Format-Table -AutoSize -Wrap
    throw "$($failures.Count) SVG file(s) use unsupported features."
}

if ($CatalogPath) {
    $resolvedCatalogPath = (Resolve-Path $CatalogPath).Path
    $catalog = Get-Content $resolvedCatalogPath -Raw | ConvertFrom-Json
    $outputRoot = [System.IO.Path]::GetFullPath($OutputDirectory).TrimEnd("\") + "\"
    $migrations = [System.Collections.Generic.List[object]]::new()

    foreach ($convertedFile in $convertedFiles) {
        $image = @($catalog.customImages | Where-Object name -eq $convertedFile.Name)
        if ($image.Count -ne 1) {
            throw "Catalog must contain exactly one custom image named '$($convertedFile.Name)'."
        }
        if ($image[0].file -notlike "*.png") {
            throw "Catalog image '$($convertedFile.Name)' does not reference a PNG: $($image[0].file)"
        }

        $oldAsset = [System.IO.Path]::GetFullPath((Join-Path $OutputDirectory $image[0].file))
        if (-not $oldAsset.StartsWith($outputRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Catalog asset resolves outside the output directory: $oldAsset"
        }
        if (-not (Test-Path $oldAsset -PathType Leaf)) {
            throw "Catalog PNG was not found: $oldAsset"
        }

        $migrations.Add([pscustomobject]@{
            Image = $image[0]
            OldAsset = $oldAsset
            NewFile = [System.IO.Path]::GetFileName($convertedFile.Destination)
            Source = "$($SourceBaseUrl.TrimEnd("/"))/$($convertedFile.SourceFile.Name)"
        })
    }

    foreach ($migration in $migrations) {
        $migration.Image.file = $migration.NewFile
        $migration.Image.provenance = "verified"
        foreach ($property in "size", "width", "height") {
            $migration.Image.PSObject.Properties.Remove($property)
        }
        $migration.Image | Add-Member -NotePropertyName source -NotePropertyValue $migration.Source -Force
        $migration.Image | Add-Member -NotePropertyName license -NotePropertyValue $License -Force
    }

    if ($PSCmdlet.ShouldProcess($resolvedCatalogPath, "Migrate $($migrations.Count) catalog images from PNG to XAML")) {
        $json = $catalog | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($resolvedCatalogPath, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
        foreach ($migration in $migrations) {
            Remove-Item $migration.OldAsset
        }
    }
}
