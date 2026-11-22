#!/usr/bin/env python3
"""aggregate.py DIR OUT.json - turn the instrumented build's caller/callee
address counts (DIR/calls.txt) into function-name pairs for tools/banks.py."""
import collections, json, os, subprocess, sys
d, out = sys.argv[1], sys.argv[2]
a2f = {}
for line in subprocess.run(['nm', os.path.join(d, 'rogue88i')], capture_output=True, text=True).stdout.splitlines():
    p = line.split()
    if len(p) == 3 and p[1] in 'Tt':
        a2f[int(p[0], 16)] = p[2]
pairs = collections.Counter()
for line in open(os.path.join(d, 'calls.txt')):
    a, b, n = line.split()
    fa = 'START' if a == '(nil)' else a2f.get(int(a, 16), '?')
    pairs[(fa, a2f.get(int(b, 16), '?'))] += int(n)
json.dump({'pairs': [[a, b, n] for (a, b), n in pairs.items()]}, open(out, 'w'))
print('%d calls, %d caller/callee pairs -> %s' % (sum(pairs.values()), len(pairs), out))
