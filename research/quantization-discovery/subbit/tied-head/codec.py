"""Head-specific dictionary fitting and little-endian row label packing."""
import numpy as np


def distances(x, centers):
    x=np.asarray(x,np.float32)
    centers=np.asarray(centers,np.float32)
    return np.maximum(0,(x*x).sum(1)[:,None]+(centers*centers).sum(1)[None,:]-2*x@centers.T)


def train_kmeans(x,k,rng,steps=18):
    d=x.shape[1]
    centers=x[rng.choice(len(x),k,replace=False)].astype(np.float32).copy()
    for _ in range(steps):
        labels=distances(x,centers).argmin(1)
        counts=np.bincount(labels,minlength=k)
        totals=np.zeros((k,d),np.float32)
        np.add.at(totals,labels,x)
        live=counts>0
        centers[live]=totals[live]/counts[live,None]
        if (~live).any():
            farther=np.argsort(distances(x,centers).min(1))[-np.sum(~live):]
            centers[~live]=x[farther]
    return centers


def pack(labels,bits):
    rows,segments=labels.shape
    if bits<1 or bits>8 or np.any(labels>=1<<bits):raise ValueError('invalid labels')
    out=np.zeros((rows,(segments*bits+7)//8),np.uint8)
    for s in range(segments):
        position=s*bits;byte=position//8
        shifted=labels[:,s].astype(np.uint32) << (position%8)
        for part in range((bits+position%8+7)//8):
            out[:,byte+part] |= (shifted>>(8*part)).astype(np.uint8)
    return out


def unpack(packed,segments,bits):
    rows,width=packed.shape
    if width!=(segments*bits+7)//8:raise ValueError('wrong label packet width')
    out=np.empty((rows,segments),np.uint8)
    for s in range(segments):
        position=s*bits;byte=position//8
        shifted=np.zeros(rows,np.uint32)
        for part in range((bits+position%8+7)//8):
            shifted |=packed[:,byte+part].astype(np.uint32) << (8*part)
        out[:,s]=((shifted>>(position%8)) & ((1<<bits)-1)).astype(np.uint8)
    return out
