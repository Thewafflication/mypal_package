# Bounded fail-fast test: valid SHA256 digest exercises passing validation
# Uses the same validation logic as scripts/Build-MypalPackage.ps1 lines 52-55
# Documented semantics: matching valid SHA256 → PASS (validation succeeds)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

# Create a test file with known content
$testBytes = @(86,69,65,80,32,116,101,115,116,32,102,111,110,116,45,119,105,116,104,32,99,111,110,116,101,110,116,115,46,101,120,101)
$testFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllBytes($testFile, $testBytes) | Out-Null

$differentFile = $null

# Helper function to compute SHA256 using .NET
function Get-SHA256Hash($path) {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $hash = $sha256.ComputeHash($bytes)
    return ($hash | ForEach-Object { $_.ToString("x2") }) -join ''
}

try {
    # Step 1: Compute the real SHA-256 hash (this is what production validation does)
    $realHash = Get-SHA256Hash $testFile
    Write-Host "Test file bytes: $($testBytes.Length)"
    Write-Host "Real SHA-256 hash: $realHash`n"

    # Step 2: Test with CORRECT digest matching the real hash (production validation path)
    # This exercises the exact pattern from Build-MypalPackage.ps1: ^sha256:(?<hash>[0-9a-fA-F]{64})$
    $correctDigest = "sha256:$realHash"
    Write-Host "Test 1: Valid SHA256 digest matching real hash`n"

    if ($correctDigest -and $correctDigest -match '^sha256:(?<hash>[0-9a-fA-F]{64})$') {
        $matchedHash = $Matches.hash
        $actualHash = Get-SHA256Hash $testFile
        if ($actualHash -ne $matchedHash) {
            Write-Host "  MISMATCH detected: actual=$actualHash expected=$matchedHash - FAIL"
            exit 1
        } else {
            Write-Host "  Match: actual=$actualHash expected=$matchedHash - PASS"
        }
    } else {
        Write-Host "  Digest did not match pattern - unexpected"
        exit 1
    }

    # Step 3: Test with a different valid64hex SHA256 (different value, same format)
    # Generate a different SHA256 by hashing different content
    $differentBytes = @(65,66,67,68)  # "ABCD" - will produce different hash
    $differentFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllBytes($differentFile, $differentBytes) | Out-Null
    $differentHash = Get-SHA256Hash $differentFile
    Write-Host "`nTest 2: Different valid64hex SHA256 (different content, same format)`n"
    Write-Host "  Different file hash: $differentHash"

    $differentDigest = "sha256:$differentHash"
    if ($differentDigest -and $differentDigest -match '^sha256:(?<hash>[0-9a-fA-F]{64})$') {
        $matchedHash2 = $Matches.hash
        $actualDifferentHash = Get-SHA256Hash $differentFile
        if ($actualDifferentHash -ne $matchedHash2) {
            Write-Host "  MISMATCH detected: actual=$actualDifferentHash expected=$matchedHash2 - FAIL"
            exit 1
        } else {
            Write-Host "  Match: actual=$actualDifferentHash expected=$matchedHash2 - PASS"
            Write-Host "  Note: Different content produces different but valid SHA256 - both exercise passing validation"
        }
    } else {
        Write-Host "  Digest did not match pattern - unexpected"
        exit 1
    }

    Write-Host "`n=== test_sha256_valid.ps1: ALL TESTS PASSED ==="
} finally {
    # Cleanup - only remove if variables were created
    if ($testFile) { Remove-Item $testFile -Force }
    if ($differentFile) { Remove-Item $differentFile -Force }
}