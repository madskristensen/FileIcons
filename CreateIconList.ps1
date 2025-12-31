
Write-Host "Updating FileExtensions.md..." -ForegroundColor Cyan -NoNewline

$solDir = (Split-Path (Get-Variable MyInvocation).Value.MyCommand.Path)
$path = $solDir + "\src\icons.pkgdef"
$content = Get-Content $path

$list = ([regex]'\\([^\\\]]+)]').Matches($content) `
		| Sort-Object `
		| foreach {"- " + $_.groups[1].value}

"## Supported File Extensions (" + $list.Length + ")`r`n`r`n" + ($list -join "`r`n") | Set-Content ($solDir + "\FileExtensions.md")

Write-Host "OK" -ForegroundColor Green