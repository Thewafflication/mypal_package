# SHA-256 Digest Validation Fixture
# Tests the same logic as in scripts/Build-MypalPackage.ps1 lines 52-55

Write-Host "=== SHA-256 Digest Validation Fixture ==`n"

# Step 1: Create a test file with known content
$testBytes = @(86,69,65,80,32,116,101,115,116,32,102,111,110,116,45,119,105,116,104,32,99,111,110,116,101,110,116,115,46,101,120,101)
$testFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllBytes($testFile, $testBytes) | Out-Null

try {
    # Step 2: Compute the real SHA-256 hash
    $sha256_hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $testFile).Hash
    Write-Host "Test file bytes: $($testBytes.Length)"
    Write-Host "Real SHA-256 hash: $sha256_hash`n"
    
    # Step 3: Test with CORRECT digest
    Write-Host "Test 1: Correct digest should PASS`n"
    $correctDigest = "sha256:$sha256_hash"
    if ($correctDigest -and $correctDigest -match '^sha256:(?<hash>[0-9a-fA-F]{64})$') {
        $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $testFile).Hash
        if ($actualHash -ne $Matches.hash) {
            Write-Host "  Mismatch detected: actual=$actualHash wrong=$($Matches.hash) - FAILS"
        } else {
            Write-Host "  Match: actual=$actualHash expected=$($Matches.hash) - PASS"
        }
    }
    
    # Step 4: Test with INCORRECT digest
    Write-Host "`nTest 2: Incorrect digest should FAIL`n"
    $wrongDigest = "sha256:wronghashvalue123456789012345678901234567890123456789012345678901234"
    # Simulate the check
    if ($wrongDigest -and $wrongDigest -match '^sha256:(?<hash>[0-9a-fA-F]{64})$') {
        $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $testFile).Hash
        if ($actualHash -ne $Matches.hash) {
            Write-Host "  Mismatch detected: actual=$actualHash wrong=$($Matches.hash) - CORRECTLY FAILS"
        } else {
            Write-Host "  No mismatch detected - SHOULD HAVE FAILED"
        }
    } else {
        Write-Host "  Wrong digest format - does not match pattern"
    }
    
    # Step 5: Test with malformed digest
    Write-Host "`nTest 3: Malformed digest format handling`n"
    $malformedDigest = "invalid-digest-format"
    if ($malformedDigest -and $malformedDigest -match '^sha256:(?<hash>[0-9a-fA-F]{64})$') {
        Write-Host "  Should not match - good, malformed digest is skipped"
    } else {
        Write-Host "  Malformed digest format correctly rejected (no match)"
    }
    
} finally {
    # Cleanup
    if (Test-Path $testFile) {
        Remove-Item $testFile -Force
    }
}

Write-Host "`n=== Fixture Complete ==="