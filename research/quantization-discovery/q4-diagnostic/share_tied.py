#!/usr/bin/env python3
"""Reference an unchanged body bank with an exact shared tied matrix."""
import argparse
import json
from pathlib import Path
from calibrated import sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--body', type=Path, required=True)
    parser.add_argument('--tied', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    body = json.loads(args.body.read_text())
    tied = json.loads(args.tied.read_text())
    if not body['complete'] or not tied['complete'] or body['model_source_sha256'] != tied['model_source_sha256']:
        raise ValueError('complete images of the same source required')
    head = [e for e in tied['matrices'] if e['key'] == 'model.embed_tokens.weight']
    if len(head) != 1 or sha(head[0]['path']) != head[0]['sha256']:
        raise ValueError('invalid tied image')
    body['matrices'] = [head[0] if e['key'] == head[0]['key'] else e for e in body['matrices']]
    body['payload_bytes'] = sum(e['payload_bytes'] for e in body['matrices']) + body['norm_bytes']
    body['bpw'] = 8 * body['payload_bytes'] / body['unique_parameters']
    body['method'] = 'affine RTN body with exact same tied image as calibrated converter; referenced images unchanged'
    body['source_manifests'] = {str(p): sha(p) for p in [args.body, args.tied]}
    with args.out.open('x') as output:
        json.dump(body, output, indent=2)
        output.write('\n')


if __name__ == '__main__':
    main()
