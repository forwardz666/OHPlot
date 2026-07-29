"""On-device bilingual (en/zh) verification driver (plan step verify).

Flow: ensure English -> assert English UI -> switch to Simplified Chinese
via Edit > Preferences > Language -> assert Chinese UI + no residual
English labels -> force-stop/restart -> assert the language persisted ->
switch back to English -> assert.  Screenshots are captured in both
states; the FaultLogger stream is checked for new cppcrash/appfreeze.

Reuses the verify_toolbar.py harness (auto-reconnect, fresh-file dumps).
"""
import json
import os
import subprocess
import sys
import time

TARGET = sys.argv[1] if len(sys.argv) > 1 else '192.168.0.116:46817'
HDC = ['hdc', '-t', TARGET]
TOOLS = os.path.dirname(os.path.abspath(__file__))
TMP = os.path.join(TOOLS, '_i18n_dump.json')
BUNDLE = 'org.scidavis.ohos'

# Exact-match texts that must NOT appear anywhere in the Chinese UI tree.
# Exact equality keeps Qt object names like 'Table1' out of scope.
EN_BANNED = [
    'File', 'Edit', 'View', 'Help', 'Windows', 'Analysis',
    'New Project', 'New Table', 'Preferences...', 'Results Log',
    'Cancel', 'Apply', 'OK', 'Close', 'Clear', 'Refresh',
    'General', 'Tables', 'Plots', 'Language', 'Follow System',
]
# ... and these must not appear in the English UI tree.
ZH_BANNED = ['文件', '编辑', '视图', '帮助', '新建表格', '首选项...', '取消', '应用']


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
    sh('uitest', 'uiInput', 'click', str(x), str(y))


def dump():
    for attempt in range(3):
        sh('uitest', 'dumpLayout', '-p', '/data/local/tmp/_i18n.json')
        if os.path.exists(TMP):
            os.remove(TMP)
        raw(HDC + ['file', 'recv', '/data/local/tmp/_i18n.json', TMP])
        if os.path.exists(TMP):
            try:
                return json.load(open(TMP, encoding='utf-8'))
            except json.JSONDecodeError:
                pass
        print('    (dump retry)', flush=True)
        reconnect()
    raise RuntimeError('dumpLayout failed after retries')


def all_texts(d):
    out = []
    stack = [d]
    while stack:
        n = stack.pop()
        t = n.get('attributes', {}).get('text', '')
        if t:
            out.append(t)
        stack.extend(n.get('children', []))
    return out


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
            if any(s == t for s in substrs):
                exact = pos
            elif partial is None and any(s in t for s in substrs):
                partial = pos
        stack.extend(n.get('children', []))
    return exact if exact else partial


results = []


def report(name, ok, note=''):
    results.append((name, ok, note))
    print(f"{'PASS' if ok else 'FAIL'}  {name}  {note}", flush=True)


def click_text(d, labels, name):
    pos = find_text(d, labels)
    if not pos:
        report(name, False, f'{labels} not found')
        return False
    click(pos[0], pos[1])
    time.sleep(1.2)
    return True


def restart_app(settle=9):
    sh('aa', 'force-stop', BUNDLE)
    time.sleep(2)
    sh('aa', 'start', '-a', 'OHPlotAbility', '-b', BUNDLE)
    time.sleep(settle)


def screenshot(tag):
    dev = f'/data/local/tmp/i18n_{tag}.jpeg'
    sh('snapshot_display', '-f', dev)
    local = os.path.join(TOOLS, f'i18n_{tag}.jpeg')
    if os.path.exists(local):
        os.remove(local)
    raw(HDC + ['file', 'recv', dev, local])
    report(f'screenshot_{tag}', os.path.exists(local), local)


