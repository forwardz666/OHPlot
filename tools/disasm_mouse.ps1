$objdump = 'C:\Users\Forwardz\AppData\Local\OpenHarmony\Sdk\26.0.0\native\llvm\bin\llvm-objdump.exe'
$nm = 'C:\Users\Forwardz\AppData\Local\OpenHarmony\Sdk\26.0.0\native\llvm\bin\llvm-nm.exe'
$so = 'c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so'
# Find the mouse event dispatch: handleMouseEvent(OpenHarmonyMouseEvent const&)
& $objdump --disassemble-symbols=_ZN32QOpenHarmonyPlatformInputContext16handleMouseEventERK21OpenHarmonyMouseEvent $so > c:\Users\Forwardz\scidavis-ohos\ohos\tools\handleMouseEvent.asm 2>$null
$l = Get-Content c:\Users\Forwardz\scidavis-ohos\ohos\tools\handleMouseEvent.asm
Write-Host ("handleMouseEvent asm lines: " + $l.Count)
$l | Select-Object -First 120
