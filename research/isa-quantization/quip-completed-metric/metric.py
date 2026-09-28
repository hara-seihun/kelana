"""Parameter-free source-conditional completion of empirical train covariance."""
from pathlib import Path
import hashlib
import json
import numpy as np

HERE=Path(__file__).resolve().parent
DATA=Path('/path/to/workspace/data/kelana-subbit/isa-source-law/qwen3-0.6b-layer00-q-input')
G_FILE=DATA/'uniform-id-second-moment.npy'
M_FILE=DATA/'conditional-completed-train-metric.npy'
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')


def main():
    assert hashlib.sha256(G_FILE.read_bytes()).hexdigest()=='48446e3398f37e867e0e79b6538252b3cf1cb155739fb7d737d5ec423393ad7d'
    G=np.load(G_FILE)
    with np.load(FIX) as f:x=f['train'].astype(float)
    H=x.T@x/len(x)
    values,U=np.linalg.eigh(H)
    assert np.count_nonzero(values>values[-1]*1e-10)==896
    R=U[:,128:];HR=values[128:];GR=R.T@G@R
    # Conditional cross-map G P (P G P)^+ in coordinates of R.
    V=np.linalg.solve(GR,(G@R).T).T
    M=G+((V*HR)@V.T)-(V@GR)@V.T
    M=(M+M.T)*.5
    supported=R.T@M@R
    residual=supported-np.diag(HR)
    assert np.max(np.abs(residual))<1e-10
    assert np.linalg.cholesky(M).shape==(1024,1024)
    np.save(M_FILE,M)
    rec={'source_G_sha256':hashlib.sha256(G_FILE.read_bytes()).hexdigest(),
         'fixture_sha256':hashlib.sha256(FIX.read_bytes()).hexdigest(),
         'rank':896,'nullity':128,'completion':'G+GP(PGP)^+(H-PGP)(PGP)^+PG',
         'supported_block_max_abs_difference':float(np.max(np.abs(residual))),
         'completed_trace':float(np.trace(M)),
         'completed_image_sha256':hashlib.sha256(M_FILE.read_bytes()).hexdigest()}
    (HERE/'metric.json').write_text(json.dumps(rec,indent=2)+'\n');print(json.dumps(rec,indent=2))

if __name__=='__main__':main()
