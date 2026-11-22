#!/usr/bin/env python3
"""z80size.py - byte size of sccz80 assembler output, by section.

Adds up the exact encoded length of every Z80 instruction and data directive
in z88dk/sccz80 .asm files (z80asm syntax), per SECTION:
    code_*    code             -> card (ROM)
    rodata_*  constant data    -> card
    data_*    initialised data -> card AND RAM (copied at start)
    bss_*     zeroed RAM       -> RAM only
and lists the library routines called (l_*, printf ...), which are not in
these files and must be added.

usage: z80size.py FILE.asm ...      (prints a table; --json for machine use)
"""
import json
import re
import sys

R8 = {'a', 'b', 'c', 'd', 'e', 'h', 'l'}
R16 = {'bc', 'de', 'hl', 'sp'}
IXY = {'ix', 'iy'}
IXY8 = {'ixh', 'ixl', 'iyh', 'iyl'}
CC = {'nz', 'z', 'nc', 'c', 'po', 'pe', 'p', 'm'}
ONE = {'rla', 'rra', 'rlca', 'rrca', 'ccf', 'scf', 'cpl', 'daa', 'nop', 'halt',
       'di', 'ei', 'exx'}
TWO = {'neg', 'ldi', 'ldir', 'ldd', 'lddr', 'cpi', 'cpir', 'cpd', 'cpdr',
       'ini', 'inir', 'ind', 'indr', 'outi', 'otir', 'outd', 'otdr', 'reti',
       'retn', 'rld', 'rrd'}
CB = {'rlc', 'rrc', 'rl', 'rr', 'sla', 'sra', 'sll', 'sli', 'srl'}
ALU = {'add', 'adc', 'sub', 'sbc', 'and', 'or', 'xor', 'cp'}


def kind(op):
    """Classify an operand."""
    o = op.strip().lower()
    if o in R8:
        return 'r'
    if o in R16:
        return 'rr'
    if o in IXY:
        return 'ix'
    if o in IXY8:
        return 'ixr'
    if o in ('af', "af'"):
        return 'af'
    if o in ('i', 'r'):
        return 'ir'
    if o == '(hl)':
        return '(hl)'
    if o in ('(bc)', '(de)'):
        return '(rr)'
    if o == '(sp)':
        return '(sp)'
    if o == '(c)':
        return '(c)'
    if re.fullmatch(r'\((ix|iy)\)', o) or re.fullmatch(r'\((ix|iy)\s*[-+].*\)', o):
        return '(ix+d)'
    if o.startswith('(') and o.endswith(')') and _balanced(o[1:-1]):
        return '(nn)'
    return 'n'


def _balanced(s):
    d = 0
    for ch in s:
        d += ch == '('
        d -= ch == ')'
        if d < 0:
            return False
    return d == 0


def split_ops(s):
    ops, depth, cur, q = [], 0, '', None
    for ch in s:
        if q:
            cur += ch
            if ch == q:
                q = None
            continue
        if ch in '"\'':
            # af' is not a string
            if ch == "'" and cur.strip().lower() == 'af':
                cur += ch
                continue
            q = ch
            cur += ch
            continue
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        if ch == ',' and depth == 0:
            ops.append(cur.strip())
            cur = ''
        else:
            cur += ch
    if cur.strip():
        ops.append(cur.strip())
    return ops


def insn_size(mn, ops):
    k = [kind(o) for o in ops]
    pre = 1 if any(x in ('ix', 'ixr', '(ix+d)') for x in k) else 0
    if mn in ONE:
        return 1
    if mn in TWO:
        return 2
    if mn == 'ld':
        a, b = k
        if a == 'r' and b == 'r':
            return 1
        if a in ('r', 'ixr') and b in ('r', 'ixr'):
            return 2
        if a in ('r', 'ixr') and b == 'n':
            return 2 + pre
        if (a == 'r' and b == '(hl)') or (a == '(hl)' and b == 'r'):
            return 1
        if a == '(hl)' and b == 'n':
            return 2
        if (a == 'r' and b == '(rr)') or (a == '(rr)' and b == 'r'):
            return 1
        if (a == 'r' and b == '(nn)') or (a == '(nn)' and b == 'r'):
            return 3
        if a == 'r' and b == 'ir' or a == 'ir' and b == 'r':
            return 2
        if a == 'r' and b == '(ix+d)' or a == '(ix+d)' and b == 'r':
            return 3
        if a == '(ix+d)' and b == 'n':
            return 4
        if a == 'rr' and b == 'n':
            return 3
        if a == 'ix' and b == 'n':
            return 4
        if a == 'rr' and b == '(nn)':
            return 3 if ops[0].lower() == 'hl' else 4
        if a == '(nn)' and b == 'rr':
            return 3 if ops[1].lower() == 'hl' else 4
        if a == 'ix' and b == '(nn)' or a == '(nn)' and b == 'ix':
            return 4
        if a == 'rr' and b == 'rr':          # ld sp,hl
            return 1
        if a == 'rr' and b == 'ix':          # ld sp,ix
            return 2
    if mn in ALU:
        if len(ops) == 2 and k[0] in ('rr', 'ix'):     # 16-bit
            if mn == 'add':
                return 1 + pre
            return 2                                   # adc/sbc hl,rr
        src = k[-1]
        if src == 'r' or src == '(hl)':
            return 1
        if src == 'ixr':
            return 2
        if src == 'n':
            return 2
        if src == '(ix+d)':
            return 3
    if mn in ('inc', 'dec'):
        x = k[0]
        if x in ('r', 'rr', '(hl)'):
            return 1
        if x in ('ix', 'ixr'):
            return 2
        if x == '(ix+d)':
            return 3
    if mn in ('push', 'pop'):
        return 2 if k[0] == 'ix' else 1
    if mn in ('jp', 'call'):
        if mn == 'jp' and k[-1] in ('(hl)',):
            return 1
        if mn == 'jp' and k[-1] == '(ix+d)':     # jp (ix)
            return 2
        return 3
    if mn in ('jr', 'djnz'):
        return 2
    if mn == 'ret':
        return 1
    if mn == 'rst':
        return 1
    if mn == 'ex':
        if k[0] == '(sp)' and k[1] == 'ix':
            return 2
        return 1
    if mn in CB:
        return 4 if k[0] == '(ix+d)' else 2
    if mn in ('bit', 'set', 'res'):
        return 4 if k[1] == '(ix+d)' else 2
    if mn == 'im':
        return 2
    if mn in ('in', 'out'):
        return 2
    raise ValueError('unknown instruction: %s %s' % (mn, ','.join(ops)))


