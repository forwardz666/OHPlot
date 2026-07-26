$objdump = 'C:\Users\Forwardz\AppData\Local\OpenHarmony\Sdk\26.0.0\native\llvm\bin\llvm-objdump.exe'
$so = 'c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so'
$syms = @(
  '_ZN32QOpenHarmonyPlatformInputContext16handleMouseEventERK21OpenHarmonyMouseEvent',
  '_ZN32QOpenHarmonyPlatformInputContext9touchDownEff'
)
$out = 'c:\Users\Forwardz\scidavis-ohos\ohos\tools\handleMouseEvent.asm'
Remove-Item $out -ErrorAction SilentlyContinue
foreach ($s in $syms) {
  & $objdump --disassemble-symbols=$s $so 2>$null | Out-File -Append -Encoding utf8 $out
}
$l = Get-Content $out
Write-Host ("total asm lines: " + $l.Count)
