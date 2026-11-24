#!/usr/bin/env python3
"""farify.py - apply the bank plan to sccz80 output.

Reads build-size/*.asm and build-size/banks.json (tools/banks.py), writes
build-banked/:
  MODULE.asm     the module with
                   - calls to a banked function in another bank, and every
                     call from resident code into banked code, renamed
                     _foo -> far_foo
                   - every use of a banked function's address (function
                     pointers: ld hl,_foo / defw _foo) renamed to far_foo, so
                     pointer calls and comparisons all go through one stub
                   - code and rodata sections renamed per bank:
                     code_bankN / rodata_bankN, or code_resident /
                     rodata_resident; data and bss stay (RAM)
  farstubs.asm   one stub per far target:  far_foo: ld a,N / ld de,_foo / jp farcall
  banks.txt      what went where
and checks the result: no direct call or address use crosses a bank.

usage: farify.py
"""
import collections
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.environ.get('ROGUE_BUILD', os.path.join(HERE, '..', 'build-size'))
OUT = os.environ.get('ROGUE_OUT', os.path.join(HERE, '..', 'build-banked'))


def main():
    b = json.load(open(os.path.join(SRC, 'banks.json')))
    assign, f2m = b['assign'], b['f2m']
    resident = set(b['resident'])
    banked = {f for f, m in f2m.items() if f not in resident and m in assign}

    def bank_of_func(f):
        return assign[f2m[f]] if f in banked else None

    os.makedirs(OUT, exist_ok=True)
    targets = set()
    stats = collections.Counter()
    problems = []
    for path in sorted(glob.glob(os.path.join(SRC, '*.asm'))):
        mod = os.path.basename(path)[:-4]
        mybank = assign.get(mod)                 # None: resident module
        tag = 'bank%d' % mybank if mybank is not None else 'resident'
        out = []
        cur_fn = None
        sect = 'code_compiler'
        for line in open(path, encoding='latin-1'):
            code, sep, comment = line.partition(';') if '"' not in line else (line, '', '')
            m = re.match(r'^\._(\w+)', code)
            if m and sect.startswith('code'):
                cur_fn = m.group(1)
            st = code.strip()
            if st.startswith('SECTION'):
                sect = st.split()[1]
                kind = sect.split('_')[0]
                if kind in ('code', 'rodata'):
                    # resident functions in a banked module would need their
                    # own module; resident.c holds them, so none are left here
                    line = line.replace(sect, '%s_%s' % (kind, tag))
                out.append(line)
                continue
            # function calls
            mc = re.match(r'(\s*(?:\.\w+\s+)?call\s+(?:\w+,\s*)?)_(\w+)(\s*)$', code)
            if mc and mc.group(2) in banked:
                f = mc.group(2)
                if mybank is None or bank_of_func(f) != mybank:
                    code = '%sfar_%s%s' % (mc.group(1), f, mc.group(3))
                    targets.add(f)
                    stats['far calls (static)'] += 1
                else:
                    stats['direct calls within a bank'] += 1
                out.append(code + sep + comment if sep else code)
                continue
            # addresses of banked functions (function pointers), anywhere
            def addr(mo):
                f = mo.group(1)
                if f in banked:
                    targets.add(f)
                    stats['function addresses -> stubs'] += 1
                    return 'far_' + f
                return mo.group(0)
            if not st.startswith(('GLOBAL', 'MODULE', 'EXTERN', 'C_LINE', 'call', 'jp')) \
                    and not re.match(r'\.\w+\s*$', st):
                new = re.sub(r'(?<![\w.])_(\w+)\b', lambda mo: addr(mo) if mo.group(1) in banked else mo.group(0), code)
                if new != code:
                    code = new
            out.append(code + sep + comment if sep else code)
        # declare the stubs this module uses
        text = ''.join(out)
        used = sorted(set(re.findall(r'\bfar_(\w+)\b', text)))
        decl = ''.join('\tGLOBAL\tfar_%s\n' % f for f in used)
        text = re.sub(r'(\tMODULE\t\w+\n)', r'\1' + decl.replace('\\', '\\\\'), text, count=1)
        open(os.path.join(OUT, mod + '.asm'), 'w').write(text)
        # check: no remaining direct cross-bank reference
        for l in text.splitlines():
            s = l.split(';')[0]
            mm = re.search(r'\bcall\s+(?:\w+,\s*)?_(\w+)\s*$', s)
            if mm and mm.group(1) in banked and (mybank is None or bank_of_func(mm.group(1)) != mybank):
                problems.append('%s: direct call to %s' % (mod, mm.group(1)))
            for f in re.findall(r'(?<![\w.])_(\w+)\b', s):
                if f in banked and not re.search(r'\bcall\b', s) and not s.strip().startswith(('GLOBAL', '.')):
                    problems.append('%s: address of %s not through a stub: %s' % (mod, f, s.strip()))
    # main() is called from the start-up code (z88/rogue_crt0.asm); the
    # resident hand-written code calls banked C through far_NAME stubs
    if 'main' in banked:
        targets.add('main')
    for hand in ('hot.asm', 'rogue_crt0.asm', 'farcall.asm'):
        for f in re.findall(r'\bfar_(\w+)', open(os.path.join(HERE, '..', 'z88', hand)).read()):
            if f in banked:
                targets.add(f)
    # stubs
    lines = ['; farstubs.asm - far-call stubs (tools/farify.py).  Resident.',
             '; far_foo: bind foo\'s bank, call foo, bind the caller\'s bank again.',
             '\tMODULE\tfarstubs', '\tSECTION\tcode_resident', '\tEXTERN\tfarcall']
    for f in sorted(targets):
        lines.append('\tEXTERN\t_%s' % f)
    for f in sorted(targets):
        lines.append('\tGLOBAL\tfar_%s' % f)
    for f in sorted(targets):
        lines.append('.far_%s\n\tld\ta,%d\n\tld\tde,_%s\n\tjp\tfarcall' % (f, bank_of_func(f), f))
    open(os.path.join(OUT, 'farstubs.asm'), 'w').write('\n'.join(lines) + '\n')
    # summary
    rep = ['far targets (stubs): %d, %d bytes of stubs' % (len(targets), 8 * len(targets))]
    for k, v in sorted(stats.items()):
        rep.append('%s: %d' % (k, v))
    for bk in sorted(set(assign.values())):
        mods = sorted(m for m, x in assign.items() if x == bk and '+' not in m)
        rep.append('bank %d: %s' % (bk, ' '.join(mods)))
    open(os.path.join(OUT, 'banks.txt'), 'w').write('\n'.join(rep) + '\n')
    print('\n'.join(rep))
    variadic = set()
    for c in glob.glob(os.path.join(SRC, '*.c')):
        for mo in re.finditer(r'^(\w+)\s*\([^;{)]*\.\.\.\s*\)', open(c, encoding='latin-1').read(), re.M):
            variadic.add(mo.group(1))
    for f in sorted(variadic & targets):
        problems.append('%s is variadic: sccz80 passes its argument count in A, '
                        'which a far-call stub overwrites - keep it resident' % f)
    if problems:
        print('PROBLEMS:', len(problems))
        for p in problems[:20]:
            print('  ', p)
        return 1
    print('check: no direct call or function address crosses a bank')
    return 0


if __name__ == '__main__':
    sys.exit(main())
