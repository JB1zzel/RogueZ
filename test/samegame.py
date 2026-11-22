#!/usr/bin/env python3
"""samegame.py OLD NEW SEED N - drive two builds with the bot's moves (taken
from OLD's screens) and check every screen of NEW is identical."""
import hashlib, os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib.util
spec = importlib.util.spec_from_file_location('bot', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'bot.py'))
bot = importlib.util.module_from_spec(spec); spec.loader.exec_module(bot)
old, new, seed, n = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
env = {'ZPIPE': '1', 'ZSEED': seed, 'PATH': '/usr/bin:/bin'}
pa = subprocess.Popen([old], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=env)
pb = subprocess.Popen([new], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=env)
import random
rng = random.Random(int(seed))
for i in range(n):
    fa, fb = bot.read_frame(pa), bot.read_frame(pb)
    if fa is None or fb is None:
        print('seed', seed, 'game ended at key', i, 'both' if fa == fb else 'ONE ONLY'); break
    if fa != fb:
        print('seed', seed, 'DIFFERENT at key', i); print('\n'.join(fa[1])); print('\n'.join(fb[1])); sys.exit(1)
    k = rng.choice('hjklyubnHJKLYUBN.s ,ie\x1b>')
    for p in (pa, pb):
        p.stdin.write(k); p.stdin.flush()
else:
    print('seed', seed, n, 'keys: every screen identical')
pa.kill(); pb.kill()
