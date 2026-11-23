#!/usr/bin/env python3
"""mkcard.py BUILD KIT - make BUILD/rogue.epr, a 128K Z88 application card
(also the source of the RAM application files: tools/mkramapp.py).

  bank $38-$39  empty
  bank $3A-$3E  code banks 0-4 (BUILD/rogue_code_bankN.bin, at $8000); the
                last also has, at its top, the first values of the
                initialised data (packed), then the MENU and help (z88/mth.asm,
                help pages from z88/help.txt), untokenized: OZ before 4.3
                cannot use a token table
  bank $3F      application bank: rogue_CODE.bin from $C000, then the DOR
                (z88/dor.asm, assembled with the kit's mpm) from $FF80
Six banks (OZ 4.7's installer, Index, loads at most 7).  rogue_crt0.asm's
NBANKS is the number of code banks; mkcard patches the data's offset (rb_dat).
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
# MENU and help (z88/mth.asm, help pages from z88/help.txt) at $C000 in bank
# MENU and help (z88/mth.asm, help pages from z88/help.txt by
# tools/helpwrap.py: key icons, 61-character lines); dor.asm gets their
# addresses
hw = subprocess.run([sys.executable, '-I', os.path.join(here, 'helpwrap.py'),
                     os.path.join(here, '..', 'z88', 'help.txt')], check=True,
                    capture_output=True, text=True).stdout
open(os.path.join(build, 'help.inc'), 'w').write(hw)
def asm_mth(org):
    src = open(os.path.join(here, '..', 'z88', 'mth.asm')).read()
    assert src.count('org     $C000') == 1
    open(os.path.join(build, 'mth.asm'), 'w').write(src.replace('org     $C000', 'org     $%04X' % org))
    subprocess.run([os.path.abspath(mpm), '-I' + os.path.abspath(os.path.join(kit, 'def')), '-b', 'mth.asm'],
                   check=True, cwd=build)
    return open(os.path.join(build, 'mth.bin'), 'rb').read()
SIG = 0x3FF0
mth_off = (SIG - len(asm_mth(0xC000))) & ~0xF      # MENU/help: top of the last code bank
mth = asm_mth(0xC000 + mth_off)                      # (OZ reads it in segment 3)
cmds, hlp = (mth[i] | mth[i + 1] << 8 for i in (0, 2))
open(os.path.join(build, 'mth_addr.def'), 'w').write(
    'defc in_topics = $%04X\ndefc in_commands = $%04X\ndefc in_help = $%04X\n'
    % (0xC000 + mth_off + 4, cmds, hlp))
assert mth_off + len(mth) <= SIG
shutil.copy(dor_src, os.path.join(build, 'dor.asm'))
subprocess.run([os.path.abspath(mpm), '-I' + os.path.abspath(os.path.join(kit, 'def')), '-b', 'dor.asm'],
               check=True, cwd=build)
dor = open(os.path.join(build, 'dor.bin'), 'rb').read()
assert len(dor) == 0x80, 'DOR block must be $FF80-$FFFF, got %d bytes' % len(dor)
code = open(os.path.join(build, 'rogue_CODE.bin'), 'rb').read()
if len(code) > 0x3F80:
    sys.exit('resident code is %d bytes, %d too many for $C000-$FF7F' % (len(code), len(code) - 0x3F80))
app = code + b'\xff' * (0x3F80 - len(code)) + dor
# data image: the initialised data is the start of rogue_RAM.bin
mp = open(os.path.join(build, 'rogue.map')).read()
def sym(n):
    m = re.search(r'^%s\s*=\s*\$([0-9A-Fa-f]+)' % n, mp, re.M)
    return int(m.group(1), 16)
dsize = sym('__data_end') - sym('__data_start')
ram = open(os.path.join(build, 'rogue_RAM.bin'), 'rb').read()
bss_end = sym('__keep_end')     # the kept area (far calls, saves) is last
data = ram[:dsize]
def pack_data(d):                   # for rogue_crt0.asm (rb_dat): zero runs
    out = bytearray(); lit = bytearray(); i = 0
    def flush():
        while lit:
            out.append(min(len(lit), 127)); out.extend(lit[:127]); del lit[:127]
    while i < len(d):
        n = 0
        while i + n < len(d) and d[i + n] == 0 and n < 128:
            n += 1
        if n >= 3:
            flush(); out.append(0x7F + n); i += n
        else:
            lit.append(d[i]); i += 1
    flush(); out.append(0)
    return bytes(out)
data_raw = data
data = pack_data(data)
def unpack(p):
    o = bytearray(); i = 0
    while p[i]:
        c = p[i]; i += 1
        if c < 0x80: o += p[i:i + c]; i += c
        else: o += bytes(c - 0x7F)
    return bytes(o)
assert unpack(data) == data_raw
data_off = (mth_off - len(data)) & ~0xF            # the data just below the MENU
# the number of code banks: rogue_crt0.asm's NBANKS (bank NBANKS-1 has the
# data and the MENU); the banks below them are empty
NB = int(re.search(r'defc\s+NBANKS\s*=\s*(\d+)', open(os.path.join(here, '..', 'z88', 'rogue_crt0.asm')).read()).group(1))
assert NB == 5, 'dor.asm BANK_MTH ($3E) assumes 5 code banks'
banks = [b'\xff' * 0x4000] * (7 - NB)
nbank = 0
for i in range(NB):
    p = os.path.join(build, 'rogue_code_bank%d.bin' % i)
    b = open(p, 'rb').read() if os.path.exists(p) else b''
    if b:
        nbank += 1
    lim = data_off if i == NB - 1 else SIG
    assert len(b) <= lim, '%s: %d bytes, %d free' % (p, len(b), lim)
    b = b + b'\xff' * (lim - len(b))
    if i == NB - 1:
        lastcode = len(open(p, 'rb').read()) if os.path.exists(p) else 0
        b = b + data + b'\xff' * (mth_off - data_off - len(data)) + mth
        b = b + b'\xff' * (SIG - len(b))
    banks.append(b)
for i in range(NB, 6):
    p = os.path.join(build, 'rogue_code_bank%d.bin' % i)
    assert not os.path.exists(p) or os.path.getsize(p) == 0, '%s: code past NBANKS' % p
# Each code bank is signed at $3FF0 so that rogue_crt0.asm (rb_find) can find
# it wherever OZ puts it (a RAM application): "RG88", a build stamp, its
# number.  The stamp (a CRC of the card) is also patched into rb_sig in the
# application bank, and the data's address into rb_dat.
rd = sym('rb_dat') + 1 - 0xC000
assert app[rd:rd + 2] == b'\x00\x80'
app = app[:rd] + (0x8000 + data_off).to_bytes(2, 'little') + app[rd + 2:]
banks.append(app)
import zlib
stamp = zlib.crc32(b''.join(banks[7 - NB:7])).to_bytes(4, 'little')
for i in range(NB):
    k = 7 - NB + i
    assert len(banks[k]) == SIG
    banks[k] = banks[k] + b'RG88' + stamp + bytes([i]) + b'\xff' * 7
rs = sym('rb_sig') + 4 - 0xC000
assert app[rs:rs + 4] == b'\0\0\0\0'
banks[7] = app[:rs] + stamp + app[rs + 4:]
epr = b''.join(banks)
assert len(epr) == 0x20000
assert bss_end <= 0x8000, 'RAM: $%04X is past $7FFF' % bss_end
open(os.path.join(build, 'rogue.epr'), 'wb').write(epr)
print('rogue.epr: %d code banks; resident %d of %d bytes; initialised data %d (packed %d); '
      'bank %d: code to $%04X, data $%04X, MENU $%04X-$%04X; RAM used $2000-$%04X of $7FFF'
      % (nbank, len(code), 0x3F80, dsize, len(data), NB - 1, lastcode, data_off, mth_off, mth_off + len(mth),
         bss_end - 1))
