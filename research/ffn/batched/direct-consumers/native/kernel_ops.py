#!/usr/bin/env python3
"""Count the instructions in each rate kernel's inner loop, from the emitted device assembly.

The rate probe's claimed op counts are only trustworthy if the assembly agrees, so read them out
of the assembly instead: for every k_rate<V> kernel, take the inner loop body (the block that ends
in the backward branch) and count VALU, SALU and other instructions in it. Eight chains run per
loop iteration, so VALU/8 is the per-application issue cost.
"""
import json
import re
import sys

KERNEL = re.compile(r"^(_Z6k_rate[^:]*|_Z\d+k_bilinear[^:]*):")


def main(path):
    lines = open(path).read().splitlines()
    kernels, cur, start = {}, None, None
    for i, line in enumerate(lines):
        m = KERNEL.match(line.strip())
        if m:
            cur, start = m.group(1), i
        elif cur and line.strip().startswith("s_endpgm"):
            kernels[cur] = (start, i)
            cur = None

    out = {}
    for name, (a, b) in kernels.items():
        body = lines[a:b]
        # inner loop: from the last loop label to the backward branch to that label
        labels = [(i, l.strip().split(":")[0]) for i, l in enumerate(body) if re.match(r"^\.LBB\d+_\d+:", l.strip())]
        loop = None
        for i, lab in labels:
            for j in range(i + 1, len(body)):
                if re.search(r"s_cbranch\w*\s+" + re.escape(lab) + r"\b", body[j]) or re.search(
                    r"s_branch\s+" + re.escape(lab) + r"\b", body[j]
                ):
                    if loop is None or (j - i) > (loop[1] - loop[0]):
                        loop = (i, j)
                    break
        if loop is None:
            continue
        counts = {"valu": 0, "salu": 0, "other": 0, "instructions": 0}
        valu = []
        for l in body[loop[0] + 1 : loop[1]]:
            t = l.strip()
            if not t or t.startswith((";", ".", "//")):
                continue
            op = t.split()[0]
            counts["instructions"] += 1
            if op.startswith("v_"):
                counts["valu"] += 1
                valu.append(op)
            elif op.startswith("s_"):
                counts["salu"] += 1
            else:
                counts["other"] += 1
        counts["valu_sequence"] = valu
        short = re.sub(r"^_Z6k_rateI\d*", "", name)
        short = re.sub(r"EvPKiS?\d*_?Pi+i*$", "", short)
        short = re.sub(r"^_Z\d+k_bilinearIL", "bilinear-", short)
        short = re.sub(r"E+$", "", short)
        out[short] = counts
    json.dump(out, sys.stdout, indent=1)
    print()


if __name__ == "__main__":
    main(sys.argv[1])
