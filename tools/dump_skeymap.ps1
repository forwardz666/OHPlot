$objdump = 'C:\Users\Forwardz\AppData\Local\OpenHarmony\Sdk\26.0.0\native\llvm\bin\llvm-objdump.exe'
$so = 'c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so'
# sKeyMap table base = 0x10c000 + 1776 = 0x10C6F0, entries of 24 bytes.
# Dump a generous window around it (0x10C600 .. 0x10D400) from whatever section holds it.
& $objdump -s --start-address=0x10C600 --stop-address=0x10D600 $so > c:\Users\Forwardz\scidavis-ohos\ohos\tools\skeymap_dump.txt 2>$null
Get-Content c:\Users\Forwardz\scidavis-ohos\ohos\tools\skeymap_dump.txt
