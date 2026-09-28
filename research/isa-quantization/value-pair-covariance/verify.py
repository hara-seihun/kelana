#!/usr/bin/env python3
"""Independent BF16 Python-int replay of every selected source row dot and layer map."""
import csv
import hashlib
import json
import sys
from array import array
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCES = (
    (ROOT/'../kivi-two-bit-dot-native/original-o.bf16','803995a9d5abb24c72d3ddabd50f4e656fc5eff26efaf3b626f175fc706ab499'),
    (ROOT/'../contextual-value-feedback/original-o.bf16','677e1de44f3a28a51b2e75e806a8ec68807ed96dfadc169729c1993181418f48'),
)

def integer(bits):
    exponent=(bits>>7)&255
    if exponent==0 and bits&127==0:
        return 0
    assert 99<=exponent<=125
    return (-1 if bits&0x8000 else 1)*((128+(bits&127))<<(exponent-99))


def main():
    source=[]
    for path,digest in SOURCES:
        raw=path.read_bytes()
        assert len(raw)==4194304 and hashlib.sha256(raw).hexdigest()==digest
        words=array('H'); words.frombytes(raw)
        if sys.byteorder != 'little':
            words.byteswap()
        assert words.itemsize==2
        assert all(((x>>7)&255) in range(99,126) or (x&0x7fff)==0 for x in words)
        source.append(words)
    coefficients={}
    with (ROOT/'coefficients.tsv').open() as f:
        reader=csv.DictReader(f,delimiter='\t')
        assert reader.fieldnames==['layer','head','group','i','j','A','B','D']
        for row in reader:
            layer,h,g,i,j=(int(row[k]) for k in ('layer','head','group','i','j'))
            assert 0<=layer<2 and 0<=h<8 and 0<=g<4 and h*128+g*32<=i<j<h*128+(g+1)*32
            key=(layer,i,j)
            assert key not in coefficients
            coefficients[key]=tuple(int(row[k]) for k in ('A','B','D'))
    assert len(coefficients)==31744
    certificates={}
    with (ROOT/'certificates.tsv').open() as f:
        for row in csv.DictReader(f,delimiter='\t'):
            layer,h,g,i,j=(int(row[k]) for k in ('layer','head','group','i','j'))
            assert 0<=layer<2 and 0<=h<8 and 0<=g<4 and h*128+g*32<=i<j<h*128+(g+1)*32
            key=(layer,i,j)
            assert key not in certificates
            a,b,d=coefficients[key]
            assert int(row['fourAD_minus_B2'])==4*a*d-b*b
            positive=a>=0 and d>=0 and (b>=0 or b*b<=4*a*d)
            negative=a<=0 and d<=0 and (b<=0 or b*b<=4*a*d)
            sign='zero' if a==b==d==0 else '+' if positive else '-' if negative else 'indefinite'
            assert row['sign']==sign
            certificates[key]=sign
    assert len(certificates)==len(coefficients)
    pair_map=(ROOT/'pair-map.bin').read_bytes()
    offset=0
    selected=set()
    with (ROOT/'matching.tsv').open() as f:
        rows=list(csv.DictReader(f,delimiter='\t'))
    row_offset=0
    summary=json.loads((ROOT/'summary.json').read_text())
    assert summary['source_sha256']==[digest for _,digest in SOURCES]
    for layer in range(2):
        start=offset
        pairs=0
        distribution={}
        sign_counts={'+':0,'-':0}
        for h in range(8):
            for g in range(4):
                base=h*128+g*32
                count=pair_map[offset];offset+=1
                assert count<=16
                distribution[str(count)]=distribution.get(str(count),0)+1
                vertices=set()
                for row in rows[row_offset:row_offset+count]:
                    i,j=int(row['i']),int(row['j'])
                    assert int(row['layer'])==layer and int(row['head'])==h and int(row['group'])==g
                    assert base<=i<j<base+32 and i not in vertices and j not in vertices
                    vertices.update((i,j))
                    sign=certificates[layer,i,j]
                    assert sign in ('+','-') and sign==row['sign']
                    sign_counts[sign]+=1
                    assert pair_map[offset:offset+3]==bytes((i-base,j-base,sign=='+'))
                    offset+=3
                    selected.add((layer,i,j))
                row_offset+=count
                pairs+=count
                assert len(vertices)==2*count
        layer_summary=summary['layers'][layer]
        assert layer_summary['layer']==layer and layer_summary['pair_map_offset']==start
        assert layer_summary['pair_map_bytes']==offset-start
        assert layer_summary['pair_map_sha256']==hashlib.sha256(pair_map[start:offset]).hexdigest()
        assert distribution==layer_summary['pairs_per_group_distribution'] and sign_counts==layer_summary['matching_sign_counts']
        assert pairs==layer_summary['matching_pairs'] and 2*pairs==layer_summary['covered_coordinates']
        assert 1024-2*pairs==layer_summary['unmatched_coordinates']
        assert layer_summary['total_pairs']==15872
        assert sum(layer_summary['classification_counts'].values())==15872
        assert layer_summary['signed_graph_edges']==sum(certificates[layer,i,j] in ('+','-') for l,i,j in certificates if l==layer)
    assert row_offset==len(rows)==len(selected) and offset==len(pair_map)==summary['pair_map_bytes']
    # This route does not call the C producer: decode source words and accumulate
    # arbitrary-precision row products for each selected pair in each layer.
    for layer,i,j in selected:
        a=b=d=0
        q0i=(2*(i//128))*128+i%128
        q0j=(2*(j//128))*128+j%128
        q1i=q0i+128; q1j=q0j+128
        for k in range(1024):
            x=integer(source[layer][k*2048+q0i]); y=integer(source[layer][k*2048+q0j])
            z=integer(source[layer][k*2048+q1i]); w=integer(source[layer][k*2048+q1j])
            a+=x*y; b+=x*w+z*y; d+=z*w
        assert coefficients[layer,i,j]==(a,b,d),(layer,i,j)
    for key,name in (('coefficients_sha256','coefficients.tsv'),('certificates_sha256','certificates.tsv'),('matching_sha256','matching.tsv'),('pair_map_sha256','pair-map.bin')):
        assert summary[key]==hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
    print(f'{len(selected)} selected pairs: independent exact Python-int layer-local Q-head O-row replay, all 31744 certificate predicates and {len(pair_map)}-byte layer-indexed layout agree')

if __name__=='__main__':
    main()
