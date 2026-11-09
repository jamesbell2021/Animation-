# Exports the Windows build and zips it with the version from project.godot:
#   build\SeaTheyAreAngry-v<version>-windows-x86_64.zip
# Needs Godot 4.3 and its export templates. Set $env:GODOT to the console exe if it isn't
# on the PATH (Godot_v4.3-stable_win64_console.exe).  Run:  scripts\export_windows.ps1
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
$line = Select-String -Path project.godot -Pattern '^config/version="(.*)"' | Select-Object -First 1
if (-not $line) { throw "no application/config/version in project.godot" }
$version = $line.Matches[0].Groups[1].Value
$out = "build\windows"
$zip = "build\SeaTheyAreAngry-v$version-windows-x86_64.zip"
New-Item -ItemType Directory -Force -Path $out | Out-Null
& $godot --headless --editor --quit --path . 2>$null | Out-Null
& $godot --headless --path . --export-release "Windows" "$out\SeaTheyAreAngry.exe"
if ($LASTEXITCODE -ne 0) { throw "export failed" }
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path "$out\*" -DestinationPath $zip
Write-Host "wrote $zip"
