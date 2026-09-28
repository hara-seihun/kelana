#!/usr/bin/env python3
"""Learn sixteen eight-sign patterns per input block for a direct lookup binary factor."""
import argparse
import importlib.util
import json
import math
import time
from pathlib import Path

import numpy as np
import torch

FIXTURES = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext')
ADMM = Path(__file__).resolve().parents[1] / 'binary-factors/nanoquant_admm.py'


def initial_factor(weight, train, rank, iterations):
    spec = importlib.util.spec_from_file_location('nanoquant_admm_pinned', ADMM)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    norm = .6 * train.square().mean(0) + .4 * train.square().mean()
    result = module.factorize_admm_nanoquant(weight, norm, torch.ones(weight.shape[0]), rank,
                                              outer_iters=iterations, inner_iters=5,
                                              rho_scheduler='linear', is_transpose=weight.shape[0] < weight.shape[1])
    u, v = result['A'].T.sign(), result['B'].sign()
    u[u == 0] = 1
    v[v == 0] = 1
    return u, v, result['scale_pre'].flatten().half().float(), result['scale_post'].flatten().half().float()


def cluster(v, labels_count, block, rounds=16):
    rank, width = v.shape
    groups = width // block
    chunks = v.reshape(rank, groups, block).transpose(0, 1).numpy()
    dictionary = np.empty((groups, labels_count, block), dtype=np.float32)
    labels = np.empty((groups, rank), dtype=np.int64)
    for group in range(groups):
        chunk = chunks[group]
        integer = np.packbits((chunk > 0).astype(np.uint8), axis=-1, bitorder='little')[:, 0]
        frequency = np.bincount(integer, minlength=256)
        ordered = np.argsort(-frequency, kind='stable')
        centers = np.unpackbits(ordered[:labels_count].astype(np.uint8)[:, None], axis=1,
                                bitorder='little').astype(np.float32) * 2 - 1
        for _ in range(rounds):
            assignment = (chunk @ centers.T).argmax(axis=1)
            updated = centers.copy()
            for code in range(labels_count):
                members = chunk[assignment == code]
                if len(members):
                    votes = members.sum(0)
                    updated[code] = np.where(votes == 0, centers[code], np.sign(votes))
            if np.array_equal(updated, centers):
                break
            centers = updated
        dictionary[group] = centers
        labels[group] = (chunk @ centers.T).argmax(axis=1)
    return torch.from_numpy(dictionary), torch.from_numpy(labels)


def expand(dictionary, labels):
    groups, _, block = dictionary.shape
    return dictionary[torch.arange(groups)[:, None], labels].transpose(0, 1).reshape(labels.shape[1], groups * block)


def quality(weight, heldout, u, v, pre, post):
    packed_u = np.packbits((u.numpy() > 0).astype(np.uint8), axis=1, bitorder='little')
    u = torch.from_numpy(np.unpackbits(packed_u, axis=1, bitorder='little')[:, :u.shape[1]].astype(np.float32)) * 2 - 1
    pre, post = pre.half().float(), post.half().float()
    reference = heldout @ weight.T
    estimate = ((heldout * pre) @ v.T @ u.T) * post
    weighted_error = ((estimate - reference).square().sum() / reference.square().sum()).item()
    reconstruction = (u @ v) * post[:, None] * pre[None, :]
    weight_error = ((reconstruction - weight).square().sum() / weight.square().sum()).item()
    return weighted_error, weight_error, packed_u


def refine_u(target, u, v, pre, post, sweeps):
    basis = v * pre
    gram = basis @ basis.T
    h = target @ basis.T
    for _ in range(sweeps):
        current = u @ gram
        for r in range(v.shape[0]):
            score = h[:, r] - post * (current[:, r] - u[:, r] * gram[r, r])
            update = torch.where(score >= 0, 1., -1.)
            delta = update - u[:, r]
            u[:, r] = update
            current += delta[:, None] * gram[r][None, :]
    return u


def refine_u_activations(weight, train, u, v, pre, post, sweeps):
    features = (train * pre) @ v.T
    reference = train @ weight.T
    gram = features.T @ features / len(train)
    h = reference.T @ features / len(train)
    for _ in range(sweeps):
        current = u @ gram
        for r in range(v.shape[0]):
            score = h[:, r] - post * (current[:, r] - u[:, r] * gram[r, r])
            updated = torch.where(score >= 0, 1., -1.)
            delta = updated - u[:, r]
            u[:, r] = updated
            current += delta[:, None] * gram[r][None, :]
        prediction = features @ u.T
        post = ((reference * prediction).sum(0) / prediction.square().sum(0).clamp_min(1e-20)).clamp_min(0).half().float()
    return u, post


