#!/usr/bin/env python3
"""Exact group-rate allocation on frozen train-selected mixed three/four-bit keys."""
import argparse
import hashlib
import json
from pathlib import Path

DATA=Path('/path/to/workspace/data/kelana-subbit')


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--layer',type=int,choices=(0,14),required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    source=DATA/f'key-three-bit/layer{args.layer:02d}-mixed.json'
    mixed=json.loads(source.read_text())
    groups=mixed['groups']
    results={}
    for budget in (0,8,16,24,32):
        dp={0:(0.,[])}
        for g in groups:
            next_dp={}
            for used,(cost,alloc) in dp.items():
                for octets in range(5):
                    total=used+octets
                    if total>budget:continue
                    score=cost+g['arms'][str(8*octets)]['train_kl']
                    if total not in next_dp or score<next_dp[total][0]:next_dp[total]=(score,alloc+[octets])
            dp=next_dp
        score,allocation=dp[budget]
        window=[sum(groups[g]['arms'][str(8*octets)]['held_by_window'][w] for g,octets in enumerate(allocation))/8 for w in range(4)]
        results[str(budget)]={'extra_bytes':budget,'cache_bytes_per_token_layer':96+budget,
                              'group_promoted_coordinates':[8*i for i in allocation],
                              'train_kl':score/8,'held_by_window':window,'held_mean':sum(window)/4,
                              'uniform_held_mean':mixed['held_mean'][str(budget)]}
    report={'layer':args.layer,'grammar':'each group adds 0,8,16,24 or 32 fourth-bit coordinates in its train-ranked order, packed in whole bytes; exact eight-group dynamic programming minimizes sum of sampled causal train KL at fixed 0/8/16/24/32 additional cache bytes per occupied key/layer',
            'results':results,'source_sha256':sha(Path(__file__)),'mixed_sha256':sha(source),
            'upstream_input_hashes':{k:v for k,v in mixed.items() if k.endswith('_sha256') and k!='source_sha256'}}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:{'group_promoted_coordinates':v['group_promoted_coordinates'],'held_mean':v['held_mean'],'uniform_held_mean':v['uniform_held_mean']} for k,v in results.items()},indent=2))


if __name__=='__main__':main()
