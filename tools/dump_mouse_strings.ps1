$f = 'c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so'
$bytes = [System.IO.File]::ReadAllBytes($f)
$sb = New-Object System.Text.StringBuilder
$strings = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $bytes.Length; $i++) {
  $b = $bytes[$i]
  if ($b -ge 32 -and $b -le 126) { [void]$sb.Append([char]$b) }
  else { if ($sb.Length -ge 6) { $strings.Add($sb.ToString()) }; [void]$sb.Clear() }
}
$strings | Where-Object { $_ -match '(?i)mouse|button|dispatch.*event|DispatchEvent' } | Sort-Object -Unique
