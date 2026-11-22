#!/usr/bin/env python3
"""banks.py - split Rogue's modules into 16K code banks.

Inputs
  build-size/*.asm       sccz80 output (tools/z88dk-size.sh)
  calls.json             dynamic call counts, caller -> callee function, from
                         an instrumented Linux build (tools/calltrace)
Model (see BANKING.txt)
  S3  code banks: game code + the module's own strings (rodata)
  S2  one fixed card bank: resident code (RESIDENT below), the shared tables
      (rodata of extern.c and init.c) and the library
  S1 + app RAM: all variables
A call between two banked functions in different banks goes through a far
call stub; calls into resident code are plain calls.  The search minimises
the number of far calls in the recorded games, with every static call site
as a tie-breaker, subject to bank size.

usage: banks.py [--banks N] [--json OUT]
"""
import collections
import glob
import json
import os
import random
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import z80size  # noqa: E402

ASMDIR = os.environ.get('ROGUE_BUILD', os.path.join(HERE, '..', 'build-size'))
CALLS = os.path.join(HERE, 'calls.json')
BANK = 16384
RESERVE = 512           # per bank: bank header, local entry points, slack
RESIDENT_MODULES = {'io', 'zcurses', 'list', 'md', 'resident', 'zoz', 'zmach', 'zterm'}
GROUPS = [{'pack', 'things'},   # must share a bank: add_line keeps pack's strings
          {'misc', 'zlook'},    # look() (z88/zlook.asm) with trip_ch, erase_lamp
          {'save', 'zsave'}]    # saved games (z88/zsave.asm) with save.c
SHARED_RODATA = {'extern'}   # tables whose pointers are kept and used anywhere -> S2
LIB_ESTIMATE = 5000     # library in S2 (3.5K measured lower bound, 4-8K)


def scan(path):
    """Per function: code bytes, calls; per module: rodata bytes, data, bss."""
    mod = os.path.basename(path)[:-4]
    funcs = collections.OrderedDict()
    calls = collections.defaultdict(collections.Counter)
    addr_refs = collections.defaultdict(set)     # function -> code symbols loaded
    sect, cur = 'code_compiler', None
    totals = collections.Counter()
    labels_code = set()
    for raw in open(path, encoding='latin-1'):
        line = z80size._strip_comment(raw).rstrip()
        s = line.strip()
        if not s:
            continue
        if s.startswith('SECTION'):
            sect = s.split()[1]
            continue
        m = re.match(r'^\.(\w+)', line)
        if m:
            name = m.group(1)
            if sect.startswith('code') and name.startswith('_'):
                cur = name[1:]
                funcs.setdefault(cur, 0)
                labels_code.add(cur)
            s = re.sub(r'^\.\w+\s*', '', s)
            if not s:
                continue
        parts = s.split(None, 1)
        w = parts[0].lower()
        if w in ('module', 'include', 'global', 'extern', 'defc', 'c_line', 'if',
                 'endif', 'else', 'section'):
            continue
        ops = z80size.split_ops(parts[1] if len(parts) > 1 else '')
        n = z80size.data_size(w, ops)
        if n is None:
            try:
                n = z80size.insn_size(w, ops)
            except (ValueError, IndexError):
                n = 0
        kind = sect.split('_')[0]
        totals[kind] += n
        if kind == 'code' and cur:
            funcs[cur] += n
            if w in ('call', 'jp') and ops and re.fullmatch(r'_\w+', ops[-1]):
                calls[cur][ops[-1][1:]] += 1
            elif w == 'ld' and len(ops) == 2 and re.fullmatch(r'_\w+', ops[1]):
                addr_refs[cur].add(ops[1][1:])
    return mod, funcs, calls, addr_refs, totals


