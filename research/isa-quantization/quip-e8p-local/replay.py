"""Independent fixed-format E8P reader and same-state response evaluation."""
import hashlib
import json
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
ASSETS={
    'e8p-abs-grid.bin':'efc2c03c60acd955dc812ff2bade9ec6cc31259807e48473506161f3a9a230ce',
    'e81b-grid.bin':'d65cecfd0258df8b7aaabfe7ce66ac5b0ec9385274c60b83f3fe3714321337eb',
    'quip-e8p-r0.bin':'d90b8ce2e6f7c9fa8be15ca07e415b613f620baa05291b5297ee25dfdfae9931',
    'quip-e8p-r4.bin':'d4494145a82eeccb2bae2112a12f0292da3087cc9efb1097d82873ebee38335c',
    'quip-e8p-r5.bin':'ae85eaefd3e83a897429305ced08b0b4e66ed966a52ab0e6e644c64b39fd1e08',
    'quip-rvq3-r0.bin':'89e2e0b5b07fb749db77a7d94efbbdb9c34b83d7d111633401fdc92d315bc597',
    'refit-mixed-q2q3-6176.bin':'ce94af65a0e7666e64778e23e05dd1325353d474cf7c8a239988ca1f4723bc63',
    'refit-mixed-q3q4-6688.bin':'d50b25117f3545aaff2b3e66397e3cfd397f9f299f10adf71ced7b447c0cf881'}


def asset(name):
    data=(HERE/name).read_bytes()
    assert hashlib.sha256(data).hexdigest()==ASSETS[name],name
    return data


def hadamard(a):
    out=np.asarray(a,dtype=np.float64).copy().reshape(-1,128)
    width=1
    while width<128:
        for start in range(0,128,2*width):
            lhs=out[:,start:start+width].copy()
            rhs=out[:,start+width:start+2*width].copy()
            out[:,start:start+width]=lhs+rhs
            out[:,start+width:start+2*width]=lhs-rhs
        width*=2
    return out/np.sqrt(128)


