$objdump = 'C:\Users\Forwardz\AppData\Local\OpenHarmony\Sdk\26.0.0\native\llvm\bin\llvm-objdump.exe'
$so = 'c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so'
$sym = '_ZN32QOpenHarmonyPlatformInputContext14handleKeyEventERK19OpenHarmonyKeyEvent'
& $objdump --disassemble-symbols=$sym $so > c:\Users\Forwardz\scidavis-ohos\ohos\tools\handleKeyEvent.asm 2>$null
$lines = Get-Content c:\Users\Forwardz\scidavis-ohos\ohos\tools\handleKeyEvent.asm
Write-Host ("total asm lines: " + $lines.Count)
# Extract immediate constants moved into w-registers (potential key codes)
$consts = $lines | Select-String 'mov\s+w\d+, #(0x[0-9a-f]+|\d+)' | ForEach-Object {
    if ($_ -match '#(0x[0-9a-f]+|\d+)') {
        $v = $Matches[1]
        if ($v.StartsWith('0x')) { [Convert]::ToInt32($v.Substring(2),16) } else { [int]$v }
    }
} | Sort-Object -Unique
Write-Host '=== immediate constants in handleKeyEvent (decimal) ==='
$consts -join ', '
