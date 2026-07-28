# Parse a uitest dumpLayout JSON: print every node with non-empty text.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File dump_texts.ps1 <layout.json>
param([string]$Path)
$j = Get-Content $Path -Raw | ConvertFrom-Json
$q = [System.Collections.Queue]::new()
$q.Enqueue($j)
while ($q.Count) {
    $n = $q.Dequeue()
    if ($n.attributes -and $n.attributes.text -and $n.attributes.text -ne '') {
        Write-Output ($n.attributes.text + ' | ' + $n.attributes.bounds + ' | ' + $n.attributes.type)
    }
    foreach ($c in $n.children) { $q.Enqueue($c) }
}
