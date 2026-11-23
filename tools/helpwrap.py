"""helpwrap.py - OZ help pages from plain text (after the Z88 dev kit's
tools/helpwrap.py, with key icons and a narrower line).

Input: "@label" starts a page; paragraphs follow, separated by blank lines (a
line with a single "." gives an empty line).  {DIAMOND}, {SQUARE} and {SHIFT}
are OZ's key icons (SOH and a code; SHIFT is three columns wide).  The other
SD_ icons (ENTER, ESC, the arrows ...) did not show in help pages on OZ 4.7,
so the text names those keys.
Output: mpm DEFM lines for each page, wrapped to 61 characters (a 62-character
line loses its first letter under the help window's left edge), $7F between
lines, 0 at the end.  Fails if a page is longer than OZ shows (7 lines).
Usage: helpwrap.py pages.txt > help.inc
"""
import re
import sys
import textwrap

W, MAXLINES = 61, 7
ICONS = {'SQUARE': (0x2A, 1), 'DIAMOND': (0x2B, 1), 'SHIFT': (0x2D, 3)}
# while wrapping, each icon is as many private characters as it is wide; the
# first stands for the icon, the rest for nothing
PRIV = {name: chr(0xE000 + 4 * i) for i, name in enumerate(ICONS)}
CODE = {PRIV[n]: ICONS[n][0] for n in ICONS}
PAD = chr(0xE003)


def icons(text):
    def sub(m):
        if m.group(1) not in ICONS:
            sys.exit('unknown key icon {%s}' % m.group(1))
        return PRIV[m.group(1)] + PAD * (ICONS[m.group(1)][1] - 1)
    return re.sub(r'\{(\w+)\}', sub, text)


def defm(line, end):
    parts, run = [], ''
    for ch in line.replace('"', "'"):
        if ch == PAD:
            continue
        if ch in CODE:
            if run:
                parts.append('"%s"' % run)
                run = ''
            parts.append('$01, $%02X' % CODE[ch])
        else:
            run += ch
    if run:
        parts.append('"%s"' % run)
    return '        defm    ' + ', '.join(parts) + end


pages, cur = [], None
for raw in open(sys.argv[1]).read().splitlines() + ['']:
    line = raw.rstrip()
    if line.startswith('@'):
        cur = [line[1:].strip(), [], []]
        pages.append(cur)
        continue
    if cur is None:
        continue
    if line == '' or line == '.':
        if cur[2]:
            cur[1].append(' '.join(cur[2]))
            cur[2] = []
        if line == '.':
            cur[1].append('')
    else:
        cur[2].append(icons(line.strip()))
out = []
for label, paras, rest in pages:
    if rest:
        paras.append(' '.join(rest))
    lines = []
    for p in paras:
        lines += textwrap.wrap(p, W) if p else ['']
    if len(lines) > MAXLINES:
        sys.exit(f'{label}: {len(lines)} lines, OZ shows {MAXLINES}')
    out.append(label + ':')
    for i, l in enumerate(lines):
        last = i == len(lines) - 1
        if l:
            out.append(defm(l, ', 0' if last else ', $7F'))
        else:
            out.append('        defb    0' if last else '        defm    $7F')
    out.append('')
sys.stdout.write('\n'.join(out))
