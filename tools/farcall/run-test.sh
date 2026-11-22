#!/bin/sh
# run-test.sh - far-call test on the banked Z80 core.
#   cc -O2 -I<devkit>/emu -o zbank zbank.c <devkit>/emu/Z80.c
#   sh run-test.sh /path/to/mpm ./zbank
MPM=${1:-mpm}; ZBANK=${2:-./zbank}
$MPM -b -g test_fixed.asm && $MPM -b test_bank1.asm && $MPM -b test_bank2.asm || exit 1
$ZBANK -d 8000:200:result.bin test_fixed.bin@8000 test_bank1.bin@1:C000 test_bank2.bin@2:C000
python3 - <<'PY'
d = open('result.bin', 'rb').read()
m = {l.split()[0]: int(l.split('=')[1].split(',')[0].strip(), 16)
     for l in open('test_fixed.map') if '=' in l and l.split()[0] in
     ('R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7', 'FC_STACK')}
w = lambda a: d[a - 0x8000] | d[a - 0x8000 + 1] << 8
checks = [('add(30, 12)', w(m['R1']), 42),
          ('long result', w(m['R2'] + 2) << 16 | w(m['R2']), 0x12345678),
          ('through a function pointer', w(m['R3']), 123),
          ('own string, nested far call', w(m['R4']), 1039),
          ('recursion between banks', w(m['R5']), 210),
          ('bank restored', d[m['R6'] - 0x8000], 0),
          ('far-call stack restored', w(m['R7']), m['FC_STACK'])]
bad = 0
for name, got, want in checks:
    print('%-30s %s' % (name, 'ok' if got == want else 'FAILED (%r, expected %r)' % (got, want)))
    bad += got != want
raise SystemExit(bad)
PY
