# Convert SciDAVis original XPM toolbar icons to PNG (original size, transparent-aware).
# Also copies the edit-*.svg (light/24) icons. Output -> entry/src/main/resources/base/media/tb_<name>.png|svg
#
# Usage:
#   python tools/convert_xpm.py
#
# Pure-Python XPM text parser (multi-char color codes, "c None" transparency,
# a small named-color table for the few X11 names SciDAVis uses). Pillow only
# writes the PNG; it never parses the XPM.
import os
import re
from PIL import Image

SRC_ICONS = r"c:\Users\Forwardz\Desktop\scidavis\scidavis\icons"
DST_MEDIA = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "entry", "src", "main", "resources", "base", "media",
)
DST_MEDIA = os.path.normpath(DST_MEDIA)

# Toolbar icons actually placed (root-level .xpm). Names without extension.
XPM_ICONS = [
    # File toolbar
    "new", "new_aspect", "fileopen", "open_template", "import",
    "filesave", "save_template", "fileprint", "pdf", "folder", "log",
    # Edit toolbar (erase = Clear Selection); undo/redo/cut/copy/paste use svg
    "erase",
    # Graph toolbar
    "pointer", "arrangeLayers", "curves", "text", "zoom", "zoomOut",
    "unzoom", "cursor_16", "select", "cursors",
    # Plot toolbar
    "lpPlot", "vertBars", "area", "pie", "histogram", "boxPlot",
    "vectXYXY", "ribbon", "bars", "scatter", "trajectory",
    # New Aspect / Plot submenu icons that have an image
    "table", "new_matrix", "new_note", "new_graph",
    "lPlot", "pPlot",
]

# edit-*.svg from light/24 -> tb_edit_*.svg
SVG_ICONS = {
    "light/24/edit-undo.svg": "tb_edit_undo.svg",
    "light/24/edit-redo.svg": "tb_edit_redo.svg",
    "light/24/edit-cut.svg": "tb_edit_cut.svg",
    "light/24/edit-copy.svg": "tb_edit_copy.svg",
    "light/24/edit-paste.svg": "tb_edit_paste.svg",
}

# Minimal X11 named-color table (only names seen in SciDAVis xpm files).
NAMED = {
    "none": None,
    "black": (0, 0, 0),
    "white": (255, 255, 255),
    "red": (255, 0, 0),
    "green": (0, 128, 0),
    "blue": (0, 0, 255),
    "yellow": (255, 255, 0),
    "cyan": (0, 255, 255),
    "magenta": (255, 0, 255),
    "gray": (190, 190, 190),
    "grey": (190, 190, 190),
    "darkgray": (169, 169, 169),
    "lightgray": (211, 211, 211),
    "orange": (255, 165, 0),
    "brown": (165, 42, 42),
    "pink": (255, 192, 203),
}


def parse_color(token):
    """token is the color spec after 'c', e.g. '#FF00AA', 'None', 'black'."""
    t = token.strip()
    if t.startswith("#"):
        hexv = t[1:]
        if len(hexv) == 12:  # #RRRRGGGGBBBB
            r = int(hexv[0:2], 16)
            g = int(hexv[4:6], 16)
            b = int(hexv[8:10], 16)
            return (r, g, b)
        if len(hexv) == 6:
            return (int(hexv[0:2], 16), int(hexv[2:4], 16), int(hexv[4:6], 16))
        if len(hexv) == 3:
            return (int(hexv[0] * 2, 16), int(hexv[1] * 2, 16), int(hexv[2] * 2, 16))
    return NAMED.get(t.lower(), (0, 0, 0))


def extract_strings(text):
    """Return list of the quoted string literals inside the xpm C array."""
    # Grab everything between the first '{' and last '}' then pull "..." tokens.
    body = text[text.index("{") + 1: text.rindex("}")]
    return re.findall(r'"((?:[^"\\]|\\.)*)"', body)


def color_key(spec_tokens):
    """spec_tokens: tokens after the pixel chars. Find the value following 'c'."""
    # Format: <key> <val> [<key> <val> ...]; keys in {c,g,g4,m,s}. We want 'c'.
    i = 0
    val = None
    while i < len(spec_tokens) - 1:
        key = spec_tokens[i]
        if key in ("c", "m", "g", "g4", "s"):
            # value may itself be multi-word for symbolic 's' but 'c' color is single token
            v = spec_tokens[i + 1]
            if key == "c":
                val = v
            i += 2
        else:
            i += 1
    return val


def convert_xpm(path, out_png):
    with open(path, "r", encoding="latin-1") as f:
        text = f.read()
    strings = extract_strings(text)
    if not strings:
        raise ValueError("no strings in " + path)
    header = strings[0].split()
    w, h, ncolors, cpp = (int(header[0]), int(header[1]), int(header[2]), int(header[3]))
    palette = {}
    for i in range(1, 1 + ncolors):
        line = strings[i]
        code = line[:cpp]
        rest = line[cpp:].split()
        cval = color_key(rest)
        palette[code] = parse_color(cval if cval is not None else "None")
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    pixel_lines = strings[1 + ncolors: 1 + ncolors + h]
    for y, row in enumerate(pixel_lines):
        for x in range(w):
            code = row[x * cpp:(x + 1) * cpp]
            col = palette.get(code, None)
            if col is None:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (col[0], col[1], col[2], 255)
    img.save(out_png, "PNG")
    return (w, h)


def main():
    os.makedirs(DST_MEDIA, exist_ok=True)
    done, missing = [], []
    for name in XPM_ICONS:
        src = os.path.join(SRC_ICONS, name + ".xpm")
        if not os.path.exists(src):
            missing.append(name + ".xpm")
            continue
        out = os.path.join(DST_MEDIA, "tb_" + name.lower() + ".png")
        sz = convert_xpm(src, out)
        done.append("%s -> tb_%s.png %s" % (name, name.lower(), sz))
    for rel, dst_name in SVG_ICONS.items():
        src = os.path.join(SRC_ICONS, *rel.split("/"))
        if not os.path.exists(src):
            missing.append(rel)
            continue
        # ArkUI's SVG renderer has no CSS-class / currentColor support:
        # inline the breeze ColorScheme-Text color (#4d4d4d) directly.
        with open(src, "r", encoding="utf-8") as f:
            svg = f.read()
        svg = svg.replace("fill:currentColor", "fill:#4d4d4d")
        svg = svg.replace('fill="currentColor"', 'fill="#4d4d4d"')
        with open(os.path.join(DST_MEDIA, dst_name), "w", encoding="utf-8", newline="\n") as f:
            f.write(svg)
        done.append("%s -> %s (color inlined)" % (rel, dst_name))
    print("Converted %d icons to %s" % (len(done), DST_MEDIA))
    for d in done:
        print("  " + d)
    if missing:
        print("MISSING (%d):" % len(missing))
        for m in missing:
            print("  " + m)


if __name__ == "__main__":
    main()
