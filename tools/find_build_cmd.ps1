$hits = Select-String -Path 'C:\Users\Forwardz\.qoder\cache\projects\ohos-26875d27\conversation-history\task-a56\task-a56.jsonl' -Pattern 'hvigorw|assembleHap|hdc.*install' 
$cmds = @()
foreach ($h in $hits) {
  foreach ($m in [regex]::Matches($h.Line, '[^"\\]*(?:hvigorw|assembleHap|hdc)[^"\\]{0,160}')) { $cmds += $m.Value.Trim() }
}
$cmds | Sort-Object -Unique | Select-Object -First 25
