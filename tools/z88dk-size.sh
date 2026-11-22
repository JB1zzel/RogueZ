#!/bin/sh
# z88dk-size.sh - Z80 size of Rogue, per module and section.
#
# Compiles each source to assembler with zcc +z88 (sccz80) and sizes it with
# tools/z80size.py (exact instruction lengths; checked against mpm, which
# gives identical totals on all 32 modules).  Library code is not included:
# the routines called are listed; tools/libclosure.py estimates them.
#
#   cd z88rogue && sh tools/z88dk-size.sh        -> build-size/report.txt
#   COMPILER=sdcc sh tools/z88dk-size.sh         (zsdcc, if you have it)

COMPILER=${COMPILER:-sccz80}
OUT=build-size
FILES="armor chase command daemon daemons extern fight init io list main misc
       monsters move new_level options pack passages potions rings rip rooms
       scrolls sticks things weapons wizard save vers zcurses zview md resident"
case "$COMPILER" in
  sdcc) CFLAGS="-compiler=sdcc -SO3 --max-allocs-per-node200000" ;;
  *)    CFLAGS="-O3" ;;
esac
command -v zcc >/dev/null || { echo "zcc not found: install z88dk"; exit 1; }
mkdir -p $OUT
cp src/*.c src/*.h $OUT/
asms=""
for f in $FILES; do
  if (cd $OUT && zcc +z88 $CFLAGS -DHAVE_CONFIG_H -I. -a $f.c -o $f.asm > $f.log 2>&1); then
    asms="$asms $OUT/$f.asm"
  else
    echo "$f FAILED: $(grep -m1 -i error $OUT/$f.log)"
  fi
done
python3 tools/z80size.py $asms | tee $OUT/report.txt
grep -il warning $OUT/*.log | sed 's/^/warnings in /'
