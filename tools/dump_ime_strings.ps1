$b = [IO.File]::ReadAllBytes('c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so')
$s = [System.Text.Encoding]::ASCII.GetString($b)
$rx = [regex]'[\x20-\x7e]{4,}'
$ms = $rx.Matches($s) | ForEach-Object { $_.Value }
Write-Host '=== IME / keyboard related strings ==='
$ms | Where-Object { $_ -match 'InputMethod|inputmethod|attach|Attach|TextInput|textInput|SoftKeyboard|softKeyboard|InputPanel|inputPanel' } | Sort-Object -Unique
Write-Host '=== InputContext class methods (mangled) ==='
$ms | Where-Object { $_ -match 'InputContext' } | Sort-Object -Unique | Select-Object -First 60