def refine_labels(target, u, dictionary, labels, pre, post, sweeps):
    groups, codes, block = dictionary.shape
    rank = u.shape[1]
    a = u * post[:, None]
    gram = a.T @ a
    h = (a.T @ target).reshape(rank, groups, block)
    v = expand(dictionary, labels).reshape(rank, groups, block)
    input_scale = pre.reshape(groups, block)
    dictionary_scaled = dictionary * input_scale[:, None, :]
    for _ in range(sweeps):
        current = (gram @ v.reshape(rank, -1)).reshape(rank, groups, block)
        for r in range(rank):
            score = h[r] - input_scale * (current[r] - gram[r, r] * v[r])
            choice = torch.einsum('gb,gcb->gc', score, dictionary_scaled).argmax(1)
            updated = dictionary[torch.arange(groups), choice]
            delta = updated - v[r]
            v[r] = updated
            labels[:, r] = choice
            current += gram[:, r, None, None] * delta[None, :, :]
    return labels


def refine_labels_activations(weight, train, u, dictionary, labels, pre, post, rounds, edits_per_round):
    groups, codes, block = dictionary.shape
    rank = u.shape[1]
    x = train * pre
    reference = train @ weight.T
    a = u * post[:, None]
    blocks = x.reshape(len(train), groups, block)
    covariance = torch.einsum('tgb,tgc->gbc', blocks, blocks) / len(train)
    norm_a = a.square().sum(0)
    pattern_quad = torch.einsum('gcb,gbd,gcd->gc', dictionary, covariance, dictionary)
    history = []
    for iteration in range(rounds):
        v = expand(dictionary, labels)
        residual = reference - (x @ v.T) @ a.T
        baseline = residual.square().mean().item()
        gradient = ((residual @ a).T @ x / len(train)).reshape(rank, groups, block)
        old = v.reshape(rank, groups, block)
        candidate_dot = torch.einsum('rgb,gcb->rgc', gradient, dictionary)
        current_dot = (gradient * old).sum(2)
        cross = torch.einsum('rgb,gbd,gcd->rgc', old, covariance, dictionary)
        old_quad = torch.einsum('rgb,gbd,rgd->rg', old, covariance, old)
        gain = 2 * (candidate_dot - current_dot[:, :, None])
        gain -= norm_a[:, None, None] * (pattern_quad[None] - 2 * cross + old_quad[:, :, None])
        best_gain, best_code = gain.max(2)
        best_gain[best_gain <= 0] = 0
        sorted_gains, sorted_flat = best_gain.flatten().topk(min(edits_per_round, best_gain.numel()))
        if sorted_gains[0] <= 0:
            break
        original = labels.clone()
        count = int((sorted_gains > 0).sum().item())
        flat = sorted_flat[:count]
        labels[flat % groups, flat // groups] = best_code.flatten()[flat]
        new_v = expand(dictionary, labels)
        achieved = (reference - (x @ new_v.T) @ a.T).square().mean().item()
        if achieved >= baseline:
            labels[:] = original
            break
        history.append({'changes': count, 'train_mean_squared_error': achieved})
    return labels, history


def refine_dictionary(target, u, dictionary, labels, pre, post):
    groups, codes, block = dictionary.shape
    rank = u.shape[1]
    a = u * post[:, None]
    gram = a.T @ a
    h = (a.T @ target).reshape(rank, groups, block)
    input_scale = pre.reshape(groups, block)
    v = expand(dictionary, labels).reshape(rank, groups, block)
    current = (gram @ v.reshape(rank, -1)).reshape(rank, groups, block)
    for group in range(groups):
        for code in range(codes):
            members = torch.where(labels[group] == code)[0]
            if not members.numel():
                continue
            cross = gram[:, members].sum(1)
            norm = cross[members].sum()
            score = h[members, group].sum(0) - input_scale[group] * current[members, group].sum(0)
            score += norm * input_scale[group] * dictionary[group, code]
            updated = torch.where(score >= 0, 1., -1.)
            delta = updated - dictionary[group, code]
            dictionary[group, code] = updated
            v[members, group] = updated
            current[:, group] += cross[:, None] * delta[None, :]
    return dictionary


def refine_post(weight, u, v, pre):
    basis = u @ (v * pre)
    numerator = (weight * basis).sum(1)
    denominator = basis.square().sum(1).clamp_min(1e-20)
    return (numerator / denominator).clamp_min(0).half().float()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fixture', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--rank', type=int, help='defaults to the largest byte-aligned rank within .55 matrix BPW')
    p.add_argument('--codes', type=int, default=16)
    p.add_argument('--block', type=int, default=8)
    p.add_argument('--admm-iterations', type=int, default=400)
    p.add_argument('--rounds', type=int, default=3)
    p.add_argument('--activation-sweeps', type=int, default=0)
    p.add_argument('--activation-label-rounds', type=int, default=0)
    p.add_argument('--label-edits-per-round', type=int, default=64)
    p.add_argument('--threads', type=int, default=8)
    p.add_argument('--image-dir', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/block-factor'))
    args = p.parse_args()
    torch.set_num_threads(args.threads)
    torch.manual_seed(0)
    with np.load(args.fixture) as data:
        weight, train, heldout = [torch.from_numpy(data[key].copy()).float() for key in ('weight', 'train', 'validation')]
    n, k = weight.shape
    if k % args.block or args.block != 8 or args.codes not in (8, 16, 32, 64, 128):
        raise ValueError('this experiment uses eight-channel blocks and 8/16/32/64/128 codes')
    label_bits = int(math.log2(args.codes))
    groups = k // args.block
    if args.rank is None:
        budget = int(.55 * n * k) - groups * args.codes * 8 - 16 * (n + k)
        args.rank = 8 * (budget // (8 * (n + groups * label_bits)))
    if args.rank % 8 or args.rank > min(n, k):
        raise ValueError('rank must be byte-aligned and no greater than either dimension')
    start = time.monotonic()
    u, v, pre, post = initial_factor(weight, train, args.rank, args.admm_iterations)
    admm_quality = quality(weight, heldout, u, v, pre, post)[:2]
    dictionary, labels = cluster(v, args.codes, args.block)
    v = expand(dictionary, labels)
    initial_quality = quality(weight, heldout, u, v, pre, post)[:2]
    target = weight
    history = []
    for iteration in range(args.rounds):
        u = refine_u(target, u, v, pre, post, 1)
        post = refine_post(target, u, v, pre)
        labels = refine_labels(target, u, dictionary, labels, pre, post, 1)
        dictionary = refine_dictionary(target, u, dictionary, labels, pre, post)
        v = expand(dictionary, labels)
        post = refine_post(target, u, v, pre)
        history.append(quality(weight, heldout, u, v, pre, post)[:2])
    before_activation = history[-1] if history else initial_quality
    if args.activation_sweeps:
        u, post = refine_u_activations(weight, train, u, v, pre, post, args.activation_sweeps)
    before_label_activation = quality(weight, heldout, u, v, pre, post)[:2]
    label_history = []
    if args.activation_label_rounds:
        labels, label_history = refine_labels_activations(weight, train, u, dictionary, labels, pre, post,
                                                           args.activation_label_rounds, args.label_edits_per_round)
        v = expand(dictionary, labels)
    response, matrix_error, packed_u = quality(weight, heldout, u, v, pre, post)
    coeff_bytes = n * (args.rank // 8)
    label_bytes = args.rank * groups * label_bits // 8
    dict_bytes = groups * args.codes
    scale_bytes = 2 * (n + k)
    payload_bytes = coeff_bytes + label_bytes + dict_bytes + scale_bytes
    report = {'fixture': args.fixture.name, 'dimensions': [n, k], 'rank': args.rank,
              'admm_iterations': args.admm_iterations, 'rounds': args.rounds,
              'input_codes_per_block': args.codes, 'input_label_bits': label_bits,
              'admm_same_rank_heldout_and_weight_error': admm_quality,
              'compressed_initial_heldout_and_weight_error': initial_quality,
              'refinement_heldout_and_weight_error': history,
              'fit_heldout_response_error': response, 'fit_weight_error': matrix_error,
              'activation_sweeps': args.activation_sweeps,
              'before_activation_heldout_and_weight_error': before_activation,
              'before_activation_label_heldout_and_weight_error': before_label_activation,
              'activation_label_rounds': args.activation_label_rounds,
              'activation_label_history': label_history,
              'seconds_cpu': time.monotonic() - start,
              'payload_bytes': {'output_signs': coeff_bytes, 'input_labels': label_bytes,
                                'input_dictionaries': dict_bytes, 'pre_post_scales': scale_bytes},
              'payload_bpw': 8 * payload_bytes / (n * k),
              'online': {'input_table_signed_additions_upper': groups * args.codes * args.block,
                         'input_label_lookups': args.rank * groups,
                         'output_table_additions': (args.rank // 8) * 255,
                         'output_table_reads': n * args.rank // 8,
                         'input_table_bf16_bytes': groups * args.codes * 2,
                         'output_table_bf16_bytes': (args.rank // 8) * 256 * 2,
                         'intermediate_bf16_bytes_unfused_write_read': 4 * args.rank,
                         'minimum_payload_read_bytes': payload_bytes}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.image_dir.mkdir(parents=True, exist_ok=True)
    image = args.image_dir / (args.output.stem + '.npz')
    packed_dictionary = np.packbits((dictionary.numpy() > 0).astype(np.uint8), axis=2, bitorder='little')[:, :, 0]
    packed_labels = np.packbits(np.stack([(labels.numpy() >> bit) & 1 for bit in range(label_bits)], axis=2).reshape(groups, args.rank * label_bits), axis=1, bitorder='little')
    np.savez(image, U=packed_u, labels=packed_labels, dictionary=packed_dictionary,
             pre=pre.numpy().astype(np.float16), post=post.numpy().astype(np.float16),
             dimensions=np.array([n, k, args.rank, args.block, args.codes], dtype=np.int32))
    report['image'] = str(image)
    report['serialized_zip_bytes'] = image.stat().st_size
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
