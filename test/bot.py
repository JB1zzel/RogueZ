#!/usr/bin/env python3
"""Exploring bot for the Z88 Rogue layout prototype.

Runs src/rogue88 in pipe mode (ZPIPE=1), plays by walking to the nearest
unexplored edge, fighting what is next to it and taking stairs down, and
checks every map frame:
  * the hero is on the Z88 screen (rows 1-7) in the same column as on the map
  * the 7 rows shown are 7 consecutive rows of the level
  * when the hero is inside a room, every wall of that room is on screen

usage: bot.py SEED [KEYS] [--frames FILE]
"""
import collections
import os
import subprocess
import sys

PASS = set('.#+%*:])!?/=,^')
DIRS = {(0, -1): 'h', (0, 1): 'l', (-1, 0): 'k', (1, 0): 'j',
        (-1, -1): 'y', (-1, 1): 'u', (1, -1): 'b', (1, 1): 'n'}
ORTH = [(0, -1), (0, 1), (-1, 0), (1, 0)]


def read_frame(p):
    lines = []
    while True:
        line = p.stdout.readline()
        if not line:
            return None
        line = line.rstrip('\n')
        if line == '@@KEY':
            break
        lines.append(line)
    idx = [k for k, l in enumerate(lines) if l.startswith('@@SCREEN')]
    if not idx:
        return None
    i = idx[-1]
    logical = lines[i + 1:i + 25]
    z88 = [l[1:-1] for l in lines[i + 26:i + 34]]
    return logical, z88


def find_hero(logical):
    for y in range(1, 23):
        x = logical[y].find('@')
        if x >= 0:
            return y, x
    return None


def bfs(logical, start, goal_fn):
    q = collections.deque([start])
    prev = {start: None}
    while q:
        cur = q.popleft()
        if cur != start and goal_fn(cur):
            while prev[cur] != start:
                cur = prev[cur]
            return cur
        for dy, dx in ORTH:
            ny, nx = cur[0] + dy, cur[1] + dx
            if 1 <= ny <= 22 and 0 <= nx < 80 and (ny, nx) not in prev:
                ch = logical[ny][nx]
                if ch in PASS or ch.isalpha():
                    prev[(ny, nx)] = cur
                    q.append((ny, nx))
    return None


def room_box(logical, hy, hx):
    """Walls of the lit room the hero stands in, or None (passage/dark)."""
    row = logical[hy]
    if logical[hy][hx - 1:hx] == '#' or logical[hy][hx + 1:hx + 2] == '#':
        return None
    left = max(row.rfind('|', 0, hx), row.rfind('+', 0, hx))
    rs = [i for i in (row.find('|', hx), row.find('+', hx)) if i >= 0]
    right = min(rs) if rs else -1
    if left < 0 or right < 0 or '#' in row[left:right] or ' ' in row[left + 1:right]:
        return None
    # corners: walk up and down the left wall to its '-' corners
    top = hy
    while top > 0 and logical[top][left] in '|+':
        top -= 1
    bot = hy
    while bot < 23 and logical[bot][left] in '|+':
        bot += 1
    if logical[top][left] != '-' or logical[bot][left] != '-':
        return None
    return top, bot


def main():
    seed = sys.argv[1]
    nkeys = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 3000
    framef = None
    if '--frames' in sys.argv:
        framef = open(sys.argv[sys.argv.index('--frames') + 1], 'w')
    env = {'ZPIPE': '1', 'ZSEED': seed, 'PATH': '/usr/bin:/bin'}
    env.update({k: v for k, v in os.environ.items() if k.startswith('ZLIVE')})
    binary = os.environ.get('ZBIN', '../src/rogue88')
    env.update({k: v for k, v in os.environ.items() if k == 'ZTRACE'})
    p = subprocess.Popen([binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         text=True, env=env, cwd=os.path.dirname(os.path.abspath(__file__)))
    visited = set()
    level = None
    steps_on_level = 0
    errors = collections.Counter()
    stats = collections.Counter()
    last_top = None
    keys = 0
    while keys < nkeys:
        fr = read_frame(p)
        if fr is None:
            break
        logical, z88 = fr
        msgline = z88[0] + logical[0]
        if '--More--' in msgline or 'Press space' in ''.join(z88) or 'continue--' in ''.join(z88):
            key = ' '
        elif 'Press return' in ''.join(z88):
            key = '\n'
            stats['deaths'] += 1
        elif any(s in msgline for s in ('which direction', 'what do you want', 'really', 'call it')):
            key = '\x1b'
        else:
            hero = find_hero(logical)
            panel = z88[0][81:].strip()
            if hero and panel.startswith('Level'):
                # --- checks on the Z88 screen ---
                hy, hx = hero
                stats['map frames'] += 1
                shown = [r[:80] for r in z88[1:8]]
                tops = [t for t in range(1, 17) if logical[t:t + 7] == shown]
                if not tops:
                    errors['viewport is not 7 consecutive level rows'] += 1
                else:
                    top = tops[0]
                    if not top <= hy <= top + 6:
                        errors['hero off screen'] += 1
                    box = room_box(logical, hy, hx)
                    if box:
                        stats['in a room'] += 1
                        if not (top <= box[0] and box[1] <= top + 6):
                            errors['room not whole on screen'] += 1
                            if framef:
                                framef.write('ROOM CUT\n' + '\n'.join(z88) + '\n')
                    else:
                        stats['in a passage'] += 1
                    if framef and last_top is not None and top != last_top:
                        framef.write('top %d -> %d, hero row %d\n' % (last_top, top, hy)
                                     + '\n'.join(z88) + '\n\n')
                    last_top = top
                lvl = panel
                if lvl != level:
                    level, steps_on_level, visited = lvl, 0, set()
                    stats['levels'] += 1
                steps_on_level += 1
            # --- choose a move ---
            key = 's'
            if hero:
                hy, hx = hero
                visited.add(hero)
                for dy, dx in ORTH:
                    k = DIRS[(dy, dx)]
                    if logical[hy + dy][hx + dx].isalpha():
                        key = k     # fight
                        break
                else:
                    def frontier(c):
                        y, x = c
                        if c in visited or logical[y][x] not in '.#+':
                            return False
                        return any(logical[y + dy][x + dx] == ' ' for dy, dx in ORTH
                                   if 0 <= y + dy < 24 and 0 <= x + dx < 80)
                    nxt = None
                    if steps_on_level < 400:
                        nxt = bfs(logical, hero, frontier)
                    if nxt is None:
                        if logical[hy][hx] == '@' and steps_on_level > 30 and \
                                '%' not in ''.join(logical[1:23]):
                            key = '>'   # standing on the stairs (hidden by @)
                        nxt = bfs(logical, hero, lambda c: logical[c[0]][c[1]] == '%')
                    if nxt is not None:
                        key = DIRS[(nxt[0] - hy, nxt[1] - hx)]
                    elif steps_on_level > 30:
                        key = '>'
        if os.environ.get('BOTTRACE') and keys % 50 == 0:
            sys.stderr.write('%d %r %s\n' % (keys, key, logical[0][:60]))
            if keys % 500 == 0:
                sys.stderr.write('\n'.join(logical) + '\n')
        try:
            p.stdin.write(key)
            p.stdin.flush()
        except BrokenPipeError:
            break
        keys += 1
    try:                        # close input: the game exits normally
        p.stdin.close()
        p.wait(timeout=10)
    except Exception:
        p.kill()
    print('seed', seed, dict(stats), 'errors:', dict(errors) or 'none')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
