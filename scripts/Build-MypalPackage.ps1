[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('x86', 'x64')]
    [string] $Architecture,

    [string] $OutputDirectory = (Join-Path $PSScriptRoot '..\out\packages'),
    [string] $WorkDirectory = (Join-Path $PSScriptRoot "..\out\work-$Architecture"),
    [string] $SigningKey,
    [string] $WpmExecutable = 'wpm.exe',
    [switch] $DebugPackage,
    [string] $ReleaseRepository = 'Feodor2/Mypal68'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Invoke-Checked {
    param([Parameter(Mandatory)][scriptblock] $Command, [Parameter(Mandatory)][string] $Description)
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "$Description failed with exit code $LASTEXITCODE." }
}

$assetArchitecture = if ($Architecture -eq 'x86') { 'win32' } else { 'win64' }
$headers = @{ Accept = 'application/vnd.github+json'; 'User-Agent' = 'mypal-wpm-builder' }
if ($env:GITHUB_TOKEN) { $headers.Authorization = "Bearer $env:GITHUB_TOKEN" }

$release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$ReleaseRepository/releases/latest"
$version = ([string]$release.tag_name).TrimStart('v')
if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$') {
    throw "The upstream tag '$($release.tag_name)' is not a supported package version."
}

$pattern = "^mypal-$([regex]::Escape($version))\.en-US\.$assetArchitecture\.zip$"
$assets = @($release.assets | Where-Object { $_.name -match $pattern })
if ($assets.Count -ne 1) {
    throw "Expected one upstream $assetArchitecture ZIP matching '$pattern'; found $($assets.Count)."
}
$asset = $assets[0]

$resolvedWork = [IO.Path]::GetFullPath($WorkDirectory)
$resolvedOutput = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $resolvedWork) { Remove-Item -LiteralPath $resolvedWork -Recurse -Force }
$downloadDirectory = Join-Path $resolvedWork 'download'
$extractDirectory = Join-Path $resolvedWork 'extract'
$stagingDirectory = Join-Path $resolvedWork 'staging'
$metadataDirectory = Join-Path $stagingDirectory '.wpm'
New-Item -ItemType Directory -Force -Path $downloadDirectory, $extractDirectory, $metadataDirectory, $resolvedOutput | Out-Null

$archive = Join-Path $downloadDirectory $asset.name
Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $asset.browser_download_url -OutFile $archive
if ($asset.digest -and $asset.digest -match '^sha256:(?<hash>[0-9a-fA-F]{64})$') {
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash
    if ($actualHash -ne $Matches.hash) { throw "SHA-256 mismatch for $($asset.name)." }
}
Expand-Archive -LiteralPath $archive -DestinationPath $extractDirectory

$executables = @(Get-ChildItem -LiteralPath $extractDirectory -Filter 'mypal.exe' -File -Recurse)
if ($executables.Count -ne 1) { throw "Expected one mypal.exe in the upstream archive; found $($executables.Count)." }
$payloadRoot = $executables[0].Directory.FullName
Copy-Item -Path (Join-Path $payloadRoot '*') -Destination $stagingDirectory -Recurse -Force

$debugValue = if ($DebugPackage) { 'true' } else { 'false' }
$metadata = @(
    'name=mypal'
    "version=$version"
    "arch=$Architecture"
    "debug=$debugValue"
    'description=Mypal, a current and maintained web browser for Windows XP'
    'maintainer=Jordan Waughtal'
    'homepage=https://www.mypal-browser.org/'
    "repository=https://github.com/$ReleaseRepository"
    'license=MPL-2.0'
    "source-version=$version"
    "source-url=$($asset.browser_download_url)"
) -join "`n"
[IO.File]::WriteAllText((Join-Path $metadataDirectory 'package.txt'), $metadata + "`n", [Text.UTF8Encoding]::new($false))

$installDirectory = "%ProgramFiles%\Mypal\$version"
$installScript = @"
@echo off
setlocal
set "MYPAL_DEST=$installDirectory"
if not exist "%MYPAL_DEST%" mkdir "%MYPAL_DEST%" || exit /b 1
xcopy "%~dp0..\*" "%MYPAL_DEST%\" /E /I /Q /Y >nul || exit /b 1
if exist "%MYPAL_DEST%\.wpm" rmdir /S /Q "%MYPAL_DEST%\.wpm"
cscript //nologo "%~dp0shortcut.vbs" create "%MYPAL_DEST%\mypal.exe" || exit /b 1
exit /b 0
"@ -replace "`n", "`r`n"
[IO.File]::WriteAllText((Join-Path $metadataDirectory 'install.cmd'), $installScript, [Text.ASCIIEncoding]::new())

$removeScript = @"
@echo off
setlocal
set "MYPAL_DEST=$installDirectory"
cscript //nologo "%~dp0shortcut.vbs" remove "%MYPAL_DEST%\mypal.exe"
if exist "%MYPAL_DEST%" rmdir /S /Q "%MYPAL_DEST%" || exit /b 1
exit /b 0
"@ -replace "`n", "`r`n"
[IO.File]::WriteAllText((Join-Path $metadataDirectory 'remove.cmd'), $removeScript, [Text.ASCIIEncoding]::new())

$shortcutScript = @'
Option Explicit
Dim shell, fs, action, target, linkPath, shortcut
If WScript.Arguments.Count <> 2 Then WScript.Quit 2
action = LCase(WScript.Arguments(0))
target = WScript.Arguments(1)
Set shell = CreateObject("WScript.Shell")
Set fs = CreateObject("Scripting.FileSystemObject")
linkPath = shell.SpecialFolders("AllUsersDesktop") & "\Mypal.lnk"
If action = "create" Then
  Set shortcut = shell.CreateShortcut(linkPath)
  shortcut.TargetPath = target
  shortcut.WorkingDirectory = fs.GetParentFolderName(target)
  shortcut.IconLocation = target & ",0"
  shortcut.Description = "Mypal web browser"
  shortcut.Save
ElseIf action = "remove" Then
  If fs.FileExists(linkPath) Then
    Set shortcut = shell.CreateShortcut(linkPath)
    If LCase(shortcut.TargetPath) = LCase(target) Then fs.DeleteFile linkPath, True
  End If
Else
  WScript.Quit 2
End If
'@
[IO.File]::WriteAllText((Join-Path $metadataDirectory 'shortcut.vbs'), $shortcutScript, [Text.ASCIIEncoding]::new())
[IO.File]::WriteAllText((Join-Path $metadataDirectory 'wpmignore.txt'), ".wpm/`n*.log`nout/`n", [Text.ASCIIEncoding]::new())

$arguments = @('build', $stagingDirectory, $resolvedOutput)
if ($SigningKey) {
    $resolvedKey = [IO.Path]::GetFullPath($SigningKey)
    if (-not (Test-Path -LiteralPath $resolvedKey -PathType Leaf)) { throw "Signing key not found: $resolvedKey" }
    $arguments += @('--sign', $resolvedKey)
}
Invoke-Checked -Description 'WPM package build' -Command { & $WpmExecutable @arguments }

$debugPart = if ($DebugPackage) { '-debug' } else { '' }
$packagePath = Join-Path $resolvedOutput "mypal-$Architecture$debugPart-$version.zip"
if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) { throw "WPM did not produce $packagePath." }
[pscustomobject]@{ Version = $version; Architecture = $Architecture; Package = $packagePath; Source = $asset.browser_download_url }
