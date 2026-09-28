"""Recustody the exact E8P magnitude alphabet as a combinatorial byte program."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import numpy as np
from replay import magnitudes, main_four, dot_four, decode, root, PERM

HERE=Path(__file__).resolve().parent
SOURCE_SHA='d39500d3a5fbfd3260f4139d064ab00654582e15e4fc461fc923502d841f907a'


def main():
    source=(HERE.parent/'e8-root-program/quip-root-standalone.bin').read_bytes()
    assert len(source)==50322 and hashlib.sha256(source).hexdigest()==SOURCE_SHA
    packed=np.frombuffer(source[49298:],dtype='<u4')
    v=((packed[:,None]>>(4*np.arange(8,dtype=np.uint32)))&15).astype(np.int16)-8
    assert set(np.unique(abs(v)))=={1,3,5}
    assert np.all(v[:,:7]>0)
    assert np.all((v.sum(1)%4)==0)
    odd=((abs(v)==3).sum(1)&1)
    assert np.array_equal(v[:,7]<0,odd!=0)
    exceptional=sorted(sum(int(abs(row[i])==3)<<i for i in range(8))
                       for row in v if np.count_nonzero(abs(row)==3)==5)
    assert len(exceptional)==29 and len(set(exceptional))==29
    exceptions=bytes(exceptional)
    generated=np.stack([magnitudes(c,exceptions) for c in range(256)])
    labels={tuple(row):i for i,row in enumerate(generated)}
    assert len(labels)==256 and set(map(tuple,v))==set(labels)
    permutation=np.array([labels[tuple(row)] for row in v],dtype=np.uint16)
    assert len(set(permutation.tolist()))==256
    eye=np.eye(8,dtype=np.int64)
    signs=np.arange(256,dtype=np.int64)
    parity=np.array([int(x).bit_count()&1 for x in signs])
    corrected=signs^parity
    sigma=1-2*((corrected[:,None]>>np.arange(8))&1)
    for old_high in range(256):
        expected=(2*v[old_high]*sigma+(1-2*parity)[:,None])[:,PERM]
        high=int(permutation[old_high])
        for low in range(256):
            code=256*high+low
            assert np.array_equal(main_four(code,exceptions),expected[low])
            assert np.array_equal(dot_four(code,eye,exceptions),expected[low])
    old=np.frombuffer(source,dtype='<u2',count=16384)
    new=(permutation[old>>8]<<8)|(old&255)
    image=new.astype('<u2').tobytes()+source[32768:49298]+exceptions
    assert len(image)==49327
    assert np.array_equal(decode(image),root.decode(source))
    (HERE/'quip-combinatorial-standalone.bin').write_bytes(image)
    counts=Counter(int(x) for x in new>>8)
    result={
        'source_sha256':SOURCE_SHA,
        'image_sha256':hashlib.sha256(image).hexdigest(),
        'bytes':len(image),'model_specific_bytes':49298,
        'generic_exception_mask_bytes':29,
        'generic_absolute_table_bytes_removed':1024,
        'additional_generic_bytes_saved_once':995,
        'total_generic_bytes_saved_vs_original_rvq':5091,
        'effective_bpw':len(image)*8/(128*1024),
        'magnitude_cells':256,'full_main_codebook_codes_checked':65536,
        'basis_dot_identities_checked':65536*8,
        'source_magnitude_classes':{str(k):v for k,v in sorted(Counter(tuple(sorted(abs(row))) for row in v).items())},
        'exception_masks':exceptional,
        'image_positions':{'subsets_up_to_four':sum(n for c,n in counts.items() if c<163),
                           'five_three_exception':sum(n for c,n in counts.items() if 163<=c<192),
                           'one_five_optional_three':sum(n for c,n in counts.items() if c>=192)},
        'entire_decoded_weight_array_equal':True,
        'native_or_speed_claim':False,
    }
    (HERE/'image.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
