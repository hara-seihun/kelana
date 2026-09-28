#!/usr/bin/env python3
"""Regenerate the tables in FINDINGS.md from results/."""
import glob
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent


def probes():
    for f in sorted(glob.glob(str(HERE / 'results/probe-*.json'))):
        d = json.load(open(f))
        print(f"\n### {d['layer']} gradient probe (7-level codes, exact diagonal)\n")
        print('| sketch | rank | norm estimate ratio | off-diagonal cosine | top-1 gain capture'
              ' | top-8 gain capture | top-8 coupled ΔE |')
        print('|---|---:|---:|---:|---:|---:|---:|')
        for r in d['results']:
            if r['levels'] != 7 or r['diagonal'] != 'exact':
                continue
            s = {x['top_k']: x for x in r['selections']}
            print(f"| {r['kind']} | {r['rank']} | {r['captured_frobenius']:.3f} | "
                  f"{r['offdiag_cosine']:+.3f} | {s[1]['gain_capture']:+.3f} | "
                  f"{s[8]['gain_capture']:+.3f} | {s[8]['coupled_relative']:+.5f} |")


def searches():
    rows = []
    for f in sorted(glob.glob(str(HERE / 'results/*.json'))):
        d = json.load(open(f))
        if (not d['format'].startswith('kelana-random-sketch-search')
                or 'diagonal-control' in f):
            continue
        for r in d['results']:
            rows.append(dict(layer=d['layer'], **{k: r[k] for k in
                        ('kind', 'rank', 'protocol', 'levels', 'steps', 'diagonal',
                         'online_MAC_fraction')},
                        before=r['before']['relative_rms'] * 100,
                        after=r['after']['relative_rms'] * 100,
                        surr_before=r['surrogate']['selection_before'],
                        surr_after=r['surrogate']['selection_after']))
    for layer in sorted({r['layer'] for r in rows}):
        print(f"\n### {layer}: best true error per family, whole grid\n")
        print('| levels | sketch | best true error | configuration | online cost |')
        print('|---:|---|---:|---|---:|')
        for levels in sorted({r['levels'] for r in rows}):
            for kind in sorted({r['kind'] for r in rows}):
                c = [r for r in rows if r['layer'] == layer and r['levels'] == levels
                     and r['kind'] == kind and r['diagonal'] == 'exact']
                if not c:
                    continue
                b = min(c, key=lambda r: r['after'])
                print(f"| {2*levels+1} | {kind} | {b['before']:.4f}% → {b['after']:.4f}% | "
                      f"r{b['rank']} {b['protocol']} {b['steps']} steps | "
                      f"{b['online_MAC_fraction']:.2f} |")
    print('\n### Surrogate collapse versus true error, fixed sketch, 4 steps\n')
    print('| layer | sketch | rank | levels | surrogate | true |')
    print('|---|---|---:|---:|---|---|')
    for r in rows:
        if (r['protocol'] == 'fixed' and r['steps'] == 4 and r['rank'] == 256
                and r['diagonal'] == 'exact'):
            print(f"| {r['layer']} | {r['kind']} | {r['rank']} | {2*r['levels']+1} | "
                  f"{r['surr_before']:.4g} → {r['surr_after']:.4g} | "
                  f"{r['before']:.4f}% → {r['after']:.4f}% |")
    print('\n### Diagonal control, layer10 gaussian rank 256, 4 steps\n')
    print('| protocol | diagonal | negative diagonal | surrogate | true |')
    print('|---|---|---:|---|---|')
    d = json.load(open(HERE / 'results/diagonal-control-layer10.json'))
    for r in d['results']:
        if r['levels'] != 7:
            continue
        s = r['surrogate']
        print(f"| {r['protocol']} | {r['diagonal']} | "
              f"{s['selection_negative_diagonal_fraction']*100:.1f}% of entries | "
              f"{s['selection_before']:.4g} → {s['selection_after']:.4g} | "
              f"{r['before']['relative_rms']*100:.4f}% → "
              f"{r['after']['relative_rms']*100:.4f}% |")


if __name__ == '__main__':
    probes()
    searches()
