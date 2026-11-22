#!/bin/sh
# run.sh - record which functions call which, for tools/banks.py.
# Builds Rogue with gcc -finstrument-functions, plays 6 bot games of 3000
# keys and 8 random-key games of 5000 keys, writes tools/calls.json.
#   cd z88rogue && sh tools/calltrace/run.sh
set -e
D=build-trace
mkdir -p $D
cp src/*.c src/*.h tools/calltrace/trace.c $D/
rm -f $D/calls.txt
(cd $D && gcc -O0 -g -w -no-pie -DHAVE_CONFIG_H -I. -finstrument-functions -c \
   $(ls *.c | grep -v "trace.c\|zoz.c\|zmach.c") && gcc -O0 -c trace.c && gcc -no-pie -o rogue88i *.o)
for s in 2 4 7 8 11 5; do
  ZBIN=$PWD/$D/rogue88i ZTRACE=$PWD/$D/calls.txt python3 -I test/bot.py $s 3000
done
for s in 1 2 3 4 5 6 7 8; do
  ZTRACE=$PWD/$D/calls.txt python3 -I test/randplay.py $D/rogue88i $s 5000
done
python3 -I tools/calltrace/aggregate.py $D tools/calls.json
