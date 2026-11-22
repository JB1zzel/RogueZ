#!/usr/bin/env python3
"""sccz80_to_mpm.py IN.asm OUT.asm - make sccz80 output assemble with mpm,
only to check sizes: drop C_LINE/INCLUDE/SECTION, declare undefined symbols
XREF, resolve "defc a = b" label aliases (mpm wants them defined first),
and put the bss (defs) at the end in a stable order."""
import re
import sys

src = open(sys.argv[1], encoding='latin-1').read().split('\n')
lines, defined, used, alias = [], set(), set(), {}
for l in src:
    s = l.strip()
    if re.match(r'(C_LINE|INCLUDE|SECTION)\b', s):
        continue
    m = re.match(r'defc\s+(\w+)\s*=\s*(\w+)\s*$', s)
    if m and not m.group(2).isdigit():
        alias[m.group(1)] = m.group(2)
        continue
    m = re.match(r'defc\s+(\w+)\s*=', s)
    if m:
        defined.add(m.group(1))
    m = re.match(r'^\.(\w+)', l)
    if m:
        defined.add(m.group(1))
    lines.append(l)


def res(x):
    seen = set()
    while x in alias and x not in seen:
        seen.add(x)
        x = alias[x]
    return x


out = []
for i, l in enumerate(lines):
    lines[i] = l.replace('ASMPC', '$')
for l in lines:
    if alias:
        l = re.sub(r'\b(\w+)\b', lambda m: res(m.group(1)) if m.group(1) in alias else m.group(1), l)
    out.append(l)
for l in out:
    s = l.split(';', 1)[0]
    if s.strip().startswith(('GLOBAL', 'MODULE', 'EXTERN')):
        continue
    for w in re.findall(r'\b[A-Za-z_]\w*\b', s.split('"')[0] if '"' in s else s):
        used.add(w)
mn = set('''ld call jp jr push pop add adc sub sbc and or xor cp inc dec ex exx ret
defb defw defm defs defc ccf scf rla rra rlca rrca bit set res sra sla srl rl rr rlc
rrc ldi ldir lddr ldd djnz cpl neg nz z nc c po pe p m a b d e h l hl de bc sp af ix iy
ixh ixl iyh iyl halt nop di ei rst im in out const MODULE GLOBAL i r'''.split())
ext = sorted(w for w in used if w not in defined and w.lower() not in mn)
hdr = ['\tdefc\t' + w + ' = 0' for w in ext]
mod = [l for l in out if l.strip().startswith('MODULE')]
body = [l for l in out if not l.strip().startswith(('MODULE', 'GLOBAL', 'EXTERN'))]
open(sys.argv[2], 'w').write('\n'.join(mod + hdr + body) + '\n')
