#!/usr/bin/env python3
"""mkramapp.py EPR Z88CARD OUTDIR [NAME] - Rogue as a RAM application, with z88card.

Splits the 128K card (tools/mkcard.py) into its 7 used banks and has z88card
(V2.2 or later) build the same card with -ramapp, which also writes the
legacy RAM application (rogue.app + rogue.ap0-ap6, OZ 4.6 and later or the
Installer) and the OZ 5 one (rogue-oz5.app).  Each bank is loaded at the
address it runs at: code banks 0-5 and the data bank in segment 2 ($8000),
the application bank in segment 3 ($C000).  The card z88card writes must
equal ours.  Banks may land anywhere when installed: rogue_crt0.asm finds
them by their signatures (rb_find).  NAME (default rogue) names the files:
NAME.app, NAME.ap0 ...; bank $39, if used, is the card's untokenized help
(read by OZ in segment 3, so loaded at $C000).
"""
import os
import subprocess
import sys

epr_path, z88card, out = sys.argv[1], sys.argv[2], sys.argv[3]
name = sys.argv[4] if len(sys.argv) > 4 else 'rogue'
epr = open(epr_path, 'rb').read()
assert len(epr) == 0x20000
os.makedirs(out, exist_ok=True)
args = [os.path.abspath(z88card), '-ramapp', '-sz', '128', name + '.epr']
used = [i for i in range(8) if epr[i * 0x4000:(i + 1) * 0x4000] != b'\xff' * 0x4000]
# OZ 4's installer (Index) loads at most 7 banks (it accepts 8 in the header
# but its copy loop stops at 7, and the 8th is never loaded)
assert len(used) <= 7, 'the RAM application has %d banks; OZ 4 loads 7' % len(used)
for i in used:
    bn = 'bank%d.bin' % i
    open(os.path.join(out, bn), 'wb').write(epr[i * 0x4000:(i + 1) * 0x4000])
    args += [bn, '%02x%04x' % (0x38 + i, 0xC000 if i in (1, 7) else 0x8000)]
subprocess.run(args, cwd=out, check=True)
for i in used:
    os.remove(os.path.join(out, 'bank%d.bin' % i))
made = open(os.path.join(out, name + '.epr'), 'rb').read()
assert made == epr, "z88card's card differs from tools/mkcard.py's"
print('RAM application in', out, ':', ' '.join(sorted(f for f in os.listdir(out))))
