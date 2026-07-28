# L3 fix1: T5 toolbar tooltip strings for base + en_US string.json (deepseek-v4-flash).
# NOTE: zh_CN is deliberately NOT delegated (past lesson: L3 corrupted Chinese JSON);
# the zh_CN side is done by L1 directly.
$root = 'c:\Users\Forwardz\scidavis-ohos'

$task = @'
Task: edit exactly two JSON resource files, appending 12 new string entries to each:
- ohos/entry/src/main/resources/base/element/string.json
- ohos/entry/src/main/resources/en_US/element/string.json
Do NOT touch ohos/entry/src/main/resources/zh_CN/element/string.json or any other file.

Both files have the structure { "string": [ { "name": "...", "value": "..." }, ... ] }.
Append the following 12 entries at the END of the "string" array in BOTH files
(identical English values in both), keeping the existing one-line-per-entry
formatting style ({ "name": "...", "value": "..." } on a single line, two-space indent):

toolbar_new_table  -> "New Table"
toolbar_open       -> "Open Project"
toolbar_save       -> "Save Project"
toolbar_import     -> "Import ASCII"
toolbar_export     -> "Export ASCII"
toolbar_cut        -> "Cut"
toolbar_copy       -> "Copy"
toolbar_paste      -> "Paste"
toolbar_undo       -> "Undo"
toolbar_redo       -> "Redo"
toolbar_plot_line  -> "Plot Line"
toolbar_plot_scatter -> "Plot Scatter"

Mind JSON validity: the previous last entry needs a trailing comma, the new last
entry must not have one. Reply done when finished, listing the two files touched.
'@

Set-Location $root
deveco run $task --model deepseek/deepseek-v4-flash 2>&1