def switch_language(option_labels, step):
    """Edit > Preferences... > Language Select > option > Apply."""
    d = dump()
    if not click_text(d, ['Edit', '编辑'], f'{step}:open_edit'):
        return False
    d = dump()
    if not click_text(d, ['Preferences...', '首选项...'], f'{step}:open_prefs'):
        return False
    d = dump()
    # The Select shows the current language; open its option popup.
    if not click_text(d, ['Follow System', 'English', '简体中文', '跟随系统'],
                      f'{step}:open_select'):
        return False
    d = dump()
    if not click_text(d, option_labels, f'{step}:pick_option'):
        return False
    d = dump()
    if not click_text(d, ['Apply', '应用'], f'{step}:apply'):
        return False
    time.sleep(2.5)  # config-update -> langTick -> rebuildMenus
    return True


def assert_labels(step, present, banned):
    d = dump()
    texts = all_texts(d)
    missing = [p for p in present if find_text(d, p) is None]
    residue = sorted(set(t for t in texts if t in banned))
    report(f'{step}:labels', not missing, f'missing={missing}' if missing else 'all present')
    report(f'{step}:no_residue', not residue, f'residue={residue}' if residue else 'clean')
    return d


def run():
    fault_before = sh('hilog -x -T FaultLogger | grep -cE "cppcrash|appfreeze" || true',
                      timeout=60).strip()

    restart_app()

    # 0) Normalize to English (device may follow a Chinese system locale).
    d = dump()
    if find_text(d, '文件') and not find_text(d, 'File'):
        if not switch_language(['English'], 'to_en0'):
            report('normalize_english', False, 'switch failed')
        time.sleep(1)
    report('normalize_english', find_text(dump(), 'File') is not None, 'menubar File visible')

    # 1) English state: menubar + Edit dropdown + Preferences dialog labels.
    d = assert_labels('en', ['File', 'Edit', 'View', 'Help'], ZH_BANNED)
    if click_text(d, 'Edit', 'en:edit_menu'):
        d = dump()
        report('en:prefs_item', find_text(d, 'Preferences...') is not None, 'Edit dropdown')
        if click_text(d, 'Preferences...', 'en:open_prefs'):
            d = dump()
            ok = all(find_text(d, t) is not None
                     for t in ['General', 'Language', 'English', 'Apply'])
            report('en:prefs_dialog', ok, 'General/Language/English/Apply')
            click_text(d, 'Cancel', 'en:close_prefs')
    screenshot('en')

    # 2) Switch to Simplified Chinese and assert.
    if switch_language(['简体中文'], 'to_zh'):
        d = assert_labels('zh', ['文件', '编辑', '视图', '帮助'], EN_BANNED)
        if click_text(d, '文件', 'zh:file_menu'):
            d = dump()
            report('zh:file_dropdown', find_text(d, '新建表格') is not None, '新建表格 visible')
            # Close the dropdown by clicking empty canvas area — keyEvent
            # Back would background the whole app (screenshot then captures
            # the launcher instead of the UI).
            click(1200, 700)
            time.sleep(1)
        # Guard: app must still be foreground before taking evidence.
        report('zh:foreground', find_text(dump(), '文件') is not None, 'app in foreground')
        screenshot('zh')
    else:
        report('to_zh', False, 'language switch failed')

    # 3) Persistence: restart and assert Chinese survives.
    restart_app()
    report('zh:persisted', find_text(dump(), '文件') is not None, 'menubar 文件 after restart')

    # 4) Switch back to English and assert.
    if switch_language(['English'], 'to_en'):
        assert_labels('en2', ['File', 'Edit', 'View', 'Help'], ZH_BANNED)
    else:
        report('to_en', False, 'language switch failed')

    fault_after = sh('hilog -x -T FaultLogger | grep -cE "cppcrash|appfreeze" || true',
                     timeout=60).strip()
    report('faultlogger', fault_after == fault_before,
           f'before={fault_before} after={fault_after}')

    fails = [r for r in results if not r[1]]
    print(f"\n=== {len(results)} checks, {len(fails)} FAIL ===")
    for name, _, note in fails:
        print(f'  FAIL: {name}  {note}')
    sys.exit(1 if fails else 0)


run()