def str_len(s):
    """Length of a "..." literal in z80asm syntax (backslash escapes)."""
    body = s[1:-1]
    n, i = 0, 0
    while i < len(body):
        if body[i] == '\\' and i + 1 < len(body):
            i += 2
            if body[i - 1] == 'x':
                while i < len(body) and body[i] in '0123456789abcdefABCDEF':
                    i += 1
            elif body[i - 1] in '01234567':
                while i < len(body) and body[i] in '01234567' and i < len(body):
                    i += 1
        else:
            i += 1
        n += 1
    return n


def data_size(d, ops):
    if d in ('defb', 'db', 'defm', 'dm', 'byte'):
        return sum(str_len(o) if o[:1] in '"' else 1 for o in ops)
    if d in ('defw', 'dw', 'word'):
        return 2 * len(ops)
    if d in ('defq', 'dword', 'defl'):
        return 4 * len(ops)
    if d in ('defs', 'ds'):
        return int(eval(ops[0].replace('$', '0x'), {}))
    return None


def size_file(path, totals, calls, unknown):
    section = 'code_compiler'
    for raw in open(path, encoding='latin-1'):
        line = raw.split(';', 1)[0] if '"' not in raw else _strip_comment(raw)
        line = line.strip()
        if not line or line.startswith('.') and ' ' not in line and '\t' not in line:
            continue
        if line.startswith('.'):                    # label then statement
            line = re.split(r"\s+", line, maxsplit=1)[1]
        parts = re.split(r"\s+", line, maxsplit=1)
        word = parts[0].lower()
        rest = parts[1] if len(parts) > 1 else ''
        if word == 'section':
            section = rest.strip()
            continue
        if word in ('module', 'include', 'global', 'extern', 'public', 'defc',
                    'c_line', 'if', 'ifdef', 'ifndef', 'else', 'endif', 'org',
                    'xdef', 'xref', 'lib', 'xlib', 'align'):
            continue
        ops = split_ops(rest)
        n = data_size(word, ops)
        if n is None:
            try:
                n = insn_size(word, ops)
            except (ValueError, IndexError):
                unknown.append('%s: %s' % (path, line))
                continue
            if word in ('call', 'jp') and ops:
                t = ops[-1]
                if re.fullmatch(r'[A-Za-z_]\w*', t) and not t.startswith('i_'):
                    calls.setdefault(t, 0)
                    calls[t] += 1
        sect = section.split('_')[0]
        totals[sect] = totals.get(sect, 0) + n


def _strip_comment(s):
    out, q = '', None
    for ch in s:
        if q:
            out += ch
            if ch == q:
                q = None
            continue
        if ch == '"':
            q = ch
        if ch == ';':
            break
        out += ch
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    rows, allcalls, unknown = [], {}, []
    for p in args:
        t, c = {}, {}
        size_file(p, t, c, unknown)
        rows.append((p, t))
        for k, v in c.items():
            allcalls[k] = allcalls.get(k, 0) + v
    defined = set()
    for p in args:
        for line in open(p, encoding='latin-1'):
            m = re.match(r'^\.(\w+)', line)
            if m:
                defined.add(m.group(1))
    external = {k: v for k, v in allcalls.items() if k not in defined}
    if '--json' in sys.argv:
        print(json.dumps({'files': rows, 'external_calls': external, 'unknown': unknown}))
        return
    keys = ['code', 'rodata', 'data', 'bss']
    print('%-14s %7s %7s %7s %7s' % ('file', *keys))
    tot = dict.fromkeys(keys, 0)
    for p, t in sorted(rows, key=lambda r: -r[1].get('code', 0)):
        print('%-14s %7d %7d %7d %7d' % (p.rsplit('/', 1)[-1], *[t.get(k, 0) for k in keys]))
        for k in keys:
            tot[k] += t.get(k, 0)
    print('%-14s %7d %7d %7d %7d' % ('TOTAL', *[tot[k] for k in keys]))
    print('\nexternal routines called (library):', len(external))
    print(' '.join('%s(%d)' % kv for kv in sorted(external.items(), key=lambda kv: -kv[1])))
    if unknown:
        print('\nUNSIZED lines:', len(unknown))
        for u in unknown[:20]:
            print('  ', u)


if __name__ == '__main__':
    main()
