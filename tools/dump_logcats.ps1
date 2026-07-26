# Extract Qt logging category names (qt.qpa.*) from QPA plugin and QtGui
$files = @(
  'c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so',
  'c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libQt5Gui.so'
)
foreach ($f in $files) {
  if (-not (Test-Path $f)) { Write-Host "MISSING: $f"; continue }
  Write-Host "===== $(Split-Path $f -Leaf) ====="
  $bytes = [System.IO.File]::ReadAllBytes($f)
  $sb = New-Object System.Text.StringBuilder
  $strings = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $bytes.Length; $i++) {
    $b = $bytes[$i]
    if ($b -ge 32 -and $b -le 126) {
      [void]$sb.Append([char]$b)
    } else {
      if ($sb.Length -ge 5) { $strings.Add($sb.ToString()) }
      [void]$sb.Clear()
    }
  }
  if ($sb.Length -ge 5) { $strings.Add($sb.ToString()) }
  $strings | Where-Object { $_ -match '^qt\.' } | Sort-Object -Unique
}
