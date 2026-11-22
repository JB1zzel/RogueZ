#!/usr/bin/env python3
"""randplay.py BINARY SEED N - play N random keys (all of Rogue's commands)."""
import random, subprocess, sys, os
binary, seed, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
env = {'ZPIPE': '1', 'ZSEED': seed, 'PATH': '/usr/bin:/bin'}
env.update({k: v for k, v in os.environ.items() if k == 'ZTRACE'})
p = subprocess.Popen([binary], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, text=True, env=env)
rng = random.Random(int(seed))
keys = 'hjklyubnHJKLYUBN' * 4 + '.s ,ieqrwWTPRdcDIo)]=@>^/zt' + '\x1b\n abcdef'
try:
    for i in range(n):
        p.stdin.write(rng.choice(keys))
    p.stdin.close()
    p.wait(timeout=60)
except Exception as e:
    p.kill()
