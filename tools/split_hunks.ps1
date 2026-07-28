# Extract selected hunks (per-file 1-based indexes) from a git diff patch.
# Usage: split_hunks.ps1 -Patch full.patch -File a/path/in/diff -Hunks 1,4 -Out sub.patch
param(
    [string]$Patch,
    [string]$File,
    [string]$HunksCsv,
    [string]$Out
)
$Hunks = @($HunksCsv -split ',' | ForEach-Object { [int]$_ })
# Byte-safe: the patch must be produced with git diff --output=... (raw UTF-8);
# read/write via .NET so PowerShell never transcodes the UTF-8 payload.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$lines = [System.IO.File]::ReadAllLines($Patch, $utf8NoBom)
$result = @()
$inFile = $false
$header = @()
$hunkIdx = 0
$keep = $false
foreach ($ln in $lines) {
    if ($ln -match '^diff --git a/(.+) b/') {
        $inFile = ($Matches[1] -eq $File)
        $hunkIdx = 0
        $keep = $false
        if ($inFile) { $header = @($ln) }
        continue
    }
    if (-not $inFile) { continue }
    if ($ln -match '^@@ ') {
        $hunkIdx++
        $keep = ($Hunks -contains $hunkIdx)
        if ($keep) {
            if ($header.Count) { $result += $header; $header = @() }
            $result += $ln
        }
        continue
    }
    if ($hunkIdx -eq 0) { $header += $ln; continue }  # index/---/+++ lines
    if ($keep) { $result += $ln }
}
[System.IO.File]::WriteAllText($Out, (($result -join "`n") + "`n"), $utf8NoBom)
Write-Output ("wrote " + $result.Count + " lines to " + $Out)
