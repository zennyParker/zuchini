# Run the portable core tests using the installed Swift/Visual C++ toolchains.
# SwiftUI/UIKit are unavailable on Windows and still require a macOS build.
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
$swiftSdkRoot = [Environment]::GetEnvironmentVariable('SDKROOT', 'User')
if (-not $swiftSdkRoot) { $swiftSdkRoot = [Environment]::GetEnvironmentVariable('SDKROOT', 'Machine') }
if (-not $swiftSdkRoot -or -not (Test-Path -LiteralPath $swiftSdkRoot -PathType Container)) {
    throw 'Swift Windows SDK not found. Install Swift using the official Windows installer.'
}
$env:SDKROOT = $swiftSdkRoot
$vsWhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vsWhere)) { throw 'Visual Studio Build Tools are required.' }
$vsCandidates = @(& $vsWhere -all -products '*' -property installationPath)
$devModule = $null
$vsInstall = $null
foreach ($candidate in $vsCandidates) {
    $candidateModule = Join-Path $candidate 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll'
    if ((Test-Path -LiteralPath $candidateModule) -and (Test-Path -LiteralPath (Join-Path $candidate 'VC\Tools\MSVC'))) {
        $devModule = $candidateModule
        $vsInstall = $candidate
        break
    }
}
if (-not $devModule) { throw 'No Visual Studio installation with C++ build tools was found.' }
Import-Module $devModule
Enter-VsDevShell -VsInstallPath $vsInstall -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64'
Push-Location -LiteralPath $sourceRoot
try {
    & swift --version
    if ($LASTEXITCODE -ne 0) { throw 'Swift compiler could not start.' }
    & swift test
    if ($LASTEXITCODE -ne 0) { throw "Swift tests failed (exit $LASTEXITCODE)." }
} finally {
    Pop-Location
}
