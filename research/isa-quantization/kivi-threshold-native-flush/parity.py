"""Compare complete scalar shared-source K encoder with 12 frozen donor logs."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import numpy as np
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
BASE=ROOT/'kivi-causal-cache'
METRIC=ROOT/'kivi-response-metric'
sys.path.insert(0,str(BASE))
from source import arrays,FIX_SHA


def sha(x):return hashlib.sha256(x).hexdigest()

def keys(path,log_sha):
    data=path.read_bytes();assert sha(data)==log_sha
    k=[];at=0
    while at<len(data):
        kind=data[at:at+1];t=int.from_bytes(data[at+1:at+3],'little')
        n=2560 if kind==b'K' else 80
        if kind==b'K':assert t==32*(len(k)+1);k.append(data[at+3:at+3+n])
        else:assert kind==b'V'
        at+=3+n
    assert len(k)==8
    return b''.join(k)

def compare(got,expected):
    assert len(got)==len(expected)==8*2560
    different=[i for i,(a,b) in enumerate(zip(got,expected)) if a!=b]
    return {'exact':len(different)==0,'mismatching_bytes':len(different),
            'mismatching_code_bytes':sum(i%2560<2048 for i in different),
            'mismatching_fp16_field_bytes':sum(i%2560>=2048 for i in different),
            'first_mismatches':[{'chunk':i//2560,'byte':i%2560,'native_friendly':got[i],'frozen':expected[i]} for i in different[:12]],
            'encoded_sha256':sha(got),'frozen_donor_sha256':sha(expected)}

def run(panel,window):
    src=arrays(panel,window)
    metric_report=json.loads((METRIC/f'{panel}-{window}.json').read_text())
    owner_report=json.loads((BASE/f'{panel}-{window}-manifest.json').read_text())
    metric_image=(METRIC/'metric-fp16.bin').read_bytes()
    assert metric_report['metric_fp16_sha256']==sha(metric_image)
    source=src['key'].astype('<u2').tobytes();assert len(source)==8*32*128*2
    inpath=HERE/f'{panel}-{window}-source.bin'
    outbase=HERE/f'{panel}-{window}-base.bin';outmetric=HERE/f'{panel}-{window}-metric.bin'
    inpath.write_bytes(source)
    subprocess.run([str(HERE/'encode_cpu'),str(inpath),str(METRIC/'metric-fp16.bin'),str(outbase),str(outmetric)],check=True)
    frozen_base=keys(BASE/f'{panel}-{window}-flush.bin',owner_report['flush_log_sha256'])
    frozen_metric=keys(METRIC/f'{panel}-{window}-flush.bin',metric_report['flush_log_sha256'])
    report={'panel':panel,'window':window,'fixture_sha256':FIX_SHA,'source_sha256':sha(source),
            'metric_fp16_sha256':sha(metric_image),'source_bf16_bytes':len(source),
            'original':compare(outbase.read_bytes(),frozen_base),
            'metric':compare(outmetric.read_bytes(),frozen_metric)}
    (HERE/f'{panel}-{window}-parity.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'panel':panel,'window':window,'original':report['original']['mismatching_bytes'],
                      'metric':report['metric']['mismatching_bytes']}))

if __name__=='__main__':run(sys.argv[1],int(sys.argv[2]))
