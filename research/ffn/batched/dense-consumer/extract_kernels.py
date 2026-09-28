#!/usr/bin/env python3
"""Pull named kernels out of emitted device assembly, so evidence files stay small and readable.

Used to keep the V_PERM_B32 folding comparison's assembly next to its measured results: whether a
call was folded is visible in whether any v_perm_b32 survives in the body.

    python3 extract_kernels.py build/check.s results/perm-folding.s k_perm_folded k_perm_runtime
"""
import hashlib
import re
import sys


def extract(src, want):
    out = []
    # label line, optionally followed by the assembler's own trailing comment
    for m in re.finditer(r'^(\S*' + re.escape(want) + r'\S*):[ \t]*(?:;.*)?$', src, re.M):
        name = m.group(1)
        if name.startswith('.'):
            continue
        end = src.find('.Lfunc_end', m.end())
        if end < 0:
            continue
        end = src.find('\n', end)
        body = src[m.start():end + 1]
        perms = len(re.findall(r'^\s*v_perm_b32\b', body, re.M))
        out.append((name, body, perms))
    return out


def main(argv):
    if len(argv) < 4:
        print(__doc__)
        return 2
    asm_path, out_path, names = argv[1], argv[2], argv[3:]
    src = open(asm_path).read()
    digest = hashlib.sha256(src.encode()).hexdigest()
    chunks = [f'; extracted from {asm_path}\n; full device assembly sha256 {digest}\n'
              f'; a folded call leaves no v_perm_b32 in the body; a real one leaves exactly one per call\n']
    for want in names:
        found = extract(src, want)
        if not found:
            print(f'{want}: not found in {asm_path}', file=sys.stderr)
            return 1
        for name, body, perms in found:
            chunks.append(f'\n; ---- {name}: {perms} v_perm_b32 instruction(s) ----\n{body}')
            print(f'{name}: {perms} v_perm_b32')
    open(out_path, 'w').write(''.join(chunks))
    print('wrote', out_path)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
