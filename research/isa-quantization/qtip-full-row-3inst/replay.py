"""Standalone image assembler and independent bitstream/state/response reader."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')

def had(a):
    a=np.asarray(a,dtype=np.float64).copy(); n=a.shape[-1]
    for width in (2**i for i in range(n.bit_length()-1)):
        v=a.reshape(-1,n//(2*width),2,width)
        x=v[:,:,0,:].copy();y=v[:,:,1,:].copy()
        v[:,:,0,:]=x+y;v[:,:,1,:]=x-y
    return a/np.sqrt(n)

def scalar_state(s):
    a=89226354;b=64248484;mask=0x8fff8fff;fpmask=996162400
    v=((int(s)*a+b)&mask)^fpmask
    h=np.array([v>>16,v&65535],dtype=np.uint16).view(np.float16)
    return float(np.float16(h[0]+h[1]))

def kernel_permute(j):
    e=j%2;d=(j//2)%2;c=(j//4)%2;b=(j//8)%4;a=(j//32)%8
    return ((((d*8+a)*2+c)*4+b)*2+e)

def decoded_image(image,arm='3inst'):
    assert len(image)==(53394 if arm=='hyb' else 49298)
    tlut=np.frombuffer(image,dtype='<f4',count=1024,offset=49298).reshape(512,2) if arm=='hyb' else None
    q=np.zeros((128,1024),dtype=np.float64)
    for gr in range(8):
        for k in range(64):
            packed=np.frombuffer(image,dtype=np.uint8,count=96,offset=(gr*64+k)*96)
            bits=np.unpackbits(packed,bitorder='big')
            step=6 if arm=='hyb' else 3
            full=np.r_[bits,bits[:16-step]]
            state=int(''.join(map(str,full[:16])),2)
            states=[state]
            for t in range(1,256//(2 if arm=='hyb' else 1)):
                digit=int(''.join(map(str,full[16+(t-1)*step:16+t*step])),2)
                state=((state<<step)&65535)|digit
                states.append(state)
            assert (states[-1]&((1<<(16-step))-1))==(states[0]>>step)
            for j,s in enumerate(states):
                if arm=='hyb':
                    n=(s+1)*s;ix=(n>>6)&511;sign=1-2*((n>>15)&1)
                    values=(sign*float(tlut[ix,0]),float(tlut[ix,1]))
                    for v,value in enumerate(values):
                        at=kernel_permute(2*j+v)
                        q[gr*16+at//16,k*16+at%16]=value
                else:
                    q[gr*16+j//16,k*16+j%16]=scalar_state(s)
    su=np.where(np.unpackbits(np.frombuffer(image[49152:49280],dtype=np.uint8),bitorder='little')!=0,-1.,1.)
    sv=np.where(np.unpackbits(np.frombuffer(image[49280:49296],dtype=np.uint8),bitorder='little')!=0,-1.,1.)
    scale=float(np.frombuffer(image[49296:49298],dtype='<f2')[0])
    assert scale>0 and np.isfinite(scale)
    w=had((had(q)*su).T).T*sv[:,None]*scale
    return w

def main():
    p=argparse.ArgumentParser();p.add_argument('--arm',choices=['3inst','hyb'],default='3inst');p.add_argument('--assemble',action='store_true');a=p.parse_args()
    path=HERE/f'qtip-{a.arm}-full-row.bin'
    if a.assemble:
        prepared=HERE/('prepared-hyb' if a.arm=='hyb' else 'prepared')
        with np.load(prepared/'meta.npz') as meta:
            su=meta['su'];sv=meta['sv'];scale=meta['scale']
        payload=b''.join((prepared/f'group-{g}.bin').read_bytes() for g in range(8))
        assert len(payload)==49152
        image=payload+np.packbits(su<0,bitorder='little').tobytes()+np.packbits(sv<0,bitorder='little').tobytes()+np.array([scale],dtype='<f2').tobytes()
        if a.arm=='hyb':image+=(HERE/'hyb-tlut-f32.bin').read_bytes()
        path.write_bytes(image)
    image=path.read_bytes()
    assert len(image)==(53394 if a.arm=='hyb' else 49298)
    w=decoded_image(image,a.arm)
    with np.load(FIX) as f:
        target=f['weight'][:128].astype(np.float64)
        panels={'train':f['train'].astype(np.float64),'held':f['validation'].astype(np.float64)}
    metrics={name:float(np.sum((x@(w-target).T)**2)/np.sum((x@target.T)**2)) for name,x in panels.items()}
    receipt={'upstream':'Cornell-RelaxML/qtip e90c6688c8dfae326a3a81b5eb032db7c6680ec0','fixture_sha256':hashlib.sha256(FIX.read_bytes()).hexdigest(),'image_sha256':hashlib.sha256(image).hexdigest(),'arm':a.arm,'bytes':len(image),'fields':{'tile_codes':49152,'input_signs':128,'output_signs':16,'scale_fp16':2,'shared_lookup_fp32_once':4096 if a.arm=='hyb' else 0},'metric':metrics,'scale_stored':float(np.frombuffer(image[49296:49298],dtype='<f2')[0])}
    (HERE/f'results-{a.arm}.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt,indent=2))
if __name__=='__main__':main()
