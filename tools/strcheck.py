#!/usr/bin/env python3
"""strcheck.py - find string literals that would be read from the wrong bank.

A banked module's string literals live in its own code bank (BANKING.txt).
That is only safe while that bank is mapped, i.e. while the module's own
code, or resident code it called, is running.  Using build-size/*.asm and the
bank assignment (build-size/banks.json), this lists, statement by statement
(sccz80 C_LINE groups):
  A  a literal passed to a function in a different code bank
  B  a function that returns one of its literals, called from another bank
  C  a literal's address stored to memory (a global, or through a pointer):
     it may be read later from another bank
Resident callees (msg, sprintf, waddstr ...) are fine: the caller's bank is
still mapped while they run - unless they keep the pointer (KEEPERS).

usage: strcheck.py   (exit 1 if anything is found)
"""
import collections
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ASMDIR = os.environ.get('ROGUE_BUILD', os.path.join(HERE, '..', 'build-size'))
# add_line() keeps its format pointer, so its callers (pack.c, things.c) must
# share its bank: tools/banks.py GROUPS.  An ordinary cross-bank check covers it.
# Reviewed by hand and safe; each with the reason.  Kind, function, callee.
ALLOW = {
    # a literal still on the stack for an outer call, e.g. msg(fmt, inv_name(o)):
    # the callee never sees it
    ('A', '*', 'inv_name'): 'outer call argument (msg format), not passed',
    ('A', '*', 'num'): 'outer call argument, not passed',
    ('A', '*', 'zunctrl'): 'unctrl(ch) takes a char; the literal is the outer msg format',
    ('A', '*', 'death'): 'outer call argument (msg before death), not passed',
    ('A', 'main', '*'): 'main(): literals of earlier calls left on the stack',
    ('A', 'fire_bolt', '*'): "fire_bolt's own name argument and literals, not passed",
    ('A', 'do_zap', 'save_throw'): 'outer call argument, not passed',
    ('A', 'total_winner', '*'): 'outer call argument, not passed',
    # pointer handed back, never read by the callee (caller's bank is mapped
    # again when the pointer is used)
    ('B', 'call_it', ''): 'returns nothing: a ternary format in HL before a jump',
    ('B', 'num', ''): 'returns numbuf (RAM)',
    ('B', 'inventory', ''): 'returns a flag (jump heuristic)',
    ('B', 'picky_inven', ''): 'returns nothing (jump heuristic)',
    ('B', 'score', ''): 'returns nothing (jump heuristic)',
    ('B', 'do_zap', ''): 'returns nothing (jump heuristic)',
    ('B', 'new_thing', ''): 'returns a THING * (jump heuristic)',
    ('B', 'z_option', ''): 'returns nothing: an on/off literal in HL for msg',
    ('B', 'z_try_restore', ''): 'returns nothing: a ternary message in HL before mvaddstr',
    ('C', 'get_dir', ''): 'static prompt pointer, only read inside get_dir',
    ('C', 'killname', ''): 'local variable sp, used inside killname',
}


def allowed(kind, fn, what):
    callee = ''
    m = re.search(r'to (\w+)', what)
    if m and kind == 'A':
        callee = m.group(1)
    for (k, f, c), _ in ALLOW.items():
        if k == kind and f in (fn, '*') and c in (callee, '*'):
            return True
    return False


def functions(path):
    """Yield (function, [instruction lines]) for the code section."""
    cur_fn, body, sect = None, [], 'code'
    for raw in open(path, encoding='latin-1'):
        s = raw.split(';')[0].rstrip()
        st = s.strip()
        if st.startswith('SECTION'):
            sect = st.split()[1]
            continue
        if not sect.startswith('code') or not st or st.startswith(('C_LINE', 'GLOBAL', 'MODULE', 'INCLUDE')):
            continue
        m = re.match(r'^\._(\w+)', s)
        if m:
            if cur_fn:
                yield cur_fn, body
            cur_fn, body = m.group(1), []
            continue
        body.append(st)
    if cur_fn:
        yield cur_fn, body


LIT = re.compile(r'^i_\d+(\+\d+)?$')


