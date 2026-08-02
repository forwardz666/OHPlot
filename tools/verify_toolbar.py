"""Toolbar regression driver v3 (task: toolbar regroup + occlusion fix).

Rewritten for the grouped, wrapping toolbar: buttons are located by their
ArkTS component id (tb_* / tbdrop_*) through `uitest dumpLayout` instead of
the old hard-coded x/y coordinates (which broke the moment the single-row
Scroll became a Flex(wrap) with context groups).

Flow:
  1. Clean restart -> default Table active.
  2. File/Edit always present; Plot + Plot3D groups present (Table active),
     Graph group absent.
  3. Fire a few File/Edit/Plot/3D buttons by id and assert the expected
     hilog / dialog / not-adapted outcome.
  4. Create a 2D Graph (new_aspect > New Graph) and activate it -> Graph
     group appears, Plot/Plot3D groups disappear (context switch).

The harness (auto-reconnect, stale-dump guard, bilingual not-adapted
matching) is inherited from v2.
"""
import json
import os
import subprocess
import sys
import time

TARGET = sys.argv[1] if len(sys.argv) > 1 else '192.168.0.116:46817'
HDC = ['hdc', '-t', TARGET]
TMP = os.path.join(os.path.dirname(os.path.abspath(__file__)), '_vt_dump.json')
NOT_ADAPTED = ['此功能还未适配完毕', 'not been adapted']


def raw(args, timeout=45):
    r = subprocess.run(args, capture_output=True, text=True,
                       encoding='utf-8', errors='replace', timeout=timeout)
    return (r.stdout or '') + (r.stderr or '')


def reconnect():
    for _ in range(12):
        out = raw(['hdc', 'tconn', TARGET])
        if 'OK' in out:
            time.sleep(1)
            return True
        time.sleep(5)
    return False


def sh(*args, timeout=45):
    for attempt in range(3):
        out = raw(HDC + ['shell'] + list(args), timeout=timeout)
        if '[Fail]' not in out and 'Device not found' not in out:
            return out
        print(f'    (hdc dropped, reconnecting: {args[:2]})', flush=True)
        reconnect()
    raise RuntimeError(f'hdc shell failed after retries: {args}')


def click(x, y):
    sh('uitest', 'uiInput', 'click', str(int(x)), str(int(y)))


def hilog_clear():
    sh('hilog', '-r')


def hilog_grab():
    return sh('hilog -x | grep QtInput', timeout=90)


def dump():
    for attempt in range(3):
        sh('uitest', 'dumpLayout', '-p', '/data/local/tmp/_vt.json')
        if os.path.exists(TMP):
            os.remove(TMP)
        raw(HDC + ['file', 'recv', '/data/local/tmp/_vt.json', TMP])
        if os.path.exists(TMP):
            try:
                return json.load(open(TMP, encoding='utf-8'))
            except json.JSONDecodeError:
                pass
        print('    (dump retry)', flush=True)
        reconnect()
    raise RuntimeError('dumpLayout failed after retries')


