"""Source-only pinching at the actual first-Q-head row space; no quantizer fit."""
import hashlib
import json
import os
from pathlib import Path

os.environ.setdefault('OPENBLAS_NUM_THREADS', '1')
os.environ.setdefault('OMP_NUM_THREADS', '1')
import numpy as np
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
SHA = 'f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b'


def main():
    with MODEL.open('rb') as f:
        assert hashlib.file_digest(f, 'sha256').hexdigest() == SHA
    with safe_open(MODEL, framework='pt', device='cpu') as f:
        w = f.get_tensor('model.layers.0.self_attn.q_proj.weight')[:128].float().numpy().astype(np.float64)
        incoming = f.get_tensor('model.layers.0.input_layernorm.weight').float().numpy().astype(np.float64)
        gain = f.get_tensor('model.norm.weight').float().numpy().astype(np.float64)
        a = w * incoming
        u, singular, _ = np.linalg.svd(a.T, full_matrices=False)
        assert singular[-1] > 1e-8 and u.shape == (1024, 128)
        compressed_gain = u.T @ (gain[:, None] * u)
        c = gain[:, None] * u - u @ compressed_gain
        delta = c @ u.T + u @ c.T
        pinched = np.diag(gain) - delta
        p = u @ u.T
        cg = c.T @ c
        sigma = np.linalg.eigvalsh(cg)
        max_row_energy = 0.0
        max_id = -1
        sum_row_energy = 0.0
        row_count = 0
        # Each vocabulary slice is processed without a dense vocabulary-by-delta image.
        embedding = f.get_slice('model.embed_tokens.weight')
        for start in range(0, 151936, 8192):
            e = embedding[start:start + 8192].float().numpy().astype(np.float64)
            eu, ec = e @ u, e @ c
            energies = np.sum(ec * ec, axis=1) + np.sum((eu @ cg) * eu, axis=1)
            i = int(np.argmax(energies))
            if energies[i] > max_row_energy:
                max_row_energy, max_id = float(energies[i]), start + i
            sum_row_energy += float(energies.sum())
            row_count += len(e)
    full_error = float(np.sum(delta * delta))
    off_error = float(2 * np.sum(c * c))
    result = {
        'model_sha256': SHA,
        'scope': 'fixed source first-head gamma-folded row space; ideal real orthogonal gauge; no quantization or final-state capture',
        'dimension': 1024, 'head_rank_numeric': 128,
        'folded_head_smallest_singular_value': float(singular[-1]),
        'orthonormal_max_error': float(np.max(np.abs(u.T @ u - np.eye(128)))),
        'head_outside_subspace_relative_squared': float(np.sum((a - (a @ u) @ u.T)**2) / np.sum(a*a)),
        'support_cross_max_error': float(np.max(np.abs(u.T @ c))),
        'commutator_max_error': float(np.max(np.abs(p @ pinched - pinched @ p))),
        'pinching_identity_absolute_error': abs(full_error - off_error),
        'optimal_gain_frobenius_squared': off_error,
        'gain_frobenius_relative_squared': off_error / float(gain @ gain),
        'gain_spectral_error': float(np.sqrt(max(0, sigma[-1]))),
        'minimum_original_gain': float(np.min(gain)),
        'pinched_minimum_eigenvalue_numeric': float(np.linalg.eigvalsh(pinched)[0]),
        'all_vocab_rows': row_count,
        'max_embedding_boundary_row_squared': max_row_energy,
        'max_embedding_boundary_row_token_id': max_id,
        'mean_embedding_boundary_row_squared': sum_row_energy / row_count,
        'uniform_all_state_kl_upper_using_row_radius': 1024 * max_row_energy / 2,
        'boundary_delta_rank_upper': 256,
        'hypothetical_q4_head_code_and_grid_saving_bytes': 60928,
        'new_quantized_image': False,
        'full_model_quality_measured': False,
    }
    (HERE / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
