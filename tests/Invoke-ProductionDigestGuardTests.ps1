param(
    [Parameter(Mandatory = $true)]
    [string]$BuildScriptPath
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Invoke-ProductionDigestGuardTests.ps1 - Production Digest Guard Harness ==="

if (-not (Test-Path -LiteralPath $BuildScriptPath)) {
    throw "Build script path not found: $BuildScriptPath"
}

# 1. Parse BuildScriptPath with PowerShell AST and extract the real digest guard block
$buildScriptContent = Get-Content -LiteralPath $BuildScriptPath -Raw
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($buildScriptContent, [ref]$tokens, [ref]$errors)

if ($errors) {
    Write-Warning "Parser warnings: $($errors.Count) errors encountered"
}

# Find the if statement containing the digest guard pattern
# In Build-MypalPackage.ps1: if ($asset.digest -and $asset.digest -match '^sha256:(?<hash>[0-9a-fA-F]{64})$') { ... }
$guardStatement = $null
$ast.FindAll(
    {
        param($node)
        if ($node -is [System.Management.Automation.Language.IfStatementAst]) {
            $condStr = $node.Clauses[0].Item1.ToString()
            if ($condStr -match 'asset\.digest' -and $condStr -match 'sha256') {
                return $true
            }
        }
        return $false
    },
    $true
) | ForEach-Object {
    if (-not $guardStatement) {
        $guardStatement = $_
    }
}

if (-not $guardStatement) {
    throw "Could not find digest guard block in production script: $BuildScriptPath"
}

$guardSource = $guardStatement.Extent.Text
Write-Host "  Found production digest guard block (extent line $($guardStatement.Extent.StartLine)):"
Write-Host "  ---"
Write-Host $guardSource
Write-Host "  ---"

# Helper function to execute a given guard source string with a specific $archive file and $digest string
function Invoke-GuardCode {
    param(
        [string]$Code,
        [string]$ArchivePath,
        [string]$AssetDigest
    )

    # Setup variables expected by the guard block
    $asset = [PSCustomObject]@{
        digest = $AssetDigest
    }
    $archive = $ArchivePath

    # Execute the code in local scope
    try {
        $sb = [scriptblock]::Create($Code)
        & $sb
        return "accepted"
    }
    catch {
        return "rejected"
    }
}

# Create a temporary test file with known content
$tempDir = [System.IO.Path]::GetTempPath()
$testFile = Join-Path $tempDir ("mypal_test_(" + [Guid]::NewGuid().ToString("N") + ").zip")
[System.IO.File]::WriteAllText($testFile, "MypalPackageTestContent", [System.Text.Encoding]::UTF8)
try {
    $actualHash = ((Get-FileHash -Algorithm SHA256 -LiteralPath $testFile).Hash).ToLower()
}
catch {
    throw "Could not compute SHA-256 of test file"
}

Write-Host "  Test file: $testFile"
Write-Host "  Actual SHA-256: $actualHash"
Write-Host ""

$test1Pass = $false
$test2Pass = $false
$test3aPass = $false
$test3bPass = $false

# === TEST 1: Matching digest accepted ===
Write-Host "=== TEST 1: Matching digest accepted ==="
$matchingDigest = "sha256:$actualHash"
$res1 = Invoke-GuardCode -Code $guardSource -ArchivePath $testFile -AssetDigest $matchingDigest
Write-Host "  Guard result: $res1"
if ($res1 -eq "accepted") {
    $test1Pass = $true
    Write-Host "  PASS: Matching digest accepted (guard exits 0)" -ForegroundColor Green
}
else {
    Write-Host "  FAIL: Matching digest unexpectedly rejected" -ForegroundColor Red
}
Write-Host ""

# === TEST 2: Different valid 64-hex digest for same archive rejected ===
Write-Host "=== TEST 2: Different valid64hex digest for same archive rejected ==="
# Generate a different valid 64-hex hash (ensuring it differs from actualHash)
$wrongHash = "0000000000000000000000000000000000000000000000000000000000000000"
if ($wrongHash -eq $actualHash) {
    $wrongHash = "1111111111111111111111111111111111111111111111111111111111111111"
}
$wrongDigest = "sha256:$wrongHash"
Write-Host "  Using wrong digest: $wrongDigest"
Write-Host "  Actual file hash:   $actualHash"

$res2 = Invoke-GuardCode -Code $guardSource -ArchivePath $testFile -AssetDigest $wrongDigest
Write-Host "  Guard result: $res2"
if ($res2 -eq "rejected") {
    $test2Pass = $true
    Write-Host "  PASS: Different valid64hex digest rejected (guard correctly detects mismatch)" -ForegroundColor Green
}
else {
    Write-Host "  FAIL: Different valid64hex digest unexpectedly accepted" -ForegroundColor Red
}
Write-Host ""

# === TEST 3a: Missing digest semantics (bypass) ===
Write-Host "=== TEST 3a: Missing digest semantics (bypass) ==="
$res3a = Invoke-GuardCode -Code $guardSource -ArchivePath $testFile -AssetDigest $null
Write-Host "  Guard result for empty digest: $res3a"
if ($res3a -eq "accepted") {
    $test3aPass = $true
    Write-Host "  PASS: Missing digest correctly skipped (guard bypassed, no exception)" -ForegroundColor Green
}
else {
    Write-Host "  FAIL: Missing digest triggered rejection/exception" -ForegroundColor Red
}
Write-Host ""

# === TEST 3b: Malformed digest (wrong prefix/length) semantics retained ===
Write-Host "=== TEST 3b: Malformed digest (wrong prefix/length) semantics retained ==="
$malformedDigests = @(
    "md5:$actualHash",
    "sha256:tooshort",
    "sha256:" + ("a" * 63),
    "sha256:" + ("a" * 65),
    "notadigest"
)
$allMalformedBypassed = $true
foreach ($md in $malformedDigests) {
    $r = Invoke-GuardCode -Code $guardSource -ArchivePath $testFile -AssetDigest $md
    if ($r -ne "accepted") {
        $allMalformedBypassed = $false
        Write-Host "    Malformed digest '$md' was NOT bypassed (result: $r)" -ForegroundColor Red
    }
}
if ($allMalformedBypassed) {
    $test3bPass = $true
    Write-Host "  PASS: All malformed digests correctly bypassed" -ForegroundColor Green
}
else {
    Write-Host "  FAIL: Some malformed digests caused rejection" -ForegroundColor Red
}
Write-Host ""

# === SUMMARY ===
Write-Host "=== SUMMARY ==="
Write-Host "  Test 1 (matching digest accepted): $test1Pass"
Write-Host "  Test 2 (different digest rejected): $test2Pass"
Write-Host "  Test 3a (missing digest bypassed): $test3aPass"
Write-Host "  Test 3b (malformed digests bypassed): $test3bPass"

$allPass = $test1Pass -and $test2Pass -and $test3aPass -and $test3bPass
if ($allPass) {
    Write-Host "  OVERALL: All core tests PASSED" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "  OVERALL: Some tests FAILED" -ForegroundColor Red
    exit 1
}