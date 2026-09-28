#!/usr/bin/env python3
"""Recode the fixed upstream residual alphabet into an executable byte geometry."""
from pathlib import Path
import importlib.util
import hashlib
import json
import numpy as np
from replay import root_twice, root_dot, decode

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'quip-full-row-slab'


def main():
    source=(SOURCE/'quip-rvq3-standalone.bin').read_bytes()
    source_sha=hashlib.sha256(source).hexdigest()
    assert source_sha=='7234c67cc269f945b2826ad8686207336208ed531023ede0be7925c1c041ad43'
    original=np.frombuffer(source[50322:],dtype='<f2').astype(np.float64)*2
    assert np.array_equal(original,np.rint(original))
    original=original.astype(np.int8).reshape(256,8)
    generated=np.stack([root_twice(c) for c in range(256)])
    labels={tuple(row.tolist()):c for c,row in enumerate(generated)}
    assert len(labels)==256
    assert set(map(tuple,original.tolist()))==set(labels)
    permutation=np.array([labels[tuple(row.tolist())] for row in original],dtype=np.uint8)
    assert len(set(permutation.tolist()))==256
    # All standard basis vectors certify the real-linear dot identity, not samples.
    for code in range(256):
        assert np.array_equal(root_dot(code,np.eye(8)),generated[code]*.5)
    old_codes=np.frombuffer(source[32768:49152],dtype=np.uint8)
    codes=permutation[old_codes]
    output=source[:32768]+codes.tobytes()+source[49152:50322]
    assert len(output)==50322
    new_weight=decode(output)
    spec=importlib.util.spec_from_file_location('source_reader',SOURCE/'replay.py')
    reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)
    old_weight,_=reader.quip()
    assert np.array_equal(new_weight,old_weight)
    (HERE/'quip-root-standalone.bin').write_bytes(output)
    type_counts={'half_root':int((codes>=128).sum()),
                 'integer_root_or_axis':int(((codes<128)&(codes!=127)).sum()),
                 'zero':int((codes==127).sum())}
    result={'source_image_sha256':source_sha,
            'image_sha256':hashlib.sha256(output).hexdigest(),
            'bytes':len(output),'model_specific_bytes':49298,
            'once_paid_main_absolute_table_bytes':1024,'residual_table_bytes':0,
            'source_standalone_bytes':len(source),'saved_bytes':len(source)-len(output),
            'effective_bpw':len(output)*8/(128*1024),
            'complete_residual_alphabet_size':256,'bijection_checked':True,
            'basis_dot_identity_checks':256*8,
            'decoded_weight_bitwise_equal':True,'residual_position_types':type_counts}
    (HERE/'image.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
