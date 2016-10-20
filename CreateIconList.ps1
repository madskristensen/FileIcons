
Write-Host "Updating iconlist.txt..." -ForegroundColor Cyan -NoNewline

$solDir = (Split-Path (Get-Variable MyInvocation).Value.MyCommand.Path)
$path = $solDir + "\src\icons.pkgdef"
$content = Get-Content $path

$list = ([regex]'\\([^\\\]]+)]').Matches($content) `
		| Sort-Object `
		| foreach {$_.groups[1].value} `
		| Set-Content ($solDir + "\FileExtenions.txt")

Write-Host "OK" -ForegroundColor Green