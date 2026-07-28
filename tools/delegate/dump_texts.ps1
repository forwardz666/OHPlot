# Extract menu-bar title texts with bounds from a uitest dumpLayout json
param(
  [string]$LayoutPath = 'C:\Users\Forwardz\scidavis-ohos\ohos\tools\shots\layout_j.json'
)
$raw = Get-Content $LayoutPath -Raw
$pattern = '"bounds":"(\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\])"[^{}]*?"text":"([^"]+)","type":"Text"'
[regex]::Matches($raw, $pattern) | ForEach-Object {
  '{0}  {1}' -f $_.Groups[2].Value, $_.Groups[1].Value
}