def main():
    nbanks = None
    if '--banks' in sys.argv:
        nbanks = int(sys.argv[sys.argv.index('--banks') + 1])
    f2m, fsize, static, addrs, mtot = {}, {}, collections.Counter(), {}, {}
    for p in sorted(glob.glob(os.path.join(ASMDIR, '*.asm'))):
        mod, funcs, calls, refs, tot = scan(p)
        mtot[mod] = tot
        for f, n in funcs.items():
            f2m[f] = mod
            fsize[f] = n
        for f, c in calls.items():
            for g, k in c.items():
                static[(f, g)] += k
        for f, r in refs.items():
            addrs[f] = r
    # functions moved to resident code (see BANKING.txt)
    resident_funcs = {f for f, m in f2m.items() if m in RESIDENT_MODULES}
    dyn = collections.Counter()
    if os.path.exists(CALLS):
        for a, b, n in json.load(open(CALLS))['pairs']:
            dyn[(a, b)] += n
    # unit of placement: module (minus resident functions)
    units = collections.Counter()
    for f, n in fsize.items():
        if f not in resident_funcs:
            units[f2m[f]] += n
    for m, t in mtot.items():
        if m in units and m not in SHARED_RODATA:
            units[m] += t['rodata']
    units = {m: n for m, n in units.items() if n > 0}
    group_of = {}
    for g in GROUPS:
        name = '+'.join(sorted(g))
        units[name] = sum(units.pop(m, 0) for m in g)
        for m in g:
            group_of[m] = name

    def unit_of(f):
        if f in resident_funcs or f not in f2m:
            return None
        return group_of.get(f2m[f], f2m[f])

    w = collections.Counter()
    for (a, b), n in dyn.items():
        ua, ub = unit_of(a), unit_of(b)
        if ua and ub and ua != ub:
            w[tuple(sorted((ua, ub)))] += n
    for (a, b), n in static.items():
        ua, ub = unit_of(a), unit_of(b)
        if ua and ub and ua != ub:
            w[tuple(sorted((ua, ub)))] += 0.01 * n     # tie-breaker
    cap = BANK - RESERVE
    total = sum(units.values())
    k = nbanks or -(-total // cap)

    def cost(assign):
        return sum(n for (a, b), n in w.items() if assign[a] != assign[b])

    def fill(assign):
        f = collections.Counter()
        for u, b in assign.items():
            f[b] += units[u]
        return f

    best = None
    rng = random.Random(1)
    for attempt in range(200):
        order = sorted(units, key=lambda u: -units[u] * (1 + rng.random() * 0.3))
        assign, used = {}, collections.Counter()
        for u in order:
            choices = [b for b in range(k) if used[b] + units[u] <= cap]
            if not choices:
                break
            aff = {b: sum(n for (x, y), n in w.items()
                          if (x == u and assign.get(y) == b) or (y == u and assign.get(x) == b))
                   for b in choices}
            b = max(choices, key=lambda b: (aff[b], -used[b], rng.random()))
            assign[u] = b
            used[b] += units[u]
        if len(assign) < len(units):
            continue
        improved = True
        while improved:
            improved = False
            c0 = cost(assign)
            for u in units:
                for b in range(k):
                    if b == assign[u]:
                        continue
                    f = fill(assign)
                    if f[b] + units[u] > cap:
                        continue
                    old = assign[u]
                    assign[u] = b
                    c1 = cost(assign)
                    if c1 < c0 - 1e-9:
                        c0, improved = c1, True
                    else:
                        assign[u] = old
            for u in units:
                for v in units:
                    if assign[u] >= assign[v]:
                        continue
                    f = fill(assign)
                    bu, bv = assign[u], assign[v]
                    if f[bu] - units[u] + units[v] > cap or f[bv] - units[v] + units[u] > cap:
                        continue
                    assign[u], assign[v] = bv, bu
                    c1 = cost(assign)
                    if c1 < c0 - 1e-9:
                        c0, improved = c1, True
                    else:
                        assign[u], assign[v] = bu, bv
        c = cost(assign)
        if best is None or c < best[0]:
            best = (c, dict(assign))
    if best is None:
        print('no fit with %d banks' % k)
        return 1
    c, assign = best
    # renumber banks by content
    f = fill(assign)
    # --- report ---
    keys = sum(1 for _ in ())  # placeholder
    print('Banked units (module code minus resident functions, plus its strings)')
    print('total %d bytes in %d banks of %d usable bytes' % (total, k, cap))
    for b in range(k):
        mods = sorted((u for u in assign if assign[u] == b), key=lambda u: -units[u])
        print('\n  bank %d: %5d bytes (%d free)' % (b, f[b], BANK - f[b]))
        print('    ' + ', '.join('%s %d' % (u, units[u]) for u in mods))
    far = collections.Counter()
    fardyn = 0
    for (a, b), n in dyn.items():
        ua, ub = unit_of(a), unit_of(b)
        if ua and ub and assign[ua] != assign[ub]:
            far[(a, b)] += n
            fardyn += n
    calls_total = sum(dyn.values())
    print('\nfar calls in the recorded games: %d of %d calls (%.2f%%)'
          % (fardyn, calls_total, 100.0 * fardyn / max(1, calls_total)))
    print('most frequent far calls:')
    for (a, b), n in far.most_common(15):
        print('  %8d  %s (%s, bank %d) -> %s (%s, bank %d)' % (
            n, a, f2m[a], assign[unit_of(a)], b, f2m[b], assign[unit_of(b)]))
    # far-call targets: every banked function called from another bank, or
    # whose address is taken (function pointers)
    targets = set()
    for (a, b), n in static.items():
        ub = unit_of(b)
        if ub is None:
            continue
        ua = unit_of(a)
        if ua is None or assign[ua] != assign[ub]:
            targets.add(b)
    fptr = set()
    for a, refs in addrs.items():
        for r in refs:
            if r in f2m and unit_of(r):
                fptr.add(r)
    print('\nfar-call stubs needed: %d functions called across banks or from '
          'resident code, %d used as function pointers (%d distinct)'
          % (len(targets), len(fptr), len(targets | fptr)))
    res_code = sum(fsize[f] for f in resident_funcs if f in fsize)
    res_ro = sum(mtot[m]['rodata'] for m in RESIDENT_MODULES | SHARED_RODATA if m in mtot)
    print('\nS2 (fixed card bank): resident code %d + tables %d + library ~%d = ~%d of %d'
          % (res_code, res_ro, LIB_ESTIMATE, res_code + res_ro + LIB_ESTIMATE, BANK))
    ram = sum(t['data'] + t['bss'] for t in mtot.values())
    print('RAM (data + bss, no heap/stack): %d' % ram)
    if '--json' in sys.argv:
        out = sys.argv[sys.argv.index('--json') + 1]
        for g, name in group_of.items():
            assign[g] = assign[name]
        json.dump({'assign': assign, 'targets': sorted(targets | fptr),
                   'fptr': sorted(fptr), 'resident': sorted(resident_funcs),
                   'f2m': f2m}, open(out, 'w'), indent=1)
    return 0


if __name__ == '__main__':
    sys.exit(main())
