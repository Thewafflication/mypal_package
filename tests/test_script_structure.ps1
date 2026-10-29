# Test: Validate Build-MypalPackage script structure
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot '..\scripts\Build-MypalPackage.ps1'
if (-not (Test-Path $scriptPath)) { throw "Build-MypalPackage.ps1 not found at $scriptPath" }
$scriptContent = Get-Content $scriptPath -Raw

# Read the param block lines directly
$lines = $scriptContent -split "`n"
$paramBlock = $null
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -eq 'param(') {
        # Collect param block until closing paren
        $j = $i + 1
        $blockLines = @()
        while ($j -lt $lines.Count -and $lines[$j] -ne ')') {
            $blockLines += $lines[$j]
            $j++
        }
        $paramBlock = $blockLines -join "`n"
        break
    }
}

if (-not $paramBlock) { throw 'Could not find param block.' }

# Check for [Parameter(Mandatory)] in param block
if (-not ($paramBlock -match '\[Parameter\(Mandatory\)\]')) {
    throw 'Missing [Parameter(Mandatory)] in param block.'
}

# Check for [ValidateSet] in param block
if (-not ($paramBlock -match '\[ValidateSet')) {
    throw 'Missing [ValidateSet] in param block.'
}

# Check that ValidateSet contains x86 and x64
if (-not ($paramBlock -match 'x86')) {
    throw 'Missing x86 in ValidateSet.'
}
if (-not ($paramBlock -match 'x64')) {
    throw 'Missing x64 in ValidateSet.'
}

# Check for [string] $Architecture in param block
if (-not ($paramBlock -match '\[string\]\s*\$Architecture')) {
    throw 'Missing $Architecture string param in param block.'
}

Write-Host 'Script structure validated successfully.'
Write-Host "Param block content:`n$paramBlock"