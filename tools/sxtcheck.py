#!/usr/bin/env python3
"""sxtcheck.py DIR - find a sccz80 code generation problem in DIR/*.asm.

A cast to char (Rogue's bool) used as a condition in && / || / ?: compiles to
    call l_sxt          ; int -> char
    jp   nc,...         ; branch on carry
but l_sxt does not set carry from the value (it leaves the sign bit), so the
condition is always false.  Found when monsters never woke on the Z88 (the
on() macro).  Exit 1 and list them if any are found."""
import glob, os, re, sys
bad = []
for f in sorted(glob.glob(os.path.join(sys.argv[1], '*.asm'))):
    lines = [l.split(';')[0].strip() for l in open(f, encoding='latin-1')]
    lines = [l for l in lines if l and not l.startswith('C_LINE')]
    fn = '?'
    for i, l in enumerate(lines):
        m = re.match(r'\._(\w+)', l)
        if m:
            fn = m.group(1)
        if re.match(r'call\s+l_sxt$', l) and i + 1 < len(lines) \
                and re.match(r'j[pr]\s+n?c,', lines[i + 1]):
            bad.append('%s: %s' % (os.path.basename(f), fn))
for b in bad:
    print('bool cast tested by carry:', b)
sys.exit(1 if bad else 0)
