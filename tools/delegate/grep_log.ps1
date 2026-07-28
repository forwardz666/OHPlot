# grep hilog_p3.txt for a pattern, print last N matching lines
param(
  [string]$Pattern = 'menu',
  [int]$Last = 20,
  [string]$LogPath = 'C:\Users\Forwardz\scidavis-ohos\ohos\hilog_p3.txt'
)
Select-String -Path $LogPath -Pattern $Pattern |
  Select-Object -Last $Last |
  ForEach-Object { $_.Line }
