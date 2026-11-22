#!/usr/bin/env python3
"""libclosure.py LIBSRC SYMBOLS... - estimate the size of the z88dk library
code a program pulls in: find the source file defining each symbol (plain Z80,
classic library preferred), follow its EXTERNs, size every file with z80size.
Conditional assembly is not evaluated (IF/ELSE both counted), so it errs high.
"""
import os
import re
import subprocess
import sys

DIRECT = '--direct' in sys.argv
args = [a for a in sys.argv[1:] if a != '--direct']
lib = args[0]
want = args[1:]
SKIP = ('ez80', 'z180', 'r2ka', 'r2k', 'r4k', '8085', 'vm1', 'gbz80', '8080',
        'r800', 'am9511', 'kc160', 'z80n', 'newlib', 'target', '_DEVELOPMENT',
        'math48', 'mbf', 'zxn', 'test', 'z88dk_')
PREF = ('5-z80', '9-common', 'classic', 'z80_crt0s')

defs = {}
for root, _, files in os.walk(lib):
    if any(s in root for s in SKIP):
        continue
    for f in files:
        if not f.endswith('.asm'):
            continue
        p = os.path.join(root, f)
        try:
            txt = open(p, encoding='latin-1').read()
        except OSError:
            continue
        for m in re.finditer(r'^\s*(?:PUBLIC|XDEF|GLOBAL|XLIB)\s+([\w, \t]+)', txt, re.M):
            for s in re.split(r'[,\s]+', m.group(1).strip()):
                if s:
                    defs.setdefault(s, []).append(p)


def best(paths):
    def score(p):
        return (-sum(k in p for k in PREF), len(p))
    return sorted(paths, key=score)[0]


seen_files, missing, queue = {}, [], list(want)
done = set()
while queue:
    s = queue.pop()
    if s in done:
        continue
    done.add(s)
    cands = defs.get(s) or defs.get('_' + s) or defs.get(s.lstrip('_'))
    if not cands:
        missing.append(s)
        continue
    p = best(cands)
    if p in seen_files:
        continue
    txt = open(p, encoding='latin-1').read()
    seen_files[p] = s
    for m in re.finditer(r'^\s*(?:EXTERN|XREF|LIB)\s+([\w, \t]+)', txt, re.M):
        for e in re.split(r'[,\s]+', m.group(1).strip()):
            # --direct: only follow into the printf core (lower bound)
            if e and e not in done and (not DIRECT or 'printf' in s or 'printf' in e):
                queue.append(e)

out = subprocess.run([sys.executable, '-I', os.path.join(os.path.dirname(__file__), 'z80size.py'),
                      '--json'] + list(seen_files), capture_output=True, text=True)
import json
d = json.loads(out.stdout)
tot = 0
rows = []
for p, t in d['files']:
    n = t.get('code', 0) + t.get('rodata', 0) + t.get('data', 0)
    tot += n
    rows.append((n, os.path.relpath(p, lib)))
for n, p in sorted(rows, reverse=True)[:25]:
    print('%6d  %s' % (n, p))
print('files %d, total %d bytes; unsized lines %d' % (len(rows), tot, len(d['unknown'])))
print('not found:', ' '.join(sorted(set(missing))))
