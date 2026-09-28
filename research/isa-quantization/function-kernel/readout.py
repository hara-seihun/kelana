#!/usr/bin/env python3
"""No-trace-fitted Gaussian-law response-bank readout, scored on complete held MLP."""
import json
from pathlib import Path
import numpy as np
from safetensors import safe_open
from kernel import HERE, MODEL, hidden

PARENT=HERE.parent/'nonlinear-response-bank'
K=128


def panel(split):
    return np.concatenate([np.load(PARENT/f'{split}-{i}.npz')['target'] for i in range(4)]).astype(np.float64)


def main():
    h_train=hidden('train')
    h_held=hidden('held')
    train=panel('train')
    held=panel('held')
    with safe_open(MODEL,framework='pt',device='cpu') as f:
        down=f.get_tensor('model.layers.0.mlp.down_proj.weight').float().numpy().astype(np.float64)
    score=np.linalg.norm(h_train-h_train.mean(0),axis=0)*np.linalg.norm(down,axis=0)
    selected=np.argsort(-score,kind='stable')[:K]
    gram=np.concatenate([np.load(HERE/f'kernel-{K}-{j}.npy') for j in range(12)],axis=1)
    mean=np.load(HERE/'model-mean.npy')
    bank=gram[:,selected]
    bank=(bank+bank.T)/2
    eigen=np.linalg.eigvalsh(bank)
    lam=0.01*np.trace(bank)/K
    weights=np.linalg.solve(bank+lam*np.eye(K),gram@down.T)
    bias=down@mean-mean[selected]@weights
    fp16_weights=weights.astype(np.float16).astype(np.float64)
    fp16_bias=bias.astype(np.float16).astype(np.float64)
    assert np.isfinite(fp16_weights).all() and np.isfinite(fp16_bias).all()
    prediction=h_held[:,selected]@fp16_weights+fp16_bias
    prediction_train=h_train[:,selected]@fp16_weights+fp16_bias
    relative=lambda e,y:float(np.linalg.norm(e)/np.linalg.norm(y))
    weighted_response=gram@down.T
    actual_held_cross=(h_held[:,selected]-h_held[:,selected].mean(0)).T@(
        held-held.mean(0))/len(held)
    actual_train_cross=(h_train[:,selected]-h_train[:,selected].mean(0)).T@(
        train-train.mean(0))/len(train)
    result=dict(format='function-kernel-gaussian-bank/1',rank=K,
        law='Gaussian with captured training input mean and full sample covariance; no response fit',
        train_state_count=len(train),separate_validation_state_count=len(held),
        source_selected_ids_sha256=__import__('hashlib').sha256(selected.astype('<u2').tobytes()).hexdigest(),
        gram_centered_min_eigenvalue=float(eigen[0]),gram_centered_max_eigenvalue=float(eigen[-1]),
        ridge_relative_to_mean_diagonal=0.01,physical_model_bytes=6144*K+2*K+2048+7,
        model_predicted_output_mean_vs_actual_train_relative_error=relative(down@mean-train.mean(0),train.mean(0)),
        model_predicted_output_mean_vs_actual_held_relative_error=relative(down@mean-held.mean(0),held.mean(0)),
        model_predicted_output_cross_vs_actual_train_relative_error=relative(weighted_response-actual_train_cross,actual_train_cross),
        model_predicted_output_cross_vs_actual_held_relative_error=relative(weighted_response-actual_held_cross,actual_held_cross),
        train_relative_rms=relative(prediction_train-train,train),
        held_relative_rms=relative(prediction-held,held),
        held_q4_relative_rms=json.loads((PARENT/'results.json').read_text())['q4_relative_rms']['held'],
        target_held_mean_norm=float(np.linalg.norm(held.mean(0))),
        predicted_held_mean_norm=float(np.linalg.norm(prediction.mean(0))),
        candidate_image=None)
    (HERE/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
