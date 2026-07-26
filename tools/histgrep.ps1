$hits = Select-String -Path 'C:\Users\Forwardz\.qoder\cache\projects\ohos-26875d27\conversation-history\task-a56\task-a56.jsonl' -Pattern 'hvigor'
$out = @()
foreach ($h in $hits) {
  foreach ($m in [regex]::Matches($h.Line, '.{0,120}hvigor.{0,80}')) { $out += $m.Value.Trim() }
}
$out | Sort-Object -Unique | Select-Object -First 30
