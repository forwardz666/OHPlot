param([string[]]$Files)
foreach ($f in $Files) {
  try {
    Get-Content $f -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null
    Write-Output "$f OK"
  } catch {
    Write-Output "$f BAD: $($_.Exception.Message)"
  }
}
