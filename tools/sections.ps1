$readelf = 'C:\Users\Forwardz\AppData\Local\OpenHarmony\Sdk\26.0.0\native\llvm\bin\llvm-readelf.exe'
$so = 'c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so'
& $readelf -S $so | Select-String '\.data|\.rodata|\.bss|Name|rel\.ro'