def _center(bounds):
    x1, y1, x2, y2 = [int(v) for v in
                      bounds.replace('[', ' ').replace(']', ' ')
                      .replace(',', ' ').split()]
    return ((x1 + x2) // 2, (y1 + y2) // 2)


def find_id(d, comp_id):
    """Locate a component by its ArkTS id (dumpLayout 'key' attribute).

    Returns the click center, or None when the component is absent (a
    context group that is hidden for the active window type)."""
    stack = [d]
    while stack:
        n = stack.pop()
        a = n.get('attributes', {})
        if a.get('key', '') == comp_id or a.get('id', '') == comp_id:
            b = a.get('bounds', '')
            if b:
                return _center(b)
        stack.extend(n.get('children', []))
    return None


def find_text(d, substrs):
    if isinstance(substrs, str):
        substrs = [substrs]
    exact = None
    partial = None
    stack = [d]
    while stack:
        n = stack.pop()
        a = n.get('attributes', {})
        t = a.get('text', '')
        if t:
            pos = _center(a['bounds'])
            if any(s == t for s in substrs):
                exact = pos
            elif partial is None and any(s in t for s in substrs):
                partial = pos
        stack.extend(n.get('children', []))
    return exact if exact else partial


def close_if(d, labels):
    pos = find_text(d, labels)
    if pos:
        click(pos[0], pos[1])
        time.sleep(1)
        return True
    return False


results = []


def report(name, ok, note=''):
    results.append((name, ok, note))
    print(f"{'PASS' if ok else 'FAIL'}  {name}  {note}", flush=True)


def click_id(comp_id):
    """Click a toolbar button by id; returns False if not present."""
    pos = find_id(dump(), comp_id)
    if not pos:
        return False
    click(pos[0], pos[1])
    return True


def expect_group_present(name, comp_id, present=True):
    pos = find_id(dump(), comp_id)
    ok = (pos is not None) == present
    report(name, ok, f"id '{comp_id}' {'found' if pos else 'absent'} "
                     f"(want {'present' if present else 'absent'})")
    return pos


def expect_button_hilog(name, comp_id, pattern):
    pos = find_id(dump(), comp_id)
    if not pos:
        report(name, False, f"button id '{comp_id}' not found")
        return
    hilog_clear()
    click(pos[0], pos[1])
    time.sleep(1.5)
    log = hilog_grab()
    ok = pattern in log
    d = dump()
    if find_text(d, NOT_ADAPTED):
        close_if(d, '确定')
    report(name, ok, f"log~'{pattern}'={ok}")


def expect_button_dialog(name, comp_id, marker, close_btn=('取消', 'Cancel')):
    pos = find_id(dump(), comp_id)
    if not pos:
        report(name, False, f"button id '{comp_id}' not found")
        return
    click(pos[0], pos[1])
    ok = False
    d = None
    for _ in range(3):
        time.sleep(1.2)
        d = dump()
        if find_text(d, marker):
            ok = True
            break
    if ok:
        close_if(d, list(close_btn))
    else:
        close_if(d, ['确定', 'Cancel', '取消'])
        click(650, 700)
        time.sleep(0.8)
    report(name, ok, f"dialog '{marker[0]}' {'ok' if ok else 'missing'}")


def open_dropdown_id(comp_id, item):
    for _ in range(3):
        pos = find_id(dump(), comp_id)
        if not pos:
            return None
        click(pos[0], pos[1])
        time.sleep(1.2)
        d = dump()
        ipos = find_text(d, item)
        if ipos:
            return ipos
    return None


def dropdown_then_hilog(name, comp_id, item, pattern):
    ipos = open_dropdown_id(comp_id, item)
    if not ipos:
        report(name, False, f"drop id '{comp_id}' item '{item[0]}' not shown")
        return
    hilog_clear()
    click(ipos[0], ipos[1])
    time.sleep(1.5)
    log = hilog_grab()
    ok = pattern in log
    d = dump()
    if find_text(d, NOT_ADAPTED):
        close_if(d, '确定')
    report(name, ok, f"log~'{pattern}'={ok}")


def create_via_new_aspect(item_text):
    """Open the File>New Aspect dropdown and pick an item by text."""
    ipos = open_dropdown_id('tbdrop_new_aspect', item_text)
    if not ipos:
        return False
    click(ipos[0], ipos[1])
    time.sleep(2.5)
    return True


def run():
    # Clean restart: default Table window active.
    sh('aa', 'force-stop', 'org.scidavis.ohos')
    time.sleep(2)
    sh('aa', 'start', '-a', 'OHPlotAbility', '-b', 'org.scidavis.ohos')
    time.sleep(9)

    # --- Groups present for the default Table window ---
    expect_group_present('file_group', 'tb_new_project', True)
    expect_group_present('edit_group', 'tb_undo', True)
    expect_group_present('plot_group(Table)', 'tb_plot_area', True)
    expect_group_present('plot3d_group(Table)', 'tb_plot3d_ribbon', True)
    expect_group_present('graph_group_absent(Table)', 'tb_zoom_in', False)

    # --- Plot group (must run while the default Table is still active:
    # the new_notes test below activates a Note, hiding these groups) ---
    expect_button_dialog('plot_area', 'tb_plot_area',
                         ['要绘制的列', 'Columns to plot'])
    expect_button_dialog('plot_pie', 'tb_plot_pie',
                         ['要绘制的列', 'Columns to plot'])

    # --- Plot3D tail ---
    expect_button_not_adapted('plot3d_ribbon', 'tb_plot3d_ribbon')

    # --- File group buttons ---
    # Dialog/menu texts are locale-dependent: match zh_CN first, en fallback.
    dropdown_then_hilog('new_aspect>new_notes', 'tbdrop_new_aspect',
                        ['新建注释', 'New Note'],
                        'fallback menuAction(new_notes)')
    expect_button_dialog('import', 'tb_import',
                         ['导入 ASCII 数据', 'Import ASCII Data'])
    expect_button_hilog('project_browser', 'tb_project_browser',
                        'menu click: project_browser')
    if click_id('tb_project_browser'):  # restore (toggle off)
        time.sleep(1)

    # --- Edit group: undo greyed (no undoable action yet) ---
    hilog_clear()
    if click_id('tb_undo'):
        time.sleep(1.2)
    log = hilog_grab()
    fired = ('menu click' in log) or ('fallback menuAction' in log)
    report('undo(disabled)', not fired, f'fired={fired}')

    # --- Context switch: create + activate a 2D Graph ---
    ok = create_via_new_aspect(['新建图形', 'New Graph'])
    # a few refreshUiState pumps so the queued newGraph reflects in greying
    if click_id('tb_project_browser'):
        time.sleep(1)
        click_id('tb_project_browser')
        time.sleep(1.5)
    report('create_graph', ok, 'new_graph via New Aspect')

    expect_group_present('graph_group(Graph)', 'tb_zoom_in', True)
    expect_group_present('plot_group_absent(Graph)', 'tb_plot_area', False)
    expect_group_present('plot3d_group_absent(Graph)', 'tb_plot3d_ribbon',
                         False)

    fails = [r for r in results if not r[1]]
    print(f"\n=== {len(results)} checks, {len(fails)} FAIL ===")
    for name, _, note in fails:
        print(f'  FAIL: {name}  {note}')
    sys.exit(1 if fails else 0)


def expect_button_not_adapted(name, comp_id):
    pos = find_id(dump(), comp_id)
    if not pos:
        report(name, False, f"button id '{comp_id}' not found")
        return
    click(pos[0], pos[1])
    shown = False
    d = None
    for _ in range(3):
        time.sleep(1.2)
        d = dump()
        if find_text(d, NOT_ADAPTED):
            shown = True
            break
    if shown:
        close_if(d, '确定')
    report(name, shown, 'not-adapted dialog' if shown else 'dialog missing')


run()