def simulate(body):
    """Follow literal addresses through HL/DE/BC and the stack.
    Returns (calls made while a literal is in HL or on the stack,
             whether HL can hold a literal at a return, literal stores)."""
    reg = {'hl': False, 'de': False, 'bc': False}
    stack = []
    lit_calls, ret_lit, stores = [], False, 0
    for st in body:
        if st.startswith('.'):              # label: register contents unknown
            reg = dict.fromkeys(reg, False)
            st = re.sub(r'^\.\w+\s*', '', st)
            if not st:
                continue
        parts = st.split(None, 1)
        op = parts[0].lower()
        args = [x.strip() for x in parts[1].split(',')] if len(parts) > 1 else []
        if op == 'ld' and len(args) == 2:
            d, src = args[0].lower(), args[1]
            if d in reg:
                reg[d] = bool(LIT.match(src))
            elif d in ('h', 'l'):
                reg['hl'] = False
            elif d in ('d', 'e'):
                reg['de'] = False
            elif d in ('b', 'c'):
                reg['bc'] = False
            elif d.startswith('(_') and src.lower() == 'hl' and reg['hl']:
                stores += 1
            elif d == 'sp':
                stack = []
        elif op == 'push' and args and args[0].lower() in reg:
            stack.append(reg[args[0].lower()])
        elif op == 'push':
            stack.append(False)
        elif op == 'pop' and args:
            v = stack.pop() if stack else False
            if args[0].lower() in reg:
                reg[args[0].lower()] = v
        elif op == 'ex' and args and args[0].lower() == 'de':
            reg['hl'], reg['de'] = reg['de'], reg['hl']
        elif op in ('call', 'jp') and args and re.match(r'_\w+$', args[-1]):
            callee = args[-1][1:]
            if reg['hl'] or reg['de'] or any(stack):
                lit_calls.append(callee)
            if callee.endswith('_callee'):
                stack = [False] * len(stack)    # callee removed its arguments
            if op == 'call':
                reg = dict.fromkeys(reg, False)
            else:
                if any(reg.values()):
                    ret_lit = True          # tail call / return path
        elif op == 'call' and args:
            name = args[-1]
            if name.endswith('_callee'):
                stack = [False] * len(stack)    # callee removed its arguments
            if name.startswith('l_pint') and reg['hl']:
                stores += 1
            if name.startswith('l_pint_pop') and stack:
                stack.pop()
            reg = dict.fromkeys(reg, False) if not name.startswith('l_g') else reg
            if name.startswith('l_g'):
                reg['hl'] = False
        elif op == 'ret' and not args:
            if reg['hl']:
                ret_lit = True
        elif op == 'jp' and args and args[-1].startswith('i_'):
            if reg['hl'] and len(args) == 1:
                ret_lit = True              # often a jump to the epilogue
        elif op in ('add', 'adc', 'sbc', 'inc', 'dec') and args:
            if args[0].lower() == 'hl' and len(args) == 2 and args[1].lower() == 'sp':
                reg['hl'] = False
            elif args[0].lower() in reg and op in ('inc', 'dec'):
                pass                        # literal+1 is still a literal
            elif args[0].lower() == 'hl':
                pass
        elif op == 'ld' and args and args[0].lower() == 'sp':
            stack = []
    return lit_calls, ret_lit, stores


def main():
    b = json.load(open(os.path.join(ASMDIR, 'banks.json')))
    assign, f2m = b['assign'], b['f2m']
    resident = set(b['resident'])

    def bank_of(fn):
        if fn in resident or fn not in f2m:
            return None             # resident code or library
        return assign.get(f2m[fn])

    returns_literal = collections.defaultdict(list)
    found = []
    callers = collections.defaultdict(set)
    for path in sorted(glob.glob(os.path.join(ASMDIR, '*.asm'))):
        mod = os.path.basename(path)[:-4]
        for fn, body in functions(path):
            for st in body:
                m = re.match(r'(call|jp)\s+(?:\w+,\s*)?_(\w+)$', st)
                if m:
                    callers[m.group(2)].add(fn)
            if mod not in assign:
                continue            # resident code: no literals of its own banked
            mybank = assign[mod]
            lit_calls, ret_lit, stores = simulate(body)
            for c in sorted(set(lit_calls)):
                cb = bank_of(c)
                if cb is not None and cb != mybank:
                    found.append(('A', mod, fn, '', 'passes a literal to %s (bank %s)' % (c, cb)))
            if ret_lit:
                returns_literal[fn].append('')
            if stores:
                found.append(('C', mod, fn, '', 'stores a literal address (%d)' % stores))
    for fn, where in returns_literal.items():
        fb = bank_of(fn)
        other = sorted({c for c in callers[fn] if bank_of(c) != fb})
        if other:
            found.append(('B', f2m.get(fn, '?'), fn, where[0],
                          'returns a literal; called from other banks by ' + ', '.join(other)))
    found = [f for f in found if not allowed(f[0], f[2], f[4])]
    for kind in 'ABC':
        rows = [f for f in found if f[0] == kind]
        print('%s: %d' % (kind, len(rows)))
        for _, mod, fn, cline, what in rows:
            print('   %-9s %-14s %s' % (mod, fn, what))
    return 1 if found else 0


if __name__ == '__main__':
    sys.exit(main())
