#!/usr/bin/env python3
"""Exact 26-coordinate live encoding for all root-byte residual dots."""
from fractions import Fraction as F
import json
from pathlib import Path
from replay import root_twice


def prepare(z):
    assert len(z)==8
    triples=[]
    for start in (0,3):
        triples.extend(sum((1-2*((mask>>j)&1))*z[start+j] for j in range(3)) for mask in range(8))
    return triples+[z[6]+z[7],z[6]-z[7]]+list(z)


def observe(code,values):
    assert 0<=code<256 and len(values)==26
    if code<128:
        if code==127:
            return F(0)
        i=code&7;j=(code>>3)&7
        sign=1-2*((code>>6)&1)
        return sign*(values[18+i]+(1 if i<=j else -1)*values[18+j])
    negate=(code>>6)&1
    mask=(code&127)^(127 if negate else 0)
    assert mask<64
    a=mask&7;b=(mask>>3)&7
    parity=(a.bit_count()+b.bit_count())&1
    return F(1-2*negate,2)*(values[a]+values[8+b]+values[16+parity])


def main():
    for code in range(256):
        expected=root_twice(code)
        for axis in range(8):
            basis=[F(int(i==axis)) for i in range(8)]
            assert observe(code,prepare(basis))==F(int(expected[axis]),2)
    result={'arithmetic':'exact rational','root_codes':256,'linear_basis_checks':2048,
            'live_encoding_coordinates':26,'signed_three_coordinate_sums':16,
            'last_pair_sums':2,'original_coordinates':8,'max_selected_coordinates_per_dot':3,
            'model_specific_bytes_added':0,'native_speed_claim':False}
    path=Path(__file__).with_name('wave-basis.json')
    path.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
