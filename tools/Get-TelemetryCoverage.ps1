[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [string]$VisualStudioInstallPath,

    [ValidateRange(1, 500)]
    [int]$Top = 25,

    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot
$catalogPath = Join-Path $repoRoot "catalog.json"

if (-not (Test-Path $CsvPath -PathType Leaf)) {
    throw "Telemetry CSV not found: $CsvPath"
}

if (-not (Test-Path $catalogPath -PathType Leaf)) {
    throw "Catalog not found: $catalogPath"
}

function Resolve-VisualStudioInstallPath {
    if ($VisualStudioInstallPath) {
        return (Resolve-Path $VisualStudioInstallPath).Path
    }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $installation = & $vswhere -latest -products * -property installationPath
        if ($installation) {
            return $installation.Trim()
        }
    }

    $devenv = Get-Process devenv -ErrorAction SilentlyContinue |
        Where-Object Path |
        Select-Object -First 1
    if ($devenv) {
        return Split-Path (Split-Path (Split-Path $devenv.Path))
    }

    throw "Visual Studio was not found. Pass -VisualStudioInstallPath explicitly."
}

function Get-VisualStudioAssociations {
    param([string]$InstallPath)

    $idePath = Join-Path $InstallPath "Common7\IDE"
    if (-not (Test-Path $idePath -PathType Container)) {
        throw "Visual Studio IDE directory not found: $idePath"
    }

    $associationPattern = '(?ms)^\[\$RootKey\$\\ShellFileAssociations\\(?<extension>[^\]]+)\]\s*\r?\n(?:(?!^\[).)*?^"DefaultIconMoniker"="(?<moniker>[^"]+)"'
    foreach ($file in Get-ChildItem $idePath -Recurse -Filter *.pkgdef -File -ErrorAction SilentlyContinue) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) {
            continue
        }

        foreach ($match in [regex]::Matches($content, $associationPattern)) {
            [pscustomobject]@{
                Extension = $match.Groups["extension"].Value.ToLowerInvariant()
                Moniker = $match.Groups["moniker"].Value
                IsCore = $file.FullName -like "*CommonExtensions\Platform\Shell\*"
            }
        }
    }
}

function Format-Count {
    param([long]$Value)
    return $Value.ToString("N0", [System.Globalization.CultureInfo]::InvariantCulture)
}

$telemetry = @(Import-Csv $CsvPath | ForEach-Object {
    if (-not $_.PSObject.Properties["ext"] -or -not $_.PSObject.Properties["dcount_MacAddressHash"]) {
        throw "CSV must contain 'ext' and 'dcount_MacAddressHash' columns."
    }

    [pscustomobject]@{
        Observed = ([string]$_.ext).Trim().ToLowerInvariant()
        Users = [long]$_.dcount_MacAddressHash
    }
})

$catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json
$fileIcons = @{}
foreach ($association in $catalog.associations) {
    $fileIcons[$association.extension] = $association
}

$vsInstall = Resolve-VisualStudioInstallPath
$vsAssociations = @(Get-VisualStudioAssociations $vsInstall)
$visualStudio = @{}
$visualStudioCore = @{}
foreach ($association in $vsAssociations) {
    $visualStudio[$association.Extension] = $association.Moniker
    if ($association.IsCore) {
        $visualStudioCore[$association.Extension] = $association.Moniker
    }
}

$knownExtensions = @($fileIcons.Keys + $visualStudio.Keys | Sort-Object -Unique)
$classified = foreach ($row in $telemetry) {
    $observed = $row.Observed
    $canonical = $observed
    $resolution = "exact"
    $isNoise = $observed -eq "unknown" -or
        $observed -match '[;)]' -or
        $observed -notmatch '^\.[a-z0-9]'

    # The telemetry column stores at most ten characters after the leading dot.
    if (-not $isNoise -and $observed.Length -eq 11 -and $observed -notin $knownExtensions) {
        $candidates = @($knownExtensions | Where-Object { $_.StartsWith($observed) })
        if ($candidates.Count -eq 1) {
            $canonical = $candidates[0]
            $resolution = "truncated"
        }
        elseif ($candidates.Count -gt 1) {
            $resolution = "ambiguous"
        }
    }

    $provider = if ($isNoise) {
        "Noise"
    }
    elseif ($resolution -eq "ambiguous") {
        "Ambiguous"
    }
    elseif ($visualStudioCore.ContainsKey($canonical)) {
        "Visual Studio core"
    }
    elseif ($visualStudio.ContainsKey($canonical)) {
        "Visual Studio optional"
    }
    elseif ($fileIcons.ContainsKey($canonical)) {
        "File Icons only"
    }
    else {
        "Uncovered"
    }

    [pscustomobject]@{
        Observed = $observed
        Extension = $canonical
        Users = $row.Users
        Provider = $provider
        Resolution = $resolution
    }
}

$normalized = @($classified | Where-Object Provider -notin "Noise", "Ambiguous")
$total = [long](($normalized | Measure-Object Users -Sum).Sum)
$report = [System.Text.StringBuilder]::new()
$null = $report.AppendLine("# File icon telemetry coverage")
$null = $report.AppendLine()
$null = $report.AppendLine("Visual Studio installation: ``$vsInstall``")
$null = $report.AppendLine()
$null = $report.AppendLine("| Provider | Extensions | Distinct machines | Share |")
$null = $report.AppendLine("|---|---:|---:|---:|")

foreach ($provider in "Visual Studio core", "Visual Studio optional", "File Icons only", "Uncovered") {
    $items = @($normalized | Where-Object Provider -eq $provider)
    $users = [long](($items | Measure-Object Users -Sum).Sum)
    $share = if ($total) { 100 * $users / $total } else { 0 }
    $null = $report.AppendLine("| $provider | $($items.Count) | $(Format-Count $users) | $($share.ToString('0.00'))% |")
}

$noise = [long](($classified | Where-Object Provider -eq "Noise" | Measure-Object Users -Sum).Sum)
$ambiguous = [long](($classified | Where-Object Provider -eq "Ambiguous" | Measure-Object Users -Sum).Sum)
$null = $report.AppendLine()
$null = $report.AppendLine("Excluded noisy observations: $(Format-Count $noise). Ambiguous truncated observations: $(Format-Count $ambiguous).")
$null = $report.AppendLine()
$null = $report.AppendLine("## Highest-use uncovered extensions")
$null = $report.AppendLine()
$null = $report.AppendLine("| Extension | Distinct machines |")
$null = $report.AppendLine("|---|---:|")

foreach ($item in $normalized | Where-Object Provider -eq "Uncovered" | Sort-Object Users -Descending | Select-Object -First $Top) {
    $suffix = if ($item.Observed.Length -eq 11) { " (possibly truncated)" } else { "" }
    $null = $report.AppendLine("| ``$($item.Observed)``$suffix | $(Format-Count $item.Users) |")
}

$content = $report.ToString().TrimEnd() + "`r`n"
if ($OutputPath) {
    [System.IO.File]::WriteAllText(
        (Join-Path (Get-Location) $OutputPath),
        $content,
        [System.Text.UTF8Encoding]::new($false))
}
else {
    $content
}
