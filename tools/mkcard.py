#!/usr/bin/env python3
"""mkcard.py BUILD KIT - make BUILD/rogue.epr, a 128K Z88 application card.

  bank $38-$3C  code banks 0-4      (BUILD/rogue_code_bankN.bin, at $8000)
  bank $3D      (spare)
  bank $3E      first values of the initialised data (start of rogue_RAM.bin)
  bank $3F      application bank: rogue_CODE.bin from $C000, then the DOR
                (z88/dor.asm, assembled with the kit's mpm) from $FE00
NB code banks 0-5 are $38-$3D: rogue_crt0.asm's DATABANK (6) means $3E.
"""
import os
import re
import subprocess
import sys

build, kit = sys.argv[1], sys.argv[2]
mpm = os.path.join(kit, 'bin', 'mpm')
here = os.path.dirname(os.path.abspath(__file__))
dor_src = os.path.join(here, '..', 'z88', 'dor.asm')
import shutil
# MENU and help (z88/mth.asm, help pages from z88/help.txt) at $E000 in the
# data bank; dor.asm gets their addresses
hw = subprocess.run([sys.executable, '-I', os.path.join(kit, 'tools', 'helpwrap.py'),
                     os.path.join(here, '..', 'z88', 'help.txt')], check=True,
                    capture_output=True, text=True).stdout
open(os.path.join(build, 'help.inc'), 'w').write(hw)
shutil.copy(os.path.join(here, '..', 'z88', 'mth.asm'), os.path.join(build, 'mth.asm'))
subprocess.run([os.path.abspath(mpm), '-I' + os.path.abspath(os.path.join(kit, 'def')), '-b', 'mth.asm'],
               check=True, cwd=build)
mth = open(os.path.join(build, 'mth.bin'), 'rb').read()
cmds, hlp = mth[0] | mth[1] << 8, mth[2] | mth[3] << 8
open(os.path.join(build, 'mth_addr.def'), 'w').write(
    'defc in_topics = $E004\ndefc in_commands = $%04X\ndefc in_help = $%04X\n' % (cmds, hlp))
assert len(mth) <= 0x2000, 'MENU and help: %d bytes, 8K free' % len(mth)
shutil.copy(dor_src, os.path.join(build, 'dor.asm'))
subprocess.run([os.path.abspath(mpm), '-I' + os.path.abspath(os.path.join(kit, 'def')), '-b', 'dor.asm'],
               check=True, cwd=build)
dor = open(os.path.join(build, 'dor.bin'), 'rb').read()
assert len(dor) == 0x200, 'DOR block must be $FE00-$FFFF, got %d bytes' % len(dor)
code = open(os.path.join(build, 'rogue_CODE.bin'), 'rb').read()
if len(code) > 0x3E00:
    sys.exit('resident code is %d bytes, %d too many for $C000-$FDFF' % (len(code), len(code) - 0x3E00))
app = code + b'\xff' * (0x3E00 - len(code)) + dor
# data image: the initialised data is the start of rogue_RAM.bin
mp = open(os.path.join(build, 'rogue.map')).read()
def sym(n):
    m = re.search(r'^%s\s*=\s*\$([0-9A-Fa-f]+)' % n, mp, re.M)
    return int(m.group(1), 16)
dsize = sym('__data_end') - sym('__data_start')
ram = open(os.path.join(build, 'rogue_RAM.bin'), 'rb').read()
bss_end = sym('__keep_end')     # the kept area (far calls, saves) is last
data = ram[:dsize]
banks = []
nbank = 0
for i in range(6):
    p = os.path.join(build, 'rogue_code_bank%d.bin' % i)
    b = open(p, 'rb').read() if os.path.exists(p) else b''
    if b:
        nbank += 1
    assert len(b) <= 0x4000, p
    banks.append(b + b'\xff' * (0x4000 - len(b)))
assert len(data) <= 0x2000, 'initialised data %d bytes: it meets the MENU at $2000' % len(data)
banks.append(data + b'\xff' * (0x2000 - len(data)) + mth + b'\xff' * (0x2000 - len(mth)))
banks.append(app)
epr = b''.join(banks)
assert len(epr) == 0x20000
assert bss_end <= 0x8000, 'RAM: $%04X is past $7FFF' % bss_end
open(os.path.join(build, 'rogue.epr'), 'wb').write(epr)
print('rogue.epr: %d code banks; resident %d of %d bytes; initialised data %d; '
      'RAM used $2000-$%04X of $7FFF' % (nbank, len(code), 0x3E00, dsize, bss_end - 1))
