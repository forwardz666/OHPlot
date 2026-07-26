$objdump = 'C:\Users\Forwardz\AppData\Local\OpenHarmony\Sdk\26.0.0\native\llvm\bin\llvm-objdump.exe'
$so = 'c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so'
$syms = @(
  '_ZN32QOpenHarmonyPlatformInputContext10mousePressEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE',
  '_ZN32QOpenHarmonyPlatformInputContext12mouseReleaseEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE',
  '_ZN32QOpenHarmonyPlatformInputContext9mouseMoveEP20QOpenHarmonyJsWindowffN2Qt11MouseButtonE'
)
$out = 'c:\Users\Forwardz\scidavis-ohos\ohos\tools\mousePressMove.asm'
Remove-Item $out -ErrorAction SilentlyContinue
foreach ($s in $syms) {
  & $objdump --disassemble-symbols=$s $so 2>$null | Out-File -Append -Encoding utf8 $out
}
$l = Get-Content $out
Write-Host ("total asm lines: " + $l.Count)
