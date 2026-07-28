"""Toolbar button-by-button regression driver v2 (plan step vf-verify).

Fixes over v1: hdc-disconnect auto-reconnect (wireless hdcd drops under
uitest load), stale-dump guard (recv to a fresh file each time), bilingual
not-adapted matching, and dialog-specific text assertions ('Columns to
plot' / 'Import ASCII Data') instead of the ambiguous 'Plot' menubar hit.
"""
import json
import os
import subprocess
import sys
import time

TARGET = '192.168.0.116:37147'
HDC = ['hdc', '-t', TARGET]
TMP = r'C:\Users\Forwardz\scidavis-ohos\ohos\tools\_vt_dump.json'
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


def click(x, y=96):
    sh('uitest', 'uiInput', 'click', str(x), str(y))


def hilog_clear():
    sh('hilog', '-r')


def hilog_grab():
    return sh('hilog -x | grep QtInput', timeout=90)


def dump():
    for attempt in range(3):
        sh('uitest', 'dumpLayout', '-p', '/data/local/tmp/_vt.json')
        if os.path.exists(TMP):
            os.remove(TMP)
        out = raw(HDC + ['file', 'recv', '/data/local/tmp/_vt.json', TMP])
        if os.path.exists(TMP):
            try:
                return json.load(open(TMP, encoding='utf-8'))
            except json.JSONDecodeError:
                pass
        print('    (dump retry)', flush=True)
        reconnect()
    raise RuntimeError('dumpLayout failed after retries')


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
            b = a['bounds']
            x1, y1, x2, y2 = [int(v) for v in
                              b.replace('[', ' ').replace(']', ' ').replace(',', ' ').split()]
            pos = ((x1 + x2) // 2, (y1 + y2) // 2)
            # exact match wins: 'Line' must not resolve to 'Vertical Drop
            # Lines' (substring hit) when both are menu entries
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


def expect_not_adapted(name, cx, cy=96):
    click(cx, cy)
    shown = False
    d = None
    # poll: dialog render can lag behind the click under uitest load, and a
    # missed dialog then eats the next test's click (autoCancel dismiss)
    for _ in range(3):
        time.sleep(1.2)
        d = dump()
        if find_text(d, NOT_ADAPTED):
            shown = True
            break
    closed = close_if(d, '确定') if shown else False
    report(name, shown and closed, 'not-adapted dialog' if shown else 'dialog missing')


def expect_hilog(name, cx, pattern, cy=96):
    hilog_clear()
    click(cx, cy)
    time.sleep(1.5)
    log = hilog_grab()
    ok = pattern in log
    d = dump()
    dlg = find_text(d, NOT_ADAPTED)
    if dlg:
        close_if(d, '确定')
    report(name, ok and dlg is None, f"log~'{pattern}'={ok} dlg={'y' if dlg else 'n'}")


def expect_disabled(name, cx, cy=96):
    hilog_clear()
    click(cx, cy)
    time.sleep(1.2)
    log = hilog_grab()
    fired = ('menu click' in log) or ('fallback menuAction' in log)
    d = dump()
    dlg = find_text(d, NOT_ADAPTED)
    if dlg:
        close_if(d, '确定')
    report(name, (not fired) and dlg is None, f'fired={fired} dlg={"y" if dlg else "n"}')


def expect_dialog(name, cx, marker, close_btn='Cancel'):
    click(cx)
    ok = False
    d = None
    for _ in range(3):
        time.sleep(1.2)
        d = dump()
        if find_text(d, marker):
            ok = True
            break
    if ok:
        close_if(d, close_btn)
    else:
        close_if(d, ['确定', 'Cancel', '取消'])  # sweep whatever popped up
        click(650, 700)  # dismiss a possibly stuck bindMenu popup
        time.sleep(0.8)
    report(name, ok, f"dialog '{marker}' {'ok' if ok else 'missing'}")


def open_dropdown(cx, item):
    # bindMenu popups occasionally swallow the first uiInput click on
    # device (seen live: 1st click no-op, 2nd click opens) — retry.
    for _ in range(3):
        click(cx)
        time.sleep(1.2)
        d = dump()
        pos = find_text(d, item)
        if pos:
            return pos
    return None


def menu_then_dialog(name, cx, item, marker, close_btn):
    pos = open_dropdown(cx, item)
    if not pos:
        report(name, False, f"menu item '{item}' not shown")
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
        close_if(d, close_btn)
    else:
        close_if(d, ['确定', 'Cancel', '取消'])  # sweep whatever popped up
        click(650, 700)  # dismiss a possibly stuck bindMenu popup
        time.sleep(0.8)
    report(name, ok, f"menu->'{marker}' {'ok' if ok else 'missing'}")


def menu_then_hilog(name, cx, item, pattern):
    pos = open_dropdown(cx, item)
    if not pos:
        report(name, False, f"menu item '{item}' not shown")
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


def ensure_log_panel_closed():
    # Blind 737-toggles can desync (a dropped uiInput click flips parity),
    # leaving the Results Log panel up; close it via its ✕ if present.
    d = dump()
    if find_text(d, 'Results Log'):
        pos = find_text(d, '✕')
        if pos:
            click(pos[0], pos[1])
            time.sleep(1)


def run():
    # Clean restart: default Table window, all panels closed, scroll at left.
    sh('aa', 'force-stop', 'org.scidavis.ohos')
    time.sleep(2)
    sh('aa', 'start', '-a', 'OHPlotAbility', '-b', 'org.scidavis.ohos')
    time.sleep(9)

    # 0 new_project: confirmation AlertDialog -> cancel
    click(41)
    time.sleep(1.5)
    d = dump()
    if find_text(d, '确定新建项目'):
        ok = close_if(d, '取消')
        report('new_project', ok, 'confirm dialog cancelled')
    else:
        report('new_project', False, 'confirm dialog missing')

    # 1 new_aspect dropdown -> New Note bridged via menuAction
    menu_then_hilog('new_aspect>new_notes', 107, 'New Note',
                    'fallback menuAction(new_notes)')

    # 2 open: system picker -> return
    click(173)
    time.sleep(3.5)
    d = dump()
    if find_text(d, 'Analysis') is None:  # left our UI -> picker up
        if not close_if(d, ['取消', 'Cancel']):
            sh('uitest', 'uiInput', 'keyEvent', 'Back')
            time.sleep(2)
        back = find_text(dump(), 'Analysis') is not None
        report('open', back, 'picker opened+returned')
    else:
        report('open', False, 'picker did not open')

    expect_not_adapted('open_template', 239)
    expect_dialog('import', 305, 'Import ASCII Data')
    # 5 save: silent sandbox save, no dialog expected
    click(371)
    time.sleep(2.5)
    d = dump()
    dlg = find_text(d, NOT_ADAPTED)
    if dlg:
        close_if(d, '确定')
    if find_text(d, 'Analysis') is None:
        if not close_if(d, ['取消', 'Cancel']):
            sh('uitest', 'uiInput', 'keyEvent', 'Back')
            time.sleep(2)
    report('save', dlg is None, 'no not-adapted dialog')
    expect_not_adapted('save_template', 437)
    expect_not_adapted('print', 521)
    expect_not_adapted('export_pdf', 587)
    expect_hilog('project_browser', 671, 'menu click: project_browser')
    click(671); time.sleep(1)   # restore
    expect_hilog('log', 737, 'menu click: log')
    click(737); time.sleep(1)   # restore
    ensure_log_panel_closed()

    # Edit group: undo/redo greying first (still no undoable action)
    expect_disabled('undo(disabled)', 822)
    expect_disabled('redo(disabled)', 888)

    # Precondition for cut..delete (hasWin) and the Plot groups (isTable):
    # a force-stop restart leaves an empty workspace, so create a Table via
    # the new_aspect dropdown before asserting on those buttons.
    click(107)
    time.sleep(1.2)
    d = dump()
    pos = find_text(d, 'New Table')
    if pos:
        click(pos[0], pos[1])
        time.sleep(2.5)
        # toggle the log panel twice: each click fires refreshUiState, so
        # the queued newTable mutation is reflected in the toolbar greying
        click(737); time.sleep(1)
        click(737); time.sleep(1.5)
        report('create_table', True, 'Table created (Edit/Plot precondition)')
    else:
        report('create_table', False, "dropdown 'New Table' missing")

    expect_hilog('cut', 954, 'fallback menuAction(cut)')
    expect_hilog('copy', 1020, 'fallback menuAction(copy)')
    expect_hilog('paste', 1086, 'paste dispatched')
    expect_hilog('delete', 1152, 'fallback menuAction(delete)')

    # Graph group: all greyed (no 2D plot window exists)
    for name, cx in [('graph_pointer', 1236), ('layers_menu', 1320),
                     ('curves_menu', 1386), ('text_menu', 1452),
                     ('zoom_in', 1536), ('zoom_out', 1602), ('rescale', 1668),
                     ('screen_reader', 1752), ('data_reader', 1818),
                     ('select_range', 1884)]:
        expect_disabled(f'{name}(greyed)', cx)

    # Plot group (Table active)
    menu_then_dialog('lines>plot_line', 1969, 'Line', 'Columns to plot', 'Cancel')
    menu_then_dialog('bars>plot_vertical_bars', 2035, 'Vertical Bars',
                     'Columns to plot', 'Cancel')
    for name, cx in [('plot_area', 2101), ('plot_pie', 2167),
                     ('plot_histogram', 2233), ('plot_box', 2299)]:
        expect_dialog(name, cx, 'Columns to plot')
    menu_then_dialog('vectors>plot_vect_xyxy', 2365, 'Vectors XYXY',
                     NOT_ADAPTED, '确定')

    # Plot3D tail: scroll left, click, scroll back
    sh('uitest', 'uiInput', 'swipe', '2300', '96', '1300', '96', '800')
    time.sleep(1.5)
    for name, cx in [('plot3d_ribbon', 2225), ('plot3d_bars', 2291),
                     ('plot3d_scatter', 2357), ('plot3d_trajectory', 2423)]:
        expect_not_adapted(name, cx)
    sh('uitest', 'uiInput', 'swipe', '300', '96', '2300', '96', '800')
    time.sleep(1)

    fails = [r for r in results if not r[1]]
    print(f"\n=== {len(results)} checks, {len(fails)} FAIL ===")
    for name, _, note in fails:
        print(f'  FAIL: {name}  {note}')
    sys.exit(1 if fails else 0)


run()
