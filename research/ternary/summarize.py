#!/usr/bin/env python3
"""Collect saved whole-model receipts without fitting or evaluating again."""
import json
from pathlib import Path
from pilot import ROOT, sha

def main():
    result={'fixture_sha256':sha(ROOT/'tokens.npz'),'quality':[],'images':[]}
    for path in sorted((ROOT/'quality').glob('*.json')):
        record=json.loads(path.read_text())
        result['quality'].append({'path':str(path),'sha256':sha(path),**record})
    for path in sorted(ROOT.glob('*/manifest.json')):
        record=json.loads(path.read_text())
        result['images'].append({'path':str(path),'sha256':sha(path),'complete':record['complete'],
            'payload_bytes':record['payload_bytes'],'bpw':record['bpw'],'matrix_count':record['matrix_count'],
            'package_file_bytes':sum(p.stat().st_size for p in path.parent.iterdir() if p.is_file())})
    out=Path(__file__).with_name('results.json')
    out.write_text(json.dumps(result,indent=2)+'\n')
    print(out)

if __name__=='__main__':main()
