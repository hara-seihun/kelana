"""Parse four stored images independently; score exact decoded producer responses."""
import hashlib
import json
from fractions import Fraction
from importlib.util import spec_from_file_location, module_from_spec
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
IMAGE_HASHES={
    'mixed-q3q4-6848.bin':'b857ea990696a431277d8931544ef03622628974dfa0a32e9623e3457b509683',
    'mixed-q3q4-7104.bin':'0cdfebebfbc8577f7d16f7dd7dd15c789d21bea66197830bf00b4f3c3e4ebb7b',
    'weighted-pair-6848.bin':'1637268ea9b4e25dfac3c3dbbe40b8e8fa47876e3ba6e06cff7b0e68e6ccf936',
    'affine-pair-7104.bin':'80503e2ee30bdd40ed70067f4af1081e35821a7742ba6505b65d4214ff1f365f',
    'refit-mixed-q3q4-6848.bin':'d28b7af6a8ac7b6cd8158143ad27cbe466c07e442c8a83d566976956b2185c2c',
    'refit-mixed-q3q4-7104.bin':'cd0c170b55b920b849669e02022ae7e0657ef184a18750d0a6d2853268090b31',
    'refit-weighted-pair-6848.bin':'257292284ab21964e1ac5830aad3435192fa545be53a3c73623bde467f288663',
    'refit-affine-pair-7104.bin':'edc7fc71208f06ccd50fd02e2721114cd87ceec4490facbb480dd58c00fd3303',
}


def image_bytes(name):
    payload=(HERE/name).read_bytes()
    assert hashlib.sha256(payload).hexdigest()==IMAGE_HASHES[name],name
    return payload


def unpack(raw,width,count):
    assert len(raw)==(width*count+7)//8
    stream=int.from_bytes(raw,'little')
    return np.asarray([(stream>>(width*k))&((1<<width)-1) for k in range(count)],dtype=np.uint8)


def rows(payload,widths,columns):
    rows=[];offset=0
    for bits in widths:
        length=(bits*columns+7)//8
        code=unpack(payload[offset:offset+length],bits,columns);offset+=length
        scale,origin=np.frombuffer(payload[offset:offset+4],dtype='<f2').astype(float);offset+=4
        assert np.isfinite(scale) and scale>0 and np.isfinite(origin)
        rows.append(code.astype(float)*scale+origin)
    assert offset==len(payload)
    return np.asarray(rows)


def control(data,budget):
    assert len(data)==budget
    mask=int.from_bytes(data[:16],'little')
    upgraded=[k for k in range(128) if (mask>>k)&1]
    assert len(upgraded)==(budget-6672)//16
    return rows(data[16:],[4 if k in upgraded else 3 for k in range(128)],128),upgraded


def pair(data,affine):
    assert len(data)==(7104 if affine else 6848)
    pairs=np.frombuffer(data[:64],dtype=np.uint8).reshape(32,2)
    singles=np.frombuffer(data[64:128],dtype=np.uint8)
    assert len(np.unique(np.r_[pairs.flatten(),singles]))==128
    ratios=np.frombuffer(data[128:192],dtype='<f2').astype(float)
    assert np.all(np.isfinite(ratios))
    output=rows(data[192:192+6656],[4]*128,96)
    intercept=np.frombuffer(data[6848:],dtype='<f2').astype(float) if affine else np.zeros(128)
    assert intercept.shape==(128,) and np.all(np.isfinite(intercept))
    t=np.zeros((128,96))
    for k,((i,j),r) in enumerate(zip(pairs,ratios)):
        t[i,k]=1;t[j,k]=r
    for k,i in enumerate(singles,32):t[i,k]=1
    return t,output,intercept


def score(pred,target):return float(np.sum((pred-target)**2)/np.sum(target**2))


