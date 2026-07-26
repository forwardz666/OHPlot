$objdump = 'C:\Users\Forwardz\AppData\Local\OpenHarmony\Sdk\26.0.0\native\llvm\bin\llvm-objdump.exe'
$so = 'c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so'
& $objdump --disassemble-symbols=_ZN22QOpenHarmonyXComponent18dispatchMouseEventEP19OH_NativeXComponentPv $so > c:\Users\Forwardz\scidavis-ohos\ohos\tools\dispatchMouseEvent.asm 2>$null
$l = Get-Content c:\Users\Forwardz\scidavis-ohos\ohos\tools\dispatchMouseEvent.asm
Write-Host ("dispatchMouseEvent asm lines: " + $l.Count)
