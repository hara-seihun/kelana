"""Finite CPU label and whole-dot checks; does not launch or time the GPU."""
import hashlib
import importlib.util
from pathlib import Path
import subprocess
import sys
import numpy as np

here=Path(__file__).resolve().parent
study=here.parent
source=Path(sys.argv[1]) if len(sys.argv)>1 else study/'e8-main-program'
image=source/'quip-combinatorial-standalone.bin'
prepared=here/'emit/prepared.bin'
prepared.parent.mkdir(exist_ok=True)
subprocess.run(['g++','-O3','-std=c++17',str(here/'check_labels.cpp'),'-o',str(here/'emit/check_labels')],check=True)
subprocess.run([str(here/'emit/check_labels'),str(image),str(prepared)],check=True)
spec=importlib.util.spec_from_file_location('parent_main',source/'replay.py')
# Parent replay.py imports its sibling root replay.py by an absolute path.
parent=importlib.util.module_from_spec(spec);spec.loader.exec_module(parent)
data=image.read_bytes();assert len(data)==49327
exception=data[49298:]
words=np.frombuffer(prepared.read_bytes(),dtype='<u4');assert len(words)==256
for c in range(256):
    expected=parent.magnitudes(c,exception)
    actual=((words[c]>>(4*np.arange(8,dtype=np.uint32)))&15).astype(np.int16)-8
    assert np.array_equal(actual,expected),(c,actual,expected)
# Exact real-arithmetic coefficient contract, including all signs, parity and slot-7 correction.
z=np.array([.125,-.375,.625,-.875,1.125,-1.375,1.625,-1.875],dtype=np.float64)
for high in range(256):
    threes,fives=parent.masks(high,exception)
    for low in (0,1,2,3,63,64,127,128,129,254,255):
        code=high*256+low;sign=low^(low.bit_count()&1)
        ordered=z[parent.INVERSE]
        terms=np.array([(-1 if sign>>i&1 else 1)*ordered[i] for i in range(8)])
        main=.5*sum(terms)+(1-2*(low.bit_count()&1))*.25*sum(ordered)
        main+=sum(terms[i] for i in range(8) if threes>>i&1)
        main+=2*sum(terms[i] for i in range(8) if fives>>i&1)
        if threes.bit_count()&1:main-=(1+2*(threes>>7&1)+4*(fives>>7&1))*terms[7]
        expected=float(np.dot(parent.main_four(code,exception)/4,z))
        assert abs(main-expected)<1e-12,(code,main,expected)
print('image_sha256='+hashlib.sha256(data).hexdigest(),'labels=256 exact','main_dots=2816 exact')
