"""No fitting: separability minors of Q RMSNorm's exact ideal-real response."""
from pathlib import Path
import hashlib
import json
import numpy as np
from safetensors import safe_open

HERE=Path(__file__).resolve().parent
FIX=Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
MODEL=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
EPS=1e-6
AMP=1/64


def norm(z,gamma):
    s=np.mean(z*z,axis=-1,keepdims=True)+EPS
    return gamma*z/np.sqrt(s)


def data(x,w,gamma):
    d=len(gamma);z=x@w.T
    s=np.mean(z*z,axis=-1)+EPS
    gz2=np.sum((gamma*z)**2,axis=-1)
    directions=np.stack((w[0]/np.linalg.norm(w[0]),w[1]/np.linalg.norm(w[1])))
    overlap=x@directions.T
    infinitesimal=np.empty((2,2))
    finite=np.empty((2,2))
    reference=norm(z,gamma)
    for row,p in enumerate((0,1)):
        zp=z[:,p];gp=gamma[p]
        # Squared Euclidean norm of Jacobian column p; gamma stays after norm.
        jacdiag=(gp*gp*(1-2*zp*zp/(d*s))+zp*zp*gz2/(d*d*s*s))/s
        for col in range(2):
            infinitesimal[row,col]=np.mean(overlap[:,col]**2*jacdiag)
            candidate=z.copy()
            candidate[:,p]+=AMP*overlap[:,col]
            finite[row,col]=np.mean(np.sum((norm(candidate,gamma)-reference)**2,axis=1))
    singular=np.linalg.svd(infinitesimal,compute_uv=False)
    f_singular=np.linalg.svd(finite,compute_uv=False)
    return {'source_positions':len(x),'probe_output_coordinates':[0,1],
            'probe_input_directions':'unit vectors parallel to teacher q_proj rows 0 and 1',
            'probe_teacher_row_cosine':float(directions[0]@directions[1]),
            'epsilon':EPS,'amplitude':AMP,
            'jacobian_rankone_quadratic_matrix':infinitesimal.tolist(),
            'jacobian_minor':float(np.linalg.det(infinitesimal)),
            'jacobian_rank_two_singular_ratio':float(singular[1]/singular[0]),
            'finite_normalized_response_matrix':finite.tolist(),
            'finite_minor':float(np.linalg.det(finite)),
            'finite_rank_two_singular_ratio':float(f_singular[1]/f_singular[0])}


def main():
    assert hashlib.sha256(FIX.read_bytes()).hexdigest()=='389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f'
    with np.load(FIX) as f:
        w=f['weight'][:128].astype(float)
        train=f['train'].astype(float);held=f['validation'].astype(float)
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        gamma=f.get_tensor('model.layers.0.self_attn.q_norm.weight').float().numpy()[:128].astype(float)
    assert w.shape==(128,1024) and gamma.shape==(128,)
    result={'source_fixture_sha256':hashlib.sha256(FIX.read_bytes()).hexdigest(),
            'model_safetensors_sha256':'f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b',
            'gamma_first_two':gamma[:2].tolist(),
            'train':data(train,w,gamma),'inspected_held':data(held,w,gamma)}
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