def decode(rank):
    data=asset(f'quip-e8p-r{rank}.bin')
    assert len(data)==4130+512*rank
    code=np.frombuffer(data,dtype='<u2',count=2048).reshape(128,16)
    su=1-2*np.unpackbits(np.frombuffer(data[4096:4112],dtype=np.uint8),bitorder='little').astype(np.int16)
    sv=1-2*np.unpackbits(np.frombuffer(data[4112:4128],dtype=np.uint8),bitorder='little').astype(np.int16)
    scale=float(np.frombuffer(data[4128:4130],dtype='<f2')[0])
    assert np.isfinite(scale) and scale>0
    a=np.frombuffer(data[4130:4130+256*rank],dtype='<f2').astype(np.float64).reshape(128,rank)
    b=np.frombuffer(data[4130+256*rank:],dtype='<f2').astype(np.float64).reshape(rank,128)
    assert np.isfinite(a).all() and np.isfinite(b).all()
    ab=np.frombuffer(asset('e8p-abs-grid.bin'),dtype='<u4')
    assert len(ab)==256
    signs=(code&255).astype(np.uint32)
    parity=np.bitwise_xor.reduce(((signs[...,None]>>np.arange(8))&1).astype(np.uint8),axis=-1)
    signs=signs^parity
    packed=ab[code>>8]
    shuffle=[0,4,1,5,2,6,3,7]
    vals=np.stack([((packed>>(4*i))&15).astype(np.float64) for i in shuffle],axis=-1)
    vals=(vals-8)*.5
    vals*=1-2*((signs[...,None]>>np.array(shuffle))&1).astype(np.int16)
    vals+=(1-2*parity.astype(np.int16))[...,None]*.25
    q=vals.reshape(128,128)*scale+a@b
    reconstructed=(hadamard((hadamard(q)*su).T)*sv).T
    return reconstructed,{'image_sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'codes':4096,'su_sv_signs':32,'global_fp16_scale':2,'fp16_lowrank':512*rank,'rank':rank,'generic_e8_abs_table_bytes':1024,'full_grid_preparation_bytes_fp32':65536*8*4}


def decode_rvq3():
    data=asset('quip-rvq3-r0.bin')
    assert len(data)==6178
    code=np.frombuffer(data,dtype='<u2',count=2048).reshape(128,16)
    residual=np.frombuffer(data,dtype='u1',count=2048,offset=4096).reshape(128,16)
    su=1-2*np.unpackbits(np.frombuffer(data[6144:6160],dtype='u1'),bitorder='little').astype(np.int16)
    sv=1-2*np.unpackbits(np.frombuffer(data[6160:6176],dtype='u1'),bitorder='little').astype(np.int16)
    scale=float(np.frombuffer(data[6176:6178],dtype='<f2')[0]);assert scale>0 and np.isfinite(scale)
    ab=np.frombuffer(asset('e8p-abs-grid.bin'),dtype='<u4')
    assert len(ab)==256
    sign=(code&255).astype(np.uint32)
    parity=np.bitwise_xor.reduce(((sign[...,None]>>np.arange(8))&1).astype(np.uint8),axis=-1)
    sign=sign^parity
    packed=ab[code>>8]
    perm=[0,4,1,5,2,6,3,7]
    val=np.stack([((packed>>(4*i))&15).astype(np.float64) for i in perm],axis=-1)
    val=(val-8)*.5*(1-2*((sign[...,None]>>np.array(perm))&1).astype(np.int16))
    val+=(1-2*parity.astype(np.int16))[...,None]*.25
    grid=np.frombuffer(asset('e81b-grid.bin'),dtype='<f2').astype(np.float64).reshape(256,8)
    assert np.isfinite(grid).all()
    q=(val+grid[residual]/2.04).reshape(128,128)*scale
    w=(hadamard((hadamard(q)*su).T)*sv).T
    return w,{'image_sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'e8p_codes':4096,'e81b_residual_codes':2048,'su_sv_signs':32,'global_fp16_scale':2,'generic_e8_abs_table_bytes':1024,'generic_e81b_grid_bytes':4096,'rank':0}


def scalar_image(size,base_bits,upgrade_bits,upgrades):
    data=asset(f'refit-mixed-q{base_bits}q{upgrade_bits}-{size}.bin');assert len(data)==size
    mask=data[:16];offset=16;rows=[]
    for row in range(128):
        bits=upgrade_bits if mask[row//8]&(1<<(row%8)) else base_bits
        payload=data[offset:offset+(128*bits)//8];offset+=128*bits//8
        digit=np.array([(payload[(i*bits)//8]>>((i*bits)%8) | (payload[(i*bits)//8+1]<<(8-(i*bits)%8) if (i*bits)%8+bits>8 else 0)) & ((1<<bits)-1) for i in range(128)],dtype=float)
        scale,origin=np.frombuffer(data[offset:offset+4],dtype='<f2').astype(float);offset+=4
        assert np.isfinite(scale) and np.isfinite(origin)
        rows.append(digit*scale+origin)
    assert offset==len(data) and sum(int(v).bit_count() for v in mask)==upgrades
    return np.stack(rows),{'image_sha256':hashlib.sha256(data).hexdigest(),'bytes':size,'codes':size-528,'fp16_row_grids':512,'row_mask':16,'upgraded_rows':upgrades}


def main():
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    with np.load(FIX) as f:
        w=f['weight'][:128,:128].astype(np.float64)
        panels={'train':f['train'][:,:128].astype(np.float64),'held':f['validation'][:,:128].astype(np.float64)}
    baselines=scalar_image(6688,3,4,1)
    baseline6176=scalar_image(6176,2,3,97)
    outputs={}
    for name,candidate in [('quip_e8p_rank0',decode(0)),('quip_e8p_rank4',decode(4)),('quip_e8p_rank5',decode(5)),('quip_rvq3_rank0',decode_rvq3()),('refit_scalar_6688',baselines),('refit_scalar_6176',baseline6176)]:
        qw,ledger=candidate
        error={label:float(np.linalg.norm(x@(qw-w).T)**2/np.linalg.norm(x@w.T)**2) for label,x in panels.items()}
        outputs[name]={**ledger,'relative_squared_response_error':error}
    (HERE/'results.json').write_text(json.dumps(outputs,indent=2)+'\n')
    print(json.dumps(outputs,indent=2))


if __name__=='__main__':main()
