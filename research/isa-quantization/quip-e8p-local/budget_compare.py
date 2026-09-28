#!/usr/bin/env python3
"""Exact ideal RVQ response and all-cardinality covariance budget certificates."""
import importlib.util
import json
from fractions import Fraction as F
from math import lcm
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent


def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def integer_hadamard(x):
    out=x.copy()
    width=1
    while width<128:
        for start in range(0,128,2*width):
            a=out[:,start:start+width].copy()
            b=out[:,start+width:start+2*width].copy()
            out[:,start:start+width]=a+b
            out[:,start+width:start+2*width]=a-b
        width*=2
    return out


def exact_reader(reader):
    data=reader.asset('quip-rvq3-r0.bin')
    codes=np.frombuffer(data,dtype='<u2',count=2048).reshape(128,16)
    residual=np.frombuffer(data,dtype='u1',count=2048,offset=4096).reshape(128,16)
    signs=codes&255
    parity=np.bitwise_xor.reduce((signs[...,None]>>np.arange(8))&1,axis=-1)
    signs=signs^parity
    ab=np.frombuffer(reader.asset('e8p-abs-grid.bin'),dtype='<u4')
    perm=[0,4,1,5,2,6,3,7]
    packed=ab[codes>>8]
    main=np.stack([((packed>>(4*i))&15).astype('int64') for i in perm],axis=-1)
    main=2*(main-8)*(1-2*((signs[...,None]>>np.array(perm))&1))+(1-2*parity)[...,None]
    grid=np.frombuffer(reader.asset('e81b-grid.bin'),dtype='<f2').astype('float64')*4
    assert np.isfinite(grid).all() and np.array_equal(grid,np.rint(grid))
    extra=grid.astype('int64').reshape(256,8)[residual]
    qnum=(51*main+25*extra).reshape(128,128).astype('int64')
    assert int(np.max(np.abs(qnum)))*128*128<np.iinfo(np.int64).max
    su=1-2*np.unpackbits(np.frombuffer(data[6144:6160],dtype='u1'),bitorder='little').astype('int64')
    sv=1-2*np.unpackbits(np.frombuffer(data[6160:6176],dtype='u1'),bitorder='little').astype('int64')
    scale=F(float(np.frombuffer(data[6176:],dtype='<f2')[0]))
    numerator=(integer_hadamard((integer_hadamard(qnum)*su).T)*sv).T.astype(object)*scale.numerator
    denominator=204*128*scale.denominator
    expected=reader.decode_rvq3()[0]
    assert np.max(np.abs(np.asarray(numerator,dtype='float64')/denominator-expected))<1e-12
    return numerator,denominator


def main():
    # Recheck the source PSD/cone certificates, not just their display decimals.
    linear=load('linear_certificate',ROOT/'full-pair-covariance/verify.py')
    affine=load('affine_certificate',ROOT/'affine-pair-covariance/verify.py')
    linear.main()
    affine.main()
    reader=load('rvq_reader',HERE/'replay.py')
    numerator,denominator=exact_reader(reader)
    with np.load(reader.FIX) as fixture:
        x=fixture['train'][:,:128].astype('float64')
        w=fixture['weight'][:128,:128].astype('float64')
    xs=x*2**27;ws=w*2**28
    assert np.isfinite(xs).all() and np.isfinite(ws).all()
    assert np.array_equal(xs,np.rint(xs)) and np.array_equal(ws,np.rint(ws))
    assert max(np.max(np.abs(xs)),np.max(np.abs(ws)))<np.iinfo(np.int64).max
    xi=xs.astype('int64');wi=ws.astype('int64').astype(object)
    gram=linear.mod.exact_gram(xi)
    source=int(np.sum(gram*(wi.T@wi)))
    common=lcm(2**28,denominator)
    error=wi*(common//2**28)-numerator*(common//denominator)
    raw=int(np.sum(gram*(error.T@error)))
    actual=F(raw*2**56,source*common**2)
    rows=[]
    for affine_flag,name in ((0,'full-pair-covariance'),(1,'affine-pair-covariance')):
        receipt=json.loads((ROOT/name/'verified.json').read_text())
        value=F(receipt['universal_floor_rational']) if not affine_flag else F(
            int(receipt['universal_floor_numerator']),int(receipt['universal_floor_denominator']))
        with np.load(ROOT/name/'spectral-certificate.npz') as certificate:
            slope=F(int(certificate['cardinality'][0]),2**50)
        assert slope>0
        for bits in range(1,5):
            base=2048*bits+642+256*affine_flag
            saving=16*bits-2
            pairs=max(0,-((6178-base)//saving))
            feasible=pairs<=64
            floor=max(F(0),value+(pairs-32)*slope) if feasible else None
            rows.append({'affine_intercept':bool(affine_flag),'output_bits':bits,
                         'byte_budget':6178,'minimum_pairs':pairs,'description_at_minimum':base-saving*pairs,
                         'grammar_feasible':feasible,'floor':None if floor is None else str(floor),
                         'floor_decimal':None if floor is None else float(floor),
                         'cannot_match_achieved_rvq_train_error':not feasible or floor>actual})
    assert all(row['cannot_match_achieved_rvq_train_error']==(row['output_bits']==4) for row in rows)
    result={'image_sha256':reader.ASSETS['quip-rvq3-r0.bin'],
            'ideal_residual_scale':'51/25','ideal_hadamard_normalization_after_two_transforms':'1/128',
            'exact_train_error':str(actual),'train_error_decimal':float(actual),
            'generic_codebook_assets_shared_model_bytes':5120,
            'payload_comparison_requires_shared_generic_reader_assets':True,
            'self_describing_pair_bytes':'16*b*(128-m)+640+2*m+256*a+2','comparisons':rows}
    (HERE/'budget.json').write_text(json.dumps(result,indent=2)+'\n')
    print('exact ideal RVQ train error',float(actual))
    for row in rows:
        print(row['affine_intercept'],row['output_bits'],row['minimum_pairs'],
              row['floor_decimal'],row['cannot_match_achieved_rvq_train_error'])


if __name__=='__main__':main()
