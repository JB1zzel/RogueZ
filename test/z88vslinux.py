#!/usr/bin/env python3
"""z88vslinux.py CARD.epr SEED KEYS... - play the same keys on a fixed-seed
Z88 test card (tools/build88.sh with ROGUE_CFLAGS=-DZ88_TEST_SEED=SEED) in the
dev kit harness and on the Linux build (ZSEED=SEED), and compare the screens
after every key.  Keys are harness tokens: H J K L ... SPACE RET ESC LSHIFT+K.
Needs Z88KIT (the dev kit, with h/h built).  The whole 94-column window is
compared, map and status panel: the harness must print 104 columns of the
screen (DUMPW=104; set ZHARNESS=./hprof for a harness with that patch, the
kit's own h prints 80, which hides the right of the map and the panel).
Walls and passages are compared exactly (DUMPLO=1 in the harness, ZBOX=1 in
the Linux build).
For a card built with -DZ88_TEST_FLAGS=n (player flags at the start: 4
blind, 0x800 hallucinating, 0x4000 sees monsters) set ZFLAGS=n too.
The harness has no keys for punctuation: LSHIFT+, presses only SHIFT."""
import os, re, subprocess, sys
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import importlib.util
spec = importlib.util.spec_from_file_location('bot', os.path.join(here, 'bot.py'))
bot = importlib.util.module_from_spec(spec); spec.loader.exec_module(bot)

card, seed, keys = sys.argv[1], sys.argv[2], sys.argv[3:]
kit = os.environ['Z88KIT']

lastseed = ['?']
_orig_read = bot.read_frame
def read_frame(p):
    lines = []
    while True:
        line = p.stdout.readline()
        if not line:
            return None
        if line.startswith('@@SEED'):
            lastseed[0] = line.split()[1]
        lines.append(line)
        if line.startswith('@@KEY'):
            break
    import io
    class F: pass
    f = F(); f.stdout = io.StringIO(''.join(lines))
    return _orig_read(f)
bot.read_frame = read_frame

def tochar(k):
    if k.startswith('LSHIFT+'): return {'.': '>', ',': '<'}.get(k[7:], k[7:].upper())
    if k.startswith('LCTRL+'): return chr(ord(k[6:].upper()) & 31)
    return {'SPACE': ' ', 'RET': '\n', 'ESC': '\x1b', 'UP': 'k', 'DOWN': 'j',
            'LEFT': 'h', 'RIGHT': 'l'}.get(k, k.lower())

# Z88: one harness run, a text dump after each key
mp = open(os.path.join(os.path.dirname(os.path.abspath(card)), 'rogue.map')).read()
seedaddr = re.search(r'^_seed\s*=\s*\$([0-9A-F]+)', mp, re.M).group(1)
args = [os.environ.get('ZHARNESS', './h'), '30000000', 'FIND:Rogue', 'RET', 'w40000000', 'd', 'lhex:' + seedaddr]
for k in keys:
    args += [k, os.environ.get('ZWAIT', 'w6000000'), 'd', 'lhex:' + seedaddr]
env = dict(os.environ, EPR=os.path.abspath(card), EPRLEN='131072', SLOT='2', OZVMCFG='1',
           NOSLOT3='1', HOLD='60000', DUMPW='104', DUMPLO='1')
out = subprocess.run(args, cwd=os.path.join(kit, 'h'), env=env, capture_output=True,
                     timeout=900).stdout.decode('latin-1').split('\n')
z88, z88seed = [], []
for i, l in enumerate(out):
    if l.startswith('lhex '):
        b = l[11:].split()[:4]
        z88seed.append(''.join(reversed(b)).lower())
    if l == '=== d ===':
        rows = [re.sub('\x01(.)', lambda m: chr(0xC0 + (ord(m.group(1)) & 31)), x)
                for x in out[i + 1:i + 9]]     # box characters (DUMPLO)
        z88.append([re.sub(r'(\s\|[RG]\d+)+$', '', x)[10:104].rstrip() for x in rows])
# Linux: frames before each key = screen after the previous one
lin, linseed = [], []
p = subprocess.Popen([os.path.join(here, '..', 'src', 'rogue88')], stdin=subprocess.PIPE,
                     stdout=subprocess.PIPE, text=True,
                     env={'ZPIPE': '1', 'ZBOX': '1', 'ZSEED': seed, 'ZFLAGS': os.environ.get('ZFLAGS', '0'), 'PATH': '/usr/bin:/bin',
                          'LANG': 'C.UTF-8'}, encoding='utf-8')
for k in [None] + keys:
    if k is not None:
        p.stdin.write(tochar(k)); p.stdin.flush()
    fr = bot.read_frame(p)
    if fr is None:
        break
    lin.append([r[:94].rstrip() for r in fr[1]])
    linseed.append(lastseed[0])
p.kill()
n = min(len(z88), len(lin))
for i in range(n):
    if i < len(z88seed) and z88seed[i] != linseed[i]:
        print('seed differs after key %d (%s): Z88 %s Linux %s (screens %s)' % (
            i, keys[i - 1] if i else 'start', z88seed[i], linseed[i],
            'same' if z88[i] == lin[i] else 'differ'))
    if z88[i] != lin[i]:
        print('first difference after key %d (%s):' % (i, keys[i - 1] if i else 'start'))
        for a, b in zip(z88[i], lin[i]):
            mark = '  ' if a == b else '>>'
            print('%s Z88   |%s' % (mark, a))
            if a != b:
                print('%s Linux |%s' % (mark, b))
        sys.exit(1)
print('%d screens identical (Z88 %d, Linux %d)' % (n, len(z88), len(lin)))
