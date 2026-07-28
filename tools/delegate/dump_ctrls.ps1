# Extract TextInput / Button / Toggle bounds from a uitest dumpLayout json
param(
  [string]$LayoutPath = 'C:\Users\Forwardz\scidavis-ohos\ohos\tools\shots\layout_d.json'
)
$raw = Get-Content $LayoutPath -Raw
$pattern = '"bounds":"(\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\])"[^{}]*?"type":"(TextInput|Button|Toggle)"'
[regex]::Matches($raw, $pattern) | ForEach-Object {
  '{0}  {1}' -f $_.Groups[2].Value, $_.Groups[1].Value
}
