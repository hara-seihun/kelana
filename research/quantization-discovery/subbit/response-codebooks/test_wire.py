#!/usr/bin/env python3
"""Independent dense response against the packed-label table consumer."""
import unittest
import numpy as np
import wire


class WireContract(unittest.TestCase):
    def test_all_key_widths_and_tail_alignment(self):
        rng=np.random.default_rng(9007)
        for bits in (1,2,4,6,8):
            for segments in (1,3,8,16,17):
                labels=rng.integers(0,1<<bits,size=(33,segments),dtype=np.uint8)
                packet=wire.pack_labels(labels,bits)
                self.assertEqual(packet.shape,(33,(bits*segments+7)//8))
                np.testing.assert_array_equal(wire.unpack_labels(packet,segments,bits),labels)
                packet[0,0]^=1
                self.assertFalse(np.array_equal(wire.unpack_labels(packet,segments,bits),labels))

    def test_table_and_exception_response(self):
        rng=np.random.default_rng(1278)
        for length,k in ((8,64),(16,256)):
            cols=384; rows=37; tokens=7
            codes=rng.integers(-40,41,size=(k,length),dtype=np.int8)
            labels=rng.integers(0,k,size=(rows,cols//length),dtype=np.uint8)
            packet=wire.pack_labels(labels,int(np.log2(k)))
            blocks=cols//128
            scales=rng.uniform(.002,.05,size=(rows,blocks)).astype(np.float16).astype(np.float32)
            query=rng.standard_normal((tokens,cols),dtype=np.float32)
            dense=(codes[labels].reshape(rows,cols).astype(np.float64)/64 *
                   np.repeat(scales,128,axis=1))
            idx=rng.integers(0,128,size=(rows,blocks,1),dtype=np.uint8)
            values=rng.uniform(-.1,.1,size=(rows,blocks,1)).astype(np.float16)
            for block in range(blocks):
                dense[np.arange(rows),block*128+idx[:,block,0].astype(np.int32)]+=values[:,block,0]
            bias=rng.uniform(-.2,.2,size=rows).astype(np.float16)
            direct=query.astype(np.float64)@dense.T+bias[None,:]
            got=wire.observe(packet,codes,1/64,scales,query,exceptions=(idx,values),bias=bias)
            np.testing.assert_allclose(got,direct,rtol=1.e-5,atol=2.e-5)


if __name__=='__main__':
    unittest.main()
