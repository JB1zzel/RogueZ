"""
mthtok.py - a token table made for Rogue's help, for mthtoken.

    table(help_inc_text) -> token table bytes (the format of OZ's
                            systokens.bin: mthtoken -tkt reads it)

OZ expands tokens with the table the DOR points at.  OZ's own system table
is in the OZ ROM, which an application's DOR cannot point at (its bank
numbers are its own), and a copy would cost 667 bytes; this table is built
from the help text itself (about 280 bytes).  mthtoken (tools/mkcard.py)
does the tokenizing against it.

Byte-pair encoding: the commonest pair of printable bytes becomes a token
($80 up), again and again while a pair still saves more than its 4 bytes in
the table (2 of string, 2 of offset).  A token's string may hold earlier
tokens: OZ expands tokens inside tokens (the table's first byte, the
"recursive token boundary", is $80).  Layout, as systokens.asm:
    defb $80, n ; defw offsets of each token and of the end (from the table)
    the token strings
"""
import collections
import re


def _bytes(args):
    b = bytearray()
    for part in re.findall(r'"[^"]*"|\$[0-9A-Fa-f]+|\d+', args):
        if part.startswith('"'):
            b += part[1:-1].encode('latin-1')
        elif part.startswith('$'):
            b.append(int(part[1:], 16))
        else:
            b.append(int(part))
    return b


def table(text, first=0x80, last=0xFF):
    seqs = [list(_bytes(l.strip()[4:])) for l in text.splitlines()
            if l.strip().lower().startswith('defm')]
    assert all(c < 0x80 for s in seqs for c in s), 'help text already has bytes >= $80'
    ok = lambda c: c >= 0x20 and c != 0x7F       # not $7F (new line) or codes
    tokens = []
    for code in range(first, last + 1):
        cnt = collections.Counter()
        for s in seqs:
            for j in range(len(s) - 1):
                if ok(s[j]) and ok(s[j + 1]):
                    cnt[(s[j], s[j + 1])] += 1
        if not cnt:
            break
        pair, n = cnt.most_common(1)[0]
        if n <= 4:
            break
        for s in seqs:
            j = 0
            while j < len(s) - 1:
                if s[j] == pair[0] and s[j + 1] == pair[1]:
                    s[j:j + 2] = [code]
                j += 1
        tokens.append(pair)
    n = len(tokens)
    head = 2 + 2 * (n + 1)
    out = bytearray([first, n])
    for k in range(n + 1):
        out += (head + 2 * k).to_bytes(2, 'little')
    for p in tokens:
        out += bytes(p)
    return bytes(out)


def asm(tab):
    """The table as assembler for mth.asm (label in_tokens)."""
    lines = ['in_tokens:']
    for i in range(0, len(tab), 16):
        lines.append('        defb    ' + ', '.join('$%02X' % c for c in tab[i:i + 16]))
    return '\n'.join(lines) + '\n'


def scan(tab):
    """mthtoken's -scan file: the tokens longest (expanded) first, which
    tokenizes the help as small as the pair merging that made the table."""
    n, first = tab[1], tab[0]

    def expand(c):
        o = tab[2 + 2 * (c - first)] | tab[3 + 2 * (c - first)] << 8
        return b''.join(expand(x) if x >= first else bytes([x]) for x in tab[o:o + 2])
    order = sorted(range(first, first + n), key=lambda c: -len(expand(c)))
    return ','.join('0x%02X' % c for c in order) + '\n'
