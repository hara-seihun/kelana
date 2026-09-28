#!/usr/bin/env python3
"""Compile a source-averaged two-chart response atlas into raw FP16 output maps."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from screen import HERE, chart_average, load, router, weights


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--chart',type=int,choices=(0,1),required=True)
    args=p.parse_args()
    train=load('train')
    source=weights()
    direction,threshold,_=router(train)
    router_payload=direction.astype('<f2').tobytes()+np.asarray([threshold],dtype='<f2').tobytes()
    router_path=HERE/'router.bin'
    if args.chart==0:
        router_path.write_bytes(router_payload)
    else:
        assert router_path.read_bytes()==router_payload
    route=(train['inputs']@direction)>=threshold
    fields=chart_average(train,route==bool(args.chart),source)
    left=source['down']@(fields['alpha'][:,None]*source['gate'])
    right=source['down']@(fields['beta'][:,None]*source['up'])
    jacobian=left+right
    bias=fields['output']-jacobian@fields['center']
    payload=jacobian.astype('<f2').tobytes()+bias.astype('<f2').tobytes()
    assert len(payload)==2*1024*1024+2*1024
    path=HERE/f'chart-{args.chart}.bin'
    path.write_bytes(payload)
    receipt=dict(chart=args.chart,bytes=len(payload),sha256=hashlib.sha256(payload).hexdigest(),
        router_direction_fp16_sha256=hashlib.sha256(direction.astype('<f2').tobytes()).hexdigest(),
        router_payload_sha256=hashlib.sha256(router_payload).hexdigest(),
        router_threshold_fp16=float(np.float16(threshold)),
        jacobian_fp16_nonfinite=int(np.sum(~np.isfinite(jacobian.astype(np.float16)))),
        bias_fp16_nonfinite=int(np.sum(~np.isfinite(bias.astype(np.float16)))))
    (HERE/f'chart-{args.chart}.json').write_text(json.dumps(receipt,indent=2)+'\n')
    assert receipt['jacobian_fp16_nonfinite']==receipt['bias_fp16_nonfinite']==0
    print(json.dumps(receipt))


if __name__=='__main__':main()
