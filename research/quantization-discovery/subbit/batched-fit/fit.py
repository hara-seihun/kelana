#!/usr/bin/env python3
"""Batched GPU ADMM NanoQuant initializer for equal normalized matrix shapes and rank."""
import argparse
import gc
import hashlib
import json
import time
from pathlib import Path

import numpy as np
import torch


def rank_for_rate(n, k, rate):
    return min(min(n, k), max(32, (int(rate * n * k / (n + k) - 16) // 32) * 32))


def svid(w, inner_iters):
    sign = torch.where(w < 0, -1., 1.)
    magnitude = w.abs()
    v = torch.randn(w.shape[0], w.shape[2], device=w.device, dtype=w.dtype)
    v = torch.nn.functional.normalize(v, dim=-1)
    for _ in range(inner_iters):
        u = torch.bmm(magnitude, v.unsqueeze(-1)).squeeze(-1)
        u = torch.nn.functional.normalize(u, dim=-1)
        v = torch.bmm(magnitude.transpose(1, 2), u.unsqueeze(-1)).squeeze(-1)
        v = torch.nn.functional.normalize(v, dim=-1)
    u = torch.bmm(magnitude, v.unsqueeze(-1)).squeeze(-1)
    return u.unsqueeze(-1) * v.unsqueeze(1) * sign


def solve_step(x, y, z, dual, rho, reg):
    xt = x.transpose(1, 2)
    system = torch.bmm(xt, x)
    system = .5 * (system + system.transpose(1, 2))
    stabilizer = torch.clamp(rho * system.diagonal(dim1=-2, dim2=-1).mean(-1).abs() + reg, min=1e-12)
    system.diagonal(dim1=-2, dim2=-1).add_(stabilizer.unsqueeze(-1))
    rhs = torch.bmm(xt, y) + rho * (z - dual)
    chol, info = torch.linalg.cholesky_ex(system)
    return torch.cholesky_solve(rhs, chol), info


class Solver:
    def __init__(self, weight, i_norm, o_norm, rank, outer_iters=400, inner_iters=5, reg=.03):
        self.weight = weight
        self.i_norm = i_norm.sqrt().clamp_min(1e-12)
        self.o_norm = o_norm.sqrt().clamp_min(1e-12)
        self.w = weight * self.i_norm[:, None, :] * self.o_norm[:, :, None]
        self.outer_iters, self.inner_iters, self.reg = outer_iters, inner_iters, reg
        batch, n, k = weight.shape
        self.a = torch.randn(batch, n, rank, device=weight.device)
        self.b = torch.randn(batch, rank, k, device=weight.device)
        self.az = svid(self.a, inner_iters)
        self.bz = svid(self.b, inner_iters)
        self.au = self.a - self.az
        self.bu = self.b - self.bz
        self.rho = torch.arange(max(outer_iters, 4), device=weight.device, dtype=torch.float32) / outer_iters
        self.index = torch.zeros((), device=weight.device, dtype=torch.long)
        self.info_a = torch.zeros(batch, device=weight.device, dtype=torch.int32)
        self.info_b = torch.zeros(batch, device=weight.device, dtype=torch.int32)

    def step(self):
        rho = torch.gather(self.rho, 0, self.index.view(1)).squeeze(0)
        nb = self.bz.norm(dim=2).clamp_min(1e-12)
        xa = self.bz.transpose(1, 2) / nb[:, None, :]
        a, ia = solve_step(xa, self.w.transpose(1, 2), self.az.transpose(1, 2),
                           self.au.transpose(1, 2), rho, self.reg)
        a = a.transpose(1, 2)
        na = self.az.norm(dim=1).clamp_min(1e-12)
        xb = self.az / na[:, None, :]
        b, ib = solve_step(xb, self.w, self.bz, self.bu, rho, self.reg)
        new_az = svid(a + self.au, self.inner_iters)
        new_bz = svid(b + self.bu, self.inner_iters)
        self.au.add_(a - new_az)
        self.bu.add_(b - new_bz)
        self.a.copy_(a)
        self.b.copy_(b)
        self.az.copy_(new_az)
        self.bz.copy_(new_bz)
        self.info_a.copy_(torch.maximum(self.info_a, ia))
        self.info_b.copy_(torch.maximum(self.info_b, ib))
        self.index.add_(1)

    def export(self):
        norm_a = self.az / self.o_norm[:, :, None]
        norm_b = self.bz / self.i_norm[:, None, :]
        balance = (norm_b.flatten(1).norm(dim=1) / norm_a.flatten(1).norm(dim=1).clamp_min(1e-12)).sqrt()
        a = norm_a * balance[:, None, None]
        b = norm_b / balance[:, None, None]
        a = a / self.az.norm(dim=1).clamp_min(1e-12)[:, None, :]
        pre = b.abs().mean(dim=1).half()
        post = a.abs().mean(dim=2).half()
        return a, b, pre, post


def fit_group(weight, i_norm, o_norm, rank, *, outer_iters=400, inner_iters=5,
              graph=True, sync_every=10):
    """Fit equal-shape CUDA tensors [B,N,K], [B,K], [B,N] with N>=K.

    Norms are squared-channel moments. Returns the NanoQuant factor contract as
    batched tensors A[B,R,N], B[B,R,K], scale_pre[B,K], scale_post[B,N], plus timings.
    A caller with N<K transposes W and swaps norms, then swaps A/B and scales back.
    """
    if weight.ndim != 3 or i_norm.shape != (weight.shape[0], weight.shape[2]) or o_norm.shape != weight.shape[:2]:
        raise ValueError('expected weight[B,N,K], i_norm[B,K], o_norm[B,N]')
    if weight.shape[1] < weight.shape[2] or not weight.is_cuda:
        raise ValueError('pass CUDA tensors with N>=K after transposing wide matrices')
    if rank < 1 or rank > min(weight.shape[1:]) or outer_iters < 1 or inner_iters < 1:
        raise ValueError('invalid rank or iteration count')
    if not all(torch.isfinite(t).all().item() for t in (weight,i_norm,o_norm)) or (i_norm<0).any().item() or (o_norm<0).any().item():
        raise ValueError('weight and squared channel norms must be finite; norms must be nonnegative')
    if graph and not 1 <= sync_every <= 10:
        raise ValueError('gfx1151 ROCm graph replay needs a device sync every 1..10 steps; larger queues segfaulted')
    graph_enabled=graph and weight.shape[0]>1
    if graph and not graph_enabled:
        print('batch 1: eager solve; hipSOLVER Cholesky graph capture failed on gfx1151',flush=True)
    start=time.perf_counter()
    solver=Solver(weight,i_norm,o_norm,rank,outer_iters,inner_iters)
    torch.cuda.synchronize()
    setup=time.perf_counter()-start
    captured=None
    capture_start=time.perf_counter()
    if graph_enabled:
        # Every replay reads and writes the same state buffers. The GPU-owned rho
        # index advances inside the graph, so no matrix incurs a host item check.
        saved={name:getattr(solver,name).clone() for name in ('a','b','az','bz','au','bu','index','info_a','info_b')}
        stream=torch.cuda.Stream()
        stream.wait_stream(torch.cuda.current_stream())
        with torch.cuda.stream(stream):
            for _ in range(3): solver.step()
        torch.cuda.current_stream().wait_stream(stream)
        solver.index.zero_()
        torch.cuda.synchronize()
        captured=torch.cuda.CUDAGraph()
        with torch.cuda.graph(captured): solver.step()
        for name,value in saved.items(): getattr(solver,name).copy_(value)
        torch.cuda.synchronize()
    capture_seconds=time.perf_counter()-capture_start
    start=time.perf_counter()
    for iteration in range(outer_iters):
        if captured: captured.replay()
        else: solver.step()
        if graph_enabled and (iteration+1)%sync_every==0:
            torch.cuda.synchronize()
    torch.cuda.synchronize()
    solve_seconds=time.perf_counter()-start
    if max(solver.info_a.max().item(),solver.info_b.max().item()) != 0:
        raise RuntimeError('Cholesky failed for at least one solve; no packed image exported')
    a,b,pre,post=solver.export()
    if not all(torch.isfinite(t).all().item() for t in (a,b,pre,post)):
        raise RuntimeError('Non-finite factor or scale; no image exported')
    return {'A':a.transpose(1,2),'B':b,'scale_pre':pre,'scale_post':post}, {
        'setup_seconds':setup,'graph_capture_seconds':capture_seconds,
        'solve_seconds':solve_seconds,'graph_effective':graph_enabled,
        'device_sync_every_steps':sync_every if graph_enabled else None}


def source_hash(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def input_from_fixture(path):
    with np.load(path) as d:
        w = d['weight'].astype(np.float32)
        x = d['train'].astype(np.float32)
        validation = d['validation'].astype(np.float32)
    i = (.6 * (x*x).mean(0) + .4 * (x*x).mean()).astype(np.float32)
    o = np.ones(w.shape[0], dtype=np.float32)
    return w, i, o, validation


def input_from_npz(path):
    with np.load(path) as d:
        w = d['weight'].astype(np.float32)
        i = d['i_norm'].astype(np.float32)
        o = d['o_norm'].astype(np.float32)
    if i.shape != (w.shape[1],) or o.shape != (w.shape[0],):
        raise ValueError(f'{path}: expected weight[N,K], i_norm[K], o_norm[N]')
    if not all(np.isfinite(t).all() for t in (w,i,o)) or np.any(i<0) or np.any(o<0):
        raise ValueError(f'{path}: weights and squared channel norms must be finite, norms nonnegative')
    return w, i, o, None


def run(args):
    started=time.perf_counter()
    paths = [Path(p) for p in args.inputs]
    if len(paths) > 16:
        raise ValueError('at most 16 inputs per bounded GPU reservation; split the group across invocations')
    if len({p.stem for p in paths}) != len(paths):
        raise ValueError('input file stems must be distinct so output images cannot overwrite one another')
    loaded = [(input_from_fixture(p) if args.fixtures else input_from_npz(p)) for p in paths]
    original_shapes = [w.shape for w, _, _, _ in loaded]
    normalized = [(w.T.copy(), o, i, v) if w.shape[0] < w.shape[1] else (w, i, o, v)
                  for w, i, o, v in loaded]
    shapes = {w.shape for w, _, _, _ in normalized}
    if len(shapes) != 1:
        raise ValueError(f'group inputs by equal shape after transposing wide matrices: {shapes}')
    n,k = next(iter(shapes))
    rank = rank_for_rate(n,k,args.rate)
    if args.rank is not None: rank=args.rank
    if rank > min(n,k) or rank <= 0 or rank % 32:
        raise ValueError('rank must be positive, <= min(N,K), and divisible by 32')
    device = torch.device('cuda')
    torch.manual_seed(args.seed)
    args.out.mkdir(parents=True, exist_ok=True)
    entries=[]
    chunks=[]
    report={'method':'batched fp32 GPU ADMM NanoQuant initializer, binary sign export; not upstream bit-equivalence',
            'source_sha256':source_hash(Path(__file__)),'torch':torch.__version__, 'device':str(torch.cuda.get_device_name()),
            'group_size':len(paths),'chunk_limit':8,'normalized_shape':[n,k],'rank':rank,'outer_iters':args.outer_iters,
            'inner_iters':args.inner_iters,'rho_scheduler':'linear','reg':.03,'seed':args.seed,
            'graph_requested':args.graph,'entries':entries,'chunks':chunks,'complete':False}
    for offset in range(0,len(paths),8):
        chunk=normalized[offset:offset+8]
        weight=torch.from_numpy(np.stack([w for w,_,_,_ in chunk])).to(device)
        i_norm=torch.from_numpy(np.stack([i for _,i,_,_ in chunk])).to(device)
        o_norm=torch.from_numpy(np.stack([o for _,_,o,_ in chunk])).to(device)
        factors,timings=fit_group(weight,i_norm,o_norm,rank,outer_iters=args.outer_iters,
                                  inner_iters=args.inner_iters,graph=args.graph,sync_every=args.sync_every)
        a=factors['A'].transpose(1,2).cpu().numpy()
        b=factors['B'].cpu().numpy()
        pre=factors['scale_pre'].cpu().numpy()
        post=factors['scale_post'].cpu().numpy()
        del factors,weight,i_norm,o_norm
        gc.collect()
        torch.cuda.empty_cache()
        export_start=time.perf_counter()
        for local_idx,(w,_,_,validation) in enumerate(loaded[offset:offset+len(chunk)]):
            idx=offset+local_idx
            path=paths[idx]
            if original_shapes[idx][0]<original_shapes[idx][1]:
                u=b[local_idx].T
                v=a[local_idx].T
                scale_pre=post[local_idx]
                scale_post=pre[local_idx]
            else:
                u=a[local_idx]
                v=b[local_idx]
                scale_pre=pre[local_idx]
                scale_post=post[local_idx]
            pu=np.packbits((u>0).astype(np.uint8),axis=1,bitorder='little')
            pv=np.packbits((v>0).astype(np.uint8),axis=1,bitorder='little')
            destination=args.out/(path.stem+'-gpu.npz')
            np.savez(destination,U=pu,V=pv,scale_pre=scale_pre,scale_post=scale_post,
                     dimensions=np.array([w.shape[0],w.shape[1],rank],dtype=np.int32))
            record={'input':str(path),'input_sha256':source_hash(path),'image':str(destination),
                    'image_sha256':source_hash(destination),'shape':list(w.shape),'rank':rank,
                    'payload_bytes':sum(t.nbytes for t in (pu,pv,scale_pre,scale_post))}
            if validation is not None:
                signed_u=np.unpackbits(pu,axis=1,bitorder='little')[:,:rank].astype(np.float32)*2-1
                signed_v=np.unpackbits(pv,axis=1,bitorder='little')[:,:w.shape[1]].astype(np.float32)*2-1
                pred=((validation*scale_pre.astype(np.float32))@signed_v.T)@signed_u.T*scale_post.astype(np.float32)
                truth=validation@w.T
                record['validation_relative_squared_error']=float(np.sum((pred-truth)**2)/np.sum(truth**2))
            entries.append(record)
        chunks.append({'start':offset,'count':len(chunk),**timings,
                       'export_and_validation_seconds':time.perf_counter()-export_start})
        report['total_seconds']=time.perf_counter()-started
        report['complete']=len(entries)==len(paths)
        tmp=args.out/'run.json.tmp'
        tmp.write_text(json.dumps(report,indent=2)+'\n')
        tmp.replace(args.out/'run.json')
        print(json.dumps({'chunk_start':offset,'count':len(chunk),'solve_seconds':timings['solve_seconds'],
                          'validation_errors':[r.get('validation_relative_squared_error') for r in entries[offset:]]}),flush=True)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('inputs',nargs='+',help='Same normalized shape after transposing wide matrices')
    p.add_argument('--fixtures',action='store_true',help='Read weight/train/validation NPZs and 0.4-shrunk input norms')
    p.add_argument('--rate',type=float,default=.55)
    p.add_argument('--rank',type=int)
    p.add_argument('--outer-iters',type=int,default=400)
    p.add_argument('--inner-iters',type=int,default=5)
    p.add_argument('--seed',type=int,default=0)
    p.add_argument('--graph',action='store_true',help='Capture each <=8-matrix chunk and replay it; batch 1 uses eager due to hipSOLVER capture failure')
    p.add_argument('--sync-every',type=int,default=10,help='ROCm graph device sync every N steps, 1..10 required')
    p.add_argument('--out',type=Path,required=True)
    run(p.parse_args())
