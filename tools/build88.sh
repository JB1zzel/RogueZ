#!/bin/sh
# build88.sh - build Rogue as a Z88 application card (needs z88dk on the
# PATH, and z88card and mpm from the Z88 dev kit: Z88KIT=/path/to/z88-devkit)
#   1 compile every module to assembler (sccz80)
#   2 split into code banks, check strings, rewrite far calls (BANKING.txt)
#   3 link with z88/rogue_crt0.asm: application bank at $C000, code banks at
#     $8000, RAM at $2000
#   4 add the DOR and the MENU, build build-z88/rogue.epr (128K)
set -e
B=${ROGUE_B:-build-z88}
Z88KIT=${Z88KIT:-../z88-devkit}
mkdir -p $B/asm $B/banked
cp src/*.c src/*.h $B/asm/
rm -f $B/asm/zterm.c $B/asm/mach_dep.c
# modules compiled for size (ROGUE_SIZE: "all", or a list of modules; the
# rest for speed).  All, so that Rogue fits 5 code banks: it costs about 4%
# of the time Rogue spends in its own code (most of a move is in OZ)
SIZE=${ROGUE_SIZE:-all}
for f in $B/asm/*.c; do
  m=$(basename ${f%.c}); opt=--opt-code-speed
  case " $SIZE " in *" $m "*|*" all "*) opt=--opt-code-size;; esac
  (cd $B/asm && zcc +z88 -O3 $opt -DHAVE_CONFIG_H $ROGUE_CFLAGS -I. -a $m.c -o $m.asm) &
done
wait
cp z88/zlook.asm z88/zsave.asm z88/zfmt.asm $B/asm/   # by hand, banked like the C modules
export ROGUE_BUILD=$B/asm ROGUE_OUT=$B/banked
python3 tools/sxtcheck.py $B/asm
python3 tools/banks.py --json $B/asm/banks.json > $B/banks-report.txt
grep -A1 "^  bank" $B/banks-report.txt | grep -v "^--" | paste - - | sed 's/  */ /g'
python3 tools/strcheck.py
python3 tools/farify.py | tail -1
zcc +z88 -crt0=z88/rogue_crt0.asm -m -o $B/rogue \
    $B/banked/*.asm z88/farcall.asm z88/ozcalls.asm z88/hot.asm z88/pfmt.asm
python3 tools/mkcard.py $B "$Z88KIT"
