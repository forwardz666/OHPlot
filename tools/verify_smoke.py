"""Project smoke-verification gate (single entry point).

Usage (from the project root):
    python tools/verify_smoke.py                 # static checks only (no device)
    python tools/verify_smoke.py --device <ip:port>   # + on-device drivers

Static checks (always run, repeatable, no device needed):
  S1  NAPI contract: every method exported by entry/src/main/cpp/qohos.cpp
      (napi_property_descriptor table) is declared by at least one ArkTS
      interface, and no ArkTS file calls a qohos method that qohos.cpp
      does not export.
  S2  ArkTS coding gate on key pages/components: no `: any`, no `require(`
      (DEVELOPMENT_GUIDE §1.1).
  S3  Deployable native library: entry/libs/arm64-v8a/libentry.so exists.
  S4  Diagnostic hygiene: repo root contains no *.jpeg / hilog_*.txt /
      crash*.txt / layout_*.json debris (must live in diagnostics/,
      DEVELOPMENT_GUIDE §7).

Device checks (only with --device):
  D1  tools/verify_toolbar.py <target>
  D2  tools/verify_i18n.py <target>

Exit code 0 = all PASS, 1 = at least one FAIL.  Any "fix complete" claim
for core changes must attach the output of this script (see
docs/DEVELOPMENT_GUIDE.md §8).
"""
import argparse
import glob
import os
import re
import subprocess
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
CPP = os.path.join(ROOT, 'entry', 'src', 'main', 'cpp', 'qohos.cpp')
ETS_DIR = os.path.join(ROOT, 'entry', 'src', 'main', 'ets')

# Key ArkTS surfaces for the S2 coding gate (bridge-critical files).
KEY_ETS = [
    'entryability/OHPlotAbility.ets',
    'pages/Index.ets',
    'pages/MainLayout.ets',
    'components/DataTable.ets',
    'components/QtEventHost.ets',
]

results = []


def report(name, ok, note=''):
    results.append((name, ok, note))
    print(f"{'PASS' if ok else 'FAIL'}  {name}  {note}", flush=True)


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def ets_files():
    return glob.glob(os.path.join(ETS_DIR, '**', '*.ets'), recursive=True)


def check_napi_contract():
    """S1: qohos.cpp descriptor table vs ArkTS interface/call sites."""
    src = read(CPP)
    # Exports from the napi_property_descriptor initializer: { "name", ...
    desc_block = re.search(r'napi_property_descriptor\s+desc\[\]\s*=\s*\{(.*?)\};',
                           src, re.S)
    if not desc_block:
        report('napi_exports_parse', False, 'descriptor table not found in qohos.cpp')
        return
    exports = set(re.findall(r'\{\s*"(\w+)"', desc_block.group(1)))
    report('napi_exports_parse', bool(exports), f'exports={sorted(exports)}')

    declared = set()   # methods declared on ArkTS interfaces for libqohos.so
    called = set()     # qohos.<method>( / qtInjector.<method>( call sites
    for f in ets_files():
        text = read(f)
        if 'libqohos.so' not in text and 'QohosInjector' not in text \
                and 'QohosNativeModule' not in text:
            continue
        for iface in re.finditer(
                r'interface\s+Qohos\w*\s*(?:extends[^{]*)?\{(.*?)\}', text, re.S):
            declared |= set(re.findall(r'^\s*(\w+)\s*\(', iface.group(1), re.M))
        for m in re.finditer(r'\b(?:qohos|qtInjector|injector|qohosNative)\s*\.\s*(\w+)\s*\(',
                             text):
            called.add(m.group(1))
    ghost_decl = declared - exports
    ghost_call = called - exports - {'toString'}
    report('napi_iface_matches_exports', not ghost_decl,
           f'declared-but-not-exported={sorted(ghost_decl)}' if ghost_decl
           else f'declared={sorted(declared)}')
    report('napi_calls_are_exported', not ghost_call,
           f'called-but-not-exported={sorted(ghost_call)}' if ghost_call
           else f'called={sorted(called)}')


def check_arkts_gate():
    """S2: banned patterns on bridge-critical ArkTS files."""
    bad = []
    for rel in KEY_ETS:
        p = os.path.join(ETS_DIR, *rel.split('/'))
        if not os.path.exists(p):
            bad.append(f'{rel}: missing')
            continue
        text = read(p)
        if re.search(r':\s*any\b', text):
            bad.append(f'{rel}: `: any`')
        if re.search(r'\brequire\s*\(', text):
            bad.append(f'{rel}: `require(`')
    report('arkts_no_banned_patterns', not bad, '; '.join(bad) if bad else
           f'{len(KEY_ETS)} key files clean')


def check_native_lib():
    """S3: deployable libentry.so present."""
    p = os.path.join(ROOT, 'entry', 'libs', 'arm64-v8a', 'libentry.so')
    ok = os.path.exists(p) and os.path.getsize(p) > 1024 * 1024
    report('libentry_present', ok,
           f'{os.path.getsize(p)//1024} KB' if os.path.exists(p) else 'missing')


def check_diag_hygiene():
    """S4: no diagnostic debris in the repo root (must be in diagnostics/)."""
    debris = []
    for pat in ('*.jpeg', '*.png', 'hilog_*.txt', 'crash*.txt', 'faultlist*.txt',
                'freeze*.txt', 'layout_*.json'):
        debris += [os.path.basename(p) for p in glob.glob(os.path.join(ROOT, pat))]
    report('root_diag_hygiene', not debris,
           f'debris={debris[:8]}{"..." if len(debris) > 8 else ""}' if debris
           else 'repo root clean')


def run_device_driver(script, target):
    rc = subprocess.call([sys.executable, os.path.join(TOOLS, script), target])
    report(f'device:{script}', rc == 0, f'exit={rc}')


def main():
    ap = argparse.ArgumentParser(description='SciDAVis-OHOS smoke verification gate')
    ap.add_argument('--device', metavar='IP:PORT',
                    help='also run on-device drivers via hdc against this target')
    args = ap.parse_args()

    check_napi_contract()
    check_arkts_gate()
    check_native_lib()
    check_diag_hygiene()

    if args.device:
        run_device_driver('verify_toolbar.py', args.device)
        run_device_driver('verify_i18n.py', args.device)
    else:
        print('(device drivers skipped — pass --device <ip:port> to include them)')

    fails = [r for r in results if not r[1]]
    print(f"\n=== verify_smoke: {len(results)} checks, {len(fails)} FAIL ===")
    for name, _, note in fails:
        print(f'  FAIL: {name}  {note}')
    sys.exit(1 if fails else 0)


main()
