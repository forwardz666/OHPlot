# Copy freshly built libentry.so to the three locations hvigorw packs from.
$src = 'C:\Users\Forwardz\scidavis-ohos\build-ohos\scidavis\libentry.so'
$dsts = @(
  'C:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libentry.so',
  'C:\Users\Forwardz\scidavis-ohos\ohos\entry\build\default\intermediates\libs\default\arm64-v8a\libentry.so',
  'C:\Users\Forwardz\scidavis-ohos\ohos\entry\build\default\intermediates\stripped_native_libs\default\arm64-v8a\libentry.so'
)
foreach ($d in $dsts) {
  $dir = Split-Path $d
  if (Test-Path $dir) {
    Copy-Item $src $d -Force
    Write-Host ("copied: " + $d)
  } else {
    Write-Host ("SKIP no dir: " + $d)
  }
}
