"""Fixed data-independent TurboQuant sphere quantizer and three paid FP32 matrices."""
import hashlib,json
from pathlib import Path
import numpy as np
from scipy.special import betainc,gammaln
HERE=Path(__file__).resolve().parent
D=128;SEED=20260924

def centroid():
 # Exact spherical-coordinate law C*(1-x²)^((d-3)/2), symmetric 4-level Lloyd.
 beta=(D-1)/2
 C=np.exp(gammaln(D/2)-.5*np.log(np.pi)-gammaln((D-1)/2))
 t=.08
 for _ in range(10000):
  middle=.5*betainc(.5,beta,t*t)
  outer=.5-middle
  numerator_inner=C*(-np.expm1(beta*np.log1p(-t*t)))/(D-1)
  numerator_outer=C*np.exp(beta*np.log1p(-t*t))/(D-1)
  a=numerator_inner/middle;b=numerator_outer/outer
  next_t=(a+b)/2
  if abs(next_t-t)<1e-15:break
  t=next_t
 assert 0<a<t<b<1
 return np.asarray([-b,-a,a,b],dtype='<f4'),{'iterations':_+1,'positive_threshold':float(t),'inner':float(a),'outer':float(b)}

def rotation(rng):
 # Sign correction makes QR(G) Haar rather than QR implementation-dependent.
 g=rng.standard_normal((D,D));q,r=np.linalg.qr(g)
 return (q*np.where(np.diag(r)<0,-1.,1.)[None,:]).astype('<f4')

def run():
 rng=np.random.default_rng(SEED)
 k=rotation(rng);v=rotation(rng);s=rng.standard_normal((D,D)).astype('<f4')
 c,receipt=centroid()
 assets=np.concatenate([k.ravel(),v.ravel(),s.ravel(),c]).astype('<f4')
 blob=assets.tobytes();assert len(blob)==196624
 (HERE/'program.fp32').write_bytes(blob)
 r={'paper':'https://arxiv.org/html/2504.19874v1#S3','seed':SEED,'rng':'NumPy PCG64 default_rng','matrix_dtype':'little-endian FP32 row-major',
 'rotation':'independent Gaussian QR with sign-diagonal R correction, realized in FP64 then stored FP32','S':'independent iid N(0,1), stored FP32',
 'codebook':'exact d128 spherical-coordinate beta density symmetric 4-centroid Lloyd (data independent), stored FP32',
 'centroid_solve':receipt,'codebook_values':c.tolist(),'sha256':hashlib.sha256(blob).hexdigest(),
 'K_rotation_bytes':65536,'V_rotation_bytes':65536,'QJL_gaussian_bytes':65536,'centroids_bytes':16,'total_program_bytes':len(blob)}
 (HERE/'program.json').write_text(json.dumps(r,indent=2)+'\n')
 print(json.dumps(r,indent=2))
if __name__=='__main__':run()