def certified_affine_comparison(x,w,decoded):
    owner=HERE.parent/'input-programs/verify_diagonal.py'
    spec=spec_from_file_location('input_program_integer_gram',owner)
    module=module_from_spec(spec);spec.loader.exec_module(module)
    assert np.array_equal(x*2**27,np.rint(x*2**27))
    assert np.array_equal(w*2**28,np.rint(w*2**28))
    assert np.array_equal(decoded*2**28,np.rint(decoded*2**28))
    xs=np.rint(x*2**27);ws=np.rint(w*2**28);qs=np.rint(decoded*2**28)
    limit=np.iinfo(np.int64).max
    assert all(np.max(np.abs(a))<limit for a in (xs,ws,qs))
    h=module.exact_gram(xs.astype('int64'))
    wi=ws.astype('int64').astype(object)
    error=wi-qs.astype('int64').astype(object)
    numerator=int(np.sum((error.T@error)*h))
    denominator=int(np.sum((wi.T@wi)*h))
    actual=Fraction(numerator,denominator)
    study='affine-pair-covariance'
    source=HERE.parent/study/'verified.json'
    receipt=json.loads(source.read_text())
    cert=HERE.parent/study/'spectral-certificate.npz'
    assert hashlib.sha256(cert.read_bytes()).hexdigest()==receipt['certificate_sha256']
    floor=Fraction(int(receipt['universal_floor_numerator']),int(receipt['universal_floor_denominator']))
    gap=floor-actual
    assert gap>0
    return {'control_train_numerator':str(actual.numerator),
            'control_train_denominator':str(actual.denominator),
            'universal_pair_floor_receipt_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
            'floor_minus_control':float(gap),
            'floor_strictly_above_control':gap>0,
            'source_certificate_sha256':receipt['certificate_sha256']}


def main():
    with np.load(FIX) as f:
        x=f['train'][:,:128].astype(float);held=f['validation'][:,:128].astype(float)
        w=f['weight'][:128,:128].astype(float)
    y=x@w.T;yh=held@w.T
    result={'fixture_sha256':hashlib.sha256(FIX.read_bytes()).hexdigest(),
            'selected_pair_source_sha256':hashlib.sha256((HERE.parent/'weighted-input-pairs/results.json').read_bytes()).hexdigest(),
            'source_shape':[128,128],'train_rows':len(x),'held_rows':len(held),
            'denominator':'original uncentered teacher response energy per split',
            'strong_full_model_method_source':'research/quantization-discovery/q4-diagnostic/calibrated.py',
            'images':{}}
    for budget in (6848,7104):
        for refined in (False,True):
            prefix='refit-' if refined else ''
            name=f'{prefix}mixed-q3q4-{budget}.bin';image=image_bytes(name)
            decoded,upgraded=control(image,budget)
            result['images'][name]={'sha256':hashlib.sha256(image).hexdigest(),'payload_bytes':len(image),
                    'code_bytes':6144+16*len(upgraded),'metadata_mask_bytes':16,
                    'fp16_scale_bytes':256,'fp16_origin_bytes':256,'four_bit_rows':upgraded,
                    'method':'local full-covariance damped GPTQ-style sequential compensation; '
                             +('fixed-code full-response FP16 grid refit; ' if refined else '')+'no SOTA claim',
                    'train_error':score(x@decoded.T,y),'held_error':score(held@decoded.T,yh)}
            if refined and budget==7104:
                result['images'][name]['exact_train_certificate_comparison']=certified_affine_comparison(x,w,decoded)
            affine=budget==7104
            name=prefix+('affine-pair-7104.bin' if affine else 'weighted-pair-6848.bin')
            image=image_bytes(name);t,a,b=pair(image,affine)
            z=x@t;zh=held@t
            mean_z=z.mean(axis=0) if affine else np.zeros(96)
            mean_y=y.mean(axis=0) if affine else np.zeros(128)
            free=np.linalg.lstsq(z-mean_z,y-mean_y,rcond=None)[0]
            floor=score((z-mean_z)@free+mean_y,y)
            result['images'][name]={'sha256':hashlib.sha256(image).hexdigest(),'payload_bytes':len(image),
                    'output_code_bytes':6144,'fp16_output_scale_bytes':256,
                    'fp16_output_origin_bytes':256,'pair_index_bytes':64,'singleton_index_bytes':64,
                    'fp16_ratio_bytes':64,'fp16_intercept_bytes':256 if affine else 0,
                    'method':'prior diagonal-cost greedy 32-pair selection; local GPTQ-style Q4 output fit'
                             +('; fixed-code full-response FP16 grid refit' if refined else ''),
                    'selected_pair_free_real_train_floor':floor,
                    'train_error':score(z@a.T+b,y),'held_error':score(zh@a.T+b,yh)}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({name:{key:value for key,value in entry.items() if key in ('payload_bytes','train_error','held_error','selected_pair_free_real_train_floor')}
           for name,entry in result['images'].items()},indent=2))

if __name__=='__main__':main()
