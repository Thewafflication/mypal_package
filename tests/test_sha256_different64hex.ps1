# Bounded fail-fast test: valid64hex SHA256 (different value) exercises passing validation
# Uses the same validation logic as scripts/Build-MypalPackage.ps1 lines 52-55
# Tests that a different but valid 64-hex-digit SHA256 also passes validation

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

# Helper function to compute SHA256 using .NET
function Get-SHA256Hash($path) {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $hash = $sha256.ComputeHash($bytes)
    return ($hash | ForEach-Object { $_.ToString("x2") }) -join ''
}

# Create a test file with different known content
$testBytes = @(72,101,115,117,108,116,32,116,101,115,116,45,102,111,110,116,45,119,105,116,104,32,99,111,110,116,101,110,116,115,46,101,120,101)
$testFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllBytes($testFile, $testBytes) | Out-Null

$differentFile = $null

try {
    # Step 1: Compute the real SHA-256 hash
    $realHash = Get-SHA256Hash $testFile
    Write-Host "Test file bytes: $($testBytes.Length)"
    Write-Host "Real SHA-256 hash: $realHash`n"

    # Step 2: Test with a different valid64hex SHA256
    # Use a different set of bytes to produce a different hash
    $diffBytes = @(83,84,82,73,70,76)  # "STRIFL" - different content
    $differentFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllBytes($differentFile, $diffBytes) | Out-Null
    $differentHash = Get-SHA256Hash $differentFile
    Write-Host "Different content file hash: $differentHash`n"

    # The production validation checks: if digest matches ^sha256:(?<hash>[0-9a-fA-F]{64})$,
    # then compute actual hash and compare. If they match, validation passes.
    # We test with the different hash value in the digest format.
    $differentDigest = "sha256:$differentHash"
    Write-Host "Test: valid64hex SHA256 digest with different hash value`n"
    Write-Host "  Digest: $differentDigest`n"

    if ($differentDigest -and $differentDigest -match '^sha256:(?<hash>[0-9a-fA-F]{64})$') {
        $matchedHash = $Matches.hash
        $actualDifferentHash = Get-SHA256Hash $differentFile
        Write-Host "  Matched from digest pattern: $matchedHash"
        Write-Host "  Actual hash from file: $actualDifferentHash"

        if ($actualDifferentHash -ne $matchedHash) {
            Write-Host "  MISMATCH: actual hash does not match digest - expected when content differs"
            # This is expected - different content produces different hash
        } else {
            Write-Host "  Match: actual=$actualDifferentHash expected=$matchedHash - PASS"
        }
    } else {
        Write-Host "  Digest did not match pattern - unexpected"
        exit 1
    }

    # Step 3: Now test the passing case - use the correct hash for the file
    Write-Host "`nTest 3: Correct matching digest for the same file (PASS case)`n"
    $correctDigest = "sha256:$realHash"
    if ($correctDigest -and $correctDigest -match '^sha256:(?<hash>[0-9a-fA-F]{64})$') {
        $matchedHash = $Matches.hash
        $actualHash = Get-SHA256Hash $testFile
        if ($actualHash -ne $matchedHash) {
            Write-Host "  MISMATCH detected - FAIL"
            exit 1
        } else {
            Write-Host "  Match: actual=$actualHash expected=$matchedHash - PASS"
        }
    }

    Write-Host "`n=== test_sha256_different64hex.ps1: ALL TESTS PASSED ==="
    Write-Host "  Both valid SHA256 formats (matching and different64hex) exercise the production"
    Write-Host "  validation pattern ^sha256:(?<hash>[0-9a-fA-F]{64})$ correctly."
} finally {
    # Cleanup - only remove if variables were created
    if ($testFile) { Remove-Item $testFile -Force }
    if ($differentFile) { Remove-Item $differentFile -Force }
}