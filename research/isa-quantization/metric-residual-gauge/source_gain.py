"""Pin and count the signed entries of the actual tied final RMSNorm gain."""
import hashlib
import json
from pathlib import Path
from safetensors import safe_open

MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
EXPECTED = 'f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b'


def main():
    digest = hashlib.sha256()
    with MODEL.open('rb') as file:
        for chunk in iter(lambda: file.read(4 * 1024 * 1024), b''):
            digest.update(chunk)
    assert digest.hexdigest() == EXPECTED
    with safe_open(MODEL, framework='pt', device='cpu') as file:
        gamma = file.get_tensor('model.norm.weight').float()
        assert tuple(gamma.shape) == (1024,)
        result = {
            'model_sha256': EXPECTED,
            'final_gain_positive': int((gamma > 0).sum()),
            'final_gain_negative': int((gamma < 0).sum()),
            'final_gain_zero': int((gamma == 0).sum()),
            'final_gain_minimum': float(gamma.min()),
            'final_gain_maximum': float(gamma.max()),
        }
    assert result['final_gain_positive'] + result['final_gain_negative'] == 1024
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
