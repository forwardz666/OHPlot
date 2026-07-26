foreach ($f in @('c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libQt5Core.so',
                 'c:\Users\Forwardz\scidavis-ohos\ohos\entry\libs\arm64-v8a\libQt5Gui.so')) {
Write-Host "===== $(Split-Path $f -Leaf) ====="
$bytes = [System.IO.File]::ReadAllBytes($f)
$text = [System.Text.Encoding]::ASCII.GetString($bytes)
# Qt version string pattern "Qt 5.x.y"
[regex]::Matches($text, 'Qt 5\.[0-9]+\.[0-9]+') | ForEach-Object Value | Sort-Object -Unique | Select-Object -First 5
[regex]::Matches($text, 'QT_[A-Z_]*HIGHDPI[A-Z_]*|QT_[A-Z_]*SCALE[A-Z_]*') | ForEach-Object Value | Sort-Object -Unique
}
