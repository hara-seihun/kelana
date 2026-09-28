"""Score frozen images under the entire embedding-ID source law, without fitting."""
from pathlib import Path
import hashlib
import importlib.util
import json
import numpy as np

HERE=Path(__file__).resolve().parent
GRAM=Path('/path/to/workspace/data/kelana-subbit/isa-source-law/qwen3-0.6b-layer00-q-input/uniform-id-second-moment.npy')
READER=HERE.parent/'quip-full-row-slab/replay.py'
spec=importlib.util.spec_from_file_location('full_row_replay',READER)
reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)


def score(D,H):
    return float(np.sum(D*(D@H)))


def main():
    G=np.load(GRAM)
    assert G.shape==(1024,1024) and hashlib.sha256(GRAM.read_bytes()).hexdigest()=='48446e3398f37e867e0e79b6538252b3cf1cb155739fb7d737d5ec423393ad7d'
    with np.load(reader.FIX) as f:
        W=f['weight'][:128].astype(float)
        Xt=f['train'].astype(float)
        Xh=f['validation'].astype(float)
    Ht=Xt.T@Xt/len(Xt);Hh=Xh.T@Xh/len(Xh)
    eigen,U=np.linalg.eigh(Ht)
    assert (eigen>eigen[-1]*1e-10).sum()==896
    null=U[:,:128]
    source_eigen=np.linalg.eigvalsh(G)
    teacher={key:score(W,H) for key,H in [('train',Ht),('held',Hh),('uniform_id',G)]}
    result={'distribution':{'law':'each integer embedding ID in [0,151936) equally weighted once',
             'not_language_frequency':True,'producer':'BF16 embedding -> RMSNorm with observed capture-equivalent CPU reduction',
             'source_second_moment_file':str(GRAM),'source_second_moment_sha256':hashlib.sha256(GRAM.read_bytes()).hexdigest(),
             'source_rank':int((source_eigen>source_eigen[-1]*1e-10).sum()),
             'source_min_eigenvalue':float(source_eigen[0]),'source_max_eigenvalue':float(source_eigen[-1]),
             'source_energy_in_train_nullspace':float(np.trace(null.T@G@null)),
             'teacher_output_energy':teacher},'fixed_images':{}}
    for name,decode in (('quip_rvq3',reader.quip),('scalar_group128',reader.scalar)):
        Q,receipt=decode();D=Q-W
        result['fixed_images'][name]={'image_sha256':receipt['image_sha256'],
           'relative_squared_response_error':{key:score(D,H)/teacher[key] for key,H in [('train',Ht),('held',Hh),('uniform_id',G)]},
           'error_energy_per_source':{key:score(D,H) for key,H in [('train',Ht),('held',Hh),('uniform_id',G)]},
           'uniform_id_error_in_train_null_component':score(D@null,null.T@G@null)}
    (HERE/'source-results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
