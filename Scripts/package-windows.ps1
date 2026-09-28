<#
.SYNOPSIS
    Packages the Unreal project as a Windows (Win64) build.

.DESCRIPTION
    Meant to be run inside the Windows VM. Finds the .uproject in the repo,
    finds the matching Unreal Engine install, checks the prerequisites and
    runs BuildCookRun headless (-nullrhi), so no GPU is needed.

.EXAMPLE
    .\Scripts\package-windows.ps1
    .\Scripts\package-windows.ps1 -Config Development
    .\Scripts\package-windows.ps1 -CopyTo \\host\share\Builds
#>
param(
    # Shipping for release, Development for testing (keeps logs and the console).
    [ValidateSet('Shipping', 'Development', 'DebugGame')]
    [string]$Config = 'Shipping',

    # Path to the .uproject. Found automatically when omitted.
    [string]$Project,

    # Engine root (the folder containing "Engine"). Found automatically when omitted.
    [string]$EngineDir = $env:UE_ROOT,

    # Where the packaged game goes. Defaults to %USERPROFILE%\UnrealBuilds\<Project>\<Config>.
    [string]$OutputDir,

    # Optional folder to copy the finished build to, e.g. the folder shared with the host.
    [string]$CopyTo,

    # Rebuild everything from scratch.
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

# --- Project ---------------------------------------------------------------
if (-not $Project) {
    $found = @(Get-ChildItem -Path $RepoRoot -Filter *.uproject -File)
    if ($found.Count -eq 0) {
        $found = @(Get-ChildItem -Path $RepoRoot -Filter *.uproject -File -Recurse -Depth 2)
    }
    if ($found.Count -ne 1) {
        throw "Expected exactly one .uproject under $RepoRoot but found $($found.Count). Pass -Project <path>."
    }
    $Project = $found[0].FullName
}
$Project = (Resolve-Path $Project).Path
$ProjectDir = Split-Path -Parent $Project
$ProjectName = [IO.Path]::GetFileNameWithoutExtension($Project)

# Assets checked out without Git LFS are small text pointers, and the cook fails on them.
$asset = Get-ChildItem -Path (Join-Path $ProjectDir 'Content') -Filter *.uasset -File -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($asset) {
    $bytes = New-Object byte[] 23
    $stream = [IO.File]::OpenRead($asset.FullName)
    try { [void]$stream.Read($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    if ([Text.Encoding]::ASCII.GetString($bytes) -eq 'version https://git-lfs') {
        throw "Assets are Git LFS pointers, not real files. Run 'git lfs install' then 'git lfs pull' in $RepoRoot."
    }
}

# --- Engine ----------------------------------------------------------------
function Get-RunUAT([string]$Root) {
    if (-not $Root) { return $null }
    $uat = Join-Path $Root 'Engine\Build\BatchFiles\RunUAT.bat'
    if (Test-Path $uat) { return $uat }
    return $null
}

$association = (Get-Content $Project -Raw | ConvertFrom-Json).EngineAssociation
$uat = Get-RunUAT $EngineDir

if (-not $uat -and $EngineDir) {
    throw "No RunUAT.bat under '$EngineDir'. Point -EngineDir (or UE_ROOT) at the folder that contains 'Engine'."
}

if (-not $uat -and $association) {
    # Launcher installs register by version number, source builds by GUID.
    $candidates = @(
        (Get-ItemProperty "HKLM:\SOFTWARE\EpicGames\Unreal Engine\$association" -ErrorAction SilentlyContinue).InstalledDirectory
        (Get-ItemProperty 'HKCU:\SOFTWARE\Epic Games\Unreal Engine\Builds' -ErrorAction SilentlyContinue).$association
        Join-Path $env:ProgramFiles "Epic Games\UE_$association"
    )
    foreach ($candidate in $candidates) {
        $uat = Get-RunUAT $candidate
        if ($uat) { break }
    }
}

if (-not $uat) {
    # The project was probably created on Linux, where EngineAssociation is a GUID
    # that means nothing here. Fall back to the newest launcher install.
    $newest = Get-ChildItem (Join-Path $env:ProgramFiles 'Epic Games') -Directory -Filter 'UE_*' -ErrorAction SilentlyContinue |
        Sort-Object -Descending {
            $v = $null
            [void][version]::TryParse(($_.Name -replace '^UE_', ''), [ref]$v)
            $v
        } |
        Select-Object -First 1
    if ($newest) { $uat = Get-RunUAT $newest.FullName }
    if (-not $uat) {
        throw "Could not find an Unreal Engine install. Install it from the Epic Games Launcher, or pass -EngineDir."
    }
    Write-Warning "Engine '$association' is not registered on this machine; using $($newest.FullName)."
    Write-Warning "Make sure this is the same engine version you use on Linux."
}

# --- Visual Studio (only needed for C++ projects) --------------------------
if (Test-Path (Join-Path $ProjectDir 'Source')) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $vs = $null
    if (Test-Path $vswhere) {
        $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    }
    if (-not $vs) {
        throw "This project has C++ code but no Visual Studio C++ tools were found. Install Visual Studio with the 'Game development with C++' workload."
    }
}

# --- Build -----------------------------------------------------------------
if (-not $OutputDir) {
    $OutputDir = Join-Path $env:USERPROFILE "UnrealBuilds\$ProjectName\$Config"
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Write-Host "Project : $Project"
Write-Host "Engine  : $((Resolve-Path (Join-Path (Split-Path -Parent $uat) '..\..\..')).Path)"
Write-Host "Config  : $Config"
Write-Host "Output  : $OutputDir"
Write-Host ''

$uatArgs = @(
    'BuildCookRun'
    "-project=$Project"
    '-platform=Win64'
    "-clientconfig=$Config"
    '-build', '-cook', '-stage', '-pak', '-prereqs', '-archive'
    "-archivedirectory=$OutputDir"
    '-nullrhi', '-unattended', '-utf8output', '-nop4'
)
if ($Clean) { $uatArgs += '-clean' }

& $uat @uatArgs
if ($LASTEXITCODE -ne 0) {
    throw "BuildCookRun failed with exit code $LASTEXITCODE. Scroll up for the first error."
}

$gameDir = Join-Path $OutputDir 'Windows'
Write-Host ''
Write-Host "Done. Game is in $gameDir"

if ($CopyTo) {
    $destination = Join-Path $CopyTo "$ProjectName-Windows-$Config"
    robocopy $gameDir $destination /MIR /NFL /NDL /NJH /NP | Out-Null
    # robocopy uses exit codes 0-7 for success.
    if ($LASTEXITCODE -ge 8) { throw "Copy to $destination failed (robocopy exit code $LASTEXITCODE)." }
    Write-Host "Copied to $destination"
}
