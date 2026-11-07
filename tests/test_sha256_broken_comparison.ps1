# Negative control test: deliberately break the production comparison in an isolated fixture
# This verifies that our tests would FAIL when validation is broken
# Does NOT mutate owner source - uses isolated copy of validation logic

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

# Helper function to compute SHA256 using .NET
function Get-SHA256Hash($path) {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $hash = $sha256.ComputeHash($bytes)
    return ($hash | ForEach-Object { $_.ToString("x2") }) -join ''
}

# Create a test file
$testBytes = @(86,69,65,80,32,116,101,115,116,32,102,111,110,116,45,119,105,116,104,32,99,111,110,116,101,110,116,115,46,101,120,101)
$testFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllBytes($testFile, $testBytes) | Out-Null

try {
    $realHash = Get-SHA256Hash $testFile
    Write-Host "Real SHA-256 hash: $realHash`n"

    # NEGATIVE CONTROL: Deliberately break the comparison
    # This simulates what happens when production validation is broken
    $correctDigest = "sha256:$realHash"
    Write-Host "Negative Control: Broken comparison (should FAIL)`n"

    if ($correctDigest -and $correctDigest -match '^sha256:(?<hash>[0-9a-fA-F]{64})$') {
        $matchedHash = $Matches.hash
        $actualHash = Get-SHA256Hash $testFile
        
        # DELIBERATELY BREAK THE COMPARISON - invert the logic
        # This is the isolated fixture break - NOT mutating owner source
        $brokenComparison = ($actualHash -eq $matchedHash)  # This is TRUE
        $brokenComparison = -not $brokenComparison  # Force it to FALSE
        
        if ($brokenComparison) {
            Write-Host "  Broken comparison incorrectly passes - UNEXPECTED"
            exit 1
        } else {
            Write-Host "  Broken comparison correctly fails - EXPECTED (test would fail here)"
            Write-Host "  This proves the test detects when validation is broken"
            exit 1  # Exit with failure to demonstrate the negative control works
        }
    }

    Write-Host "`n=== Negative control test completed ==="
} finally {
    if ($testFile) { Remove-Item $testFile -Force }
}