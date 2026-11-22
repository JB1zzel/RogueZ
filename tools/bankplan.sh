#!/bin/sh
# bankplan.sh - the bank plan from source, in one go (see BANKING.txt):
#   1 compile every module to Z80 assembler and size it   (tools/z88dk-size.sh)
#   2 split the modules into code banks                     (tools/banks.py,
#     using the call counts in tools/calls.json; re-record them with
#     tools/calltrace/run.sh after big changes)
#   3 check no string literal is read from the wrong bank   (tools/strcheck.py)
#   4 rewrite cross-bank calls to stubs, make the stubs     (tools/farify.py)
# Needs z88dk (zcc) on the PATH.
set -e
sh tools/z88dk-size.sh > build-size/sizes.txt
grep TOTAL build-size/sizes.txt
python3 tools/banks.py --json build-size/banks.json | tee build-size/banks-report.txt
python3 tools/strcheck.py
python3 tools/farify.py
