$scriptPath = "C:\Users\jmwau\source\repos\mypal_package\scripts\Build-MypalPackage.ps1"
$scriptContent = Get-Content $scriptPath -Raw
$lines = $scriptContent -split "`n"
Write-Host "Total lines: $($lines.Count)"
for ($i = 0; $i -lt $lines.Count; $i++) {
    Write-Host "Line $($i+1): [$($lines[$i])]"
    if ($lines[$i] -eq 'param(') {
        Write-Host "  ** Found param( at line $($i+1) **"
        $j = $i + 1
        $blockLines = @()
        while ($j -lt $lines.Count -and $lines[$j] -ne ')') {
            $blockLines += $lines[$j]
            $j++
        }
        $paramBlock = $blockLines -join "`n"
        Write-Host "  Block collected $($blockLines.Count) lines:"
        Write-Host $paramBlock
        break
    }
}