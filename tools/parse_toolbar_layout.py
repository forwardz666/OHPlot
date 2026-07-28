"""Extract toolbar button click-centres from a uitest dumpLayout json.

Toolbar Image nodes live in the y-band around 72..120 px (32vp bar under
the 28vp menubar at DPR 2.2).  Prints index, centre-x, centre-y sorted
left-to-right so the regression driver can map them onto the 38-button
contract order in ToolBar.ets.
"""
import json
import sys

path = sys.argv[1] if len(sys.argv) > 1 else 'layout_tb2.json'
d = json.load(open(path, encoding='utf-8'))

imgs = []
stack = [d]
while stack:
    n = stack.pop()
    a = n.get('attributes', {})
    if a.get('type') == 'Image':
        b = a['bounds']  # "[x1,y1][x2,y2]"
        x1, y1, x2, y2 = [int(v) for v in b.replace('[', ' ').replace(']', ' ').replace(',', ' ').split()]
        if 60 <= y1 <= 130:  # toolbar band only
            imgs.append(((x1 + x2) // 2, (y1 + y2) // 2, x1, x2))
    stack.extend(n.get('children', []))

imgs.sort()
print(f'count={len(imgs)}')
for i, (cx, cy, x1, x2) in enumerate(imgs):
    print(f'{i:2d}  cx={cx:5d} cy={cy}  [{x1}..{x2}]')
