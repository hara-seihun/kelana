#!/usr/bin/env python3
"""Replay the emitted FP16 two-chart source-average output map, no hidden tensor online."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from screen import HERE, load


def chart(index):
    payload=(HERE/f'chart-{index}.bin').read_bytes()
    assert len(payload)==2*1024*1024+2*1024
    expected=json.loads((HERE/f'chart-{index}.json').read_text())['sha256']
    assert hashlib.sha256(payload).hexdigest()==expected
    data=np.frombuffer(payload,dtype='<f2').astype(np.float32)
    return data[:1024*1024].reshape(1024,1024),data[1024*1024:]


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--split',choices=('train','held'),required=True)
    args=p.parse_args()
    panel=load(args.split)
    router_payload=(HERE/'router.bin').read_bytes()
    assert len(router_payload)==2050
    expected=json.loads((HERE/'chart-0.json').read_text())['router_payload_sha256']
    assert hashlib.sha256(router_payload).hexdigest()==expected
    assert expected==json.loads((HERE/'chart-1.json').read_text())['router_payload_sha256']
    vector=np.frombuffer(router_payload[:2048],dtype='<f2').astype(np.float32)
    threshold=float(np.frombuffer(router_payload[2048:],dtype='<f2')[0])
    route=(panel['inputs'].astype(np.float32)@vector>=np.float32(threshold))
    out=np.zeros((len(route),1024),dtype=np.float32)
    for r in (False,True):
        w,b=chart(int(r))
        ids=np.flatnonzero(route==r)
        out[ids]=panel['inputs'][ids].astype(np.float32)@w.T+b[None,:]
    target=panel['target'].astype(np.float32)
    baseline=panel['q4'].astype(np.float32)
    relative=lambda p:float(np.linalg.norm((p-target).astype(np.float64))/np.linalg.norm(target.astype(np.float64)))
    result=dict(split=args.split,physical_bytes=32+2048+2+2*(2099200),
        chart_payload_sha256=[json.loads((HERE/f'chart-{j}.json').read_text())['sha256'] for j in (0,1)],
        fp16_router_direction_sha256=hashlib.sha256(vector.astype('<f2').tobytes()).hexdigest(),
        fp16_router_threshold=threshold,
        route_counts=[int(np.sum(route==r)) for r in (False,True)],
        atlas_fp16_relative_rms=relative(out),q4_control_relative_rms=relative(baseline),
        improvement_over_q4=relative(out)<relative(baseline),
        router_payload_sha256=expected,full_image_emitted=False)
    (HERE/f'score-{args.split}.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))


if __name__=='__main__':main()
