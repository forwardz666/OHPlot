# Fill Table1 cells for the e2e user-story check (coords are physical px).
$T = '192.168.0.116:37147'
$cells = @(
  @(104, 223, '10'),
  @(104, 262, '20'),
  @(225, 184, '5'),
  @(225, 223, '15'),
  @(225, 262, '25')
)
foreach ($c in $cells) {
  hdc -t $T shell uitest uiInput doubleClick $c[0] $c[1] | Out-Null
  Start-Sleep -Milliseconds 500
  hdc -t $T shell uitest uiInput text $c[2] | Out-Null
  Start-Sleep -Milliseconds 300
  hdc -t $T shell uitest uiInput keyEvent 2054 | Out-Null
  Start-Sleep -Milliseconds 300
}
Write-Output 'fill done'
