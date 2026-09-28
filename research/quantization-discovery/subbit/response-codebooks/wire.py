#!/usr/bin/env python3
"""Row-major bit labels and direct response-table observation, without int4 expansion."""
import numpy as np


def pack_labels(labels,bits):
    rows,segments=labels.shape
    if bits<1 or bits>8 or np.any(labels<0) or np.any(labels >= 1<<bits):
        raise ValueError('invalid fixed-width labels')
    packet=np.zeros((rows,(segments*bits+7)//8),np.uint8)
    for segment in range(segments):
        position=segment*bits
        byte=position//8
        shifted=labels[:,segment].astype(np.uint32) << (position%8)
        for part in range((bits+position%8+7)//8):
            packet[:,byte+part] |= (shifted >> (8*part)).astype(np.uint8)
    return packet


def unpack_labels(packet,segments,bits):
    rows,width=packet.shape
    if width!=(segments*bits+7)//8:
        raise ValueError('invalid row width')
    labels=np.empty((rows,segments),np.uint8)
    for segment in range(segments):
        position=segment*bits
        byte=position//8
        shifted=np.zeros(rows,np.uint32)
        for part in range((bits+position%8+7)//8):
            shifted |= packet[:,byte+part].astype(np.uint32) << (8*part)
        labels[:,segment]=((shifted >> (position%8)) & ((1<<bits)-1)).astype(np.uint8)
    return labels


def observe(packet,codes,unit,scales,inputs,*,exceptions=None,bias=None):
    """Consume packed labels through response tables and optional paid residuals.

    exceptions is a pair (indices, fp16 residuals), each [rows, blocks, count].
    This computes the real-arithmetic weight response; it does not mimic the
    order or rounding of a deployed BF16 GEMM.
    """
    rows=packet.shape[0]
    length=codes.shape[1]
    cols=inputs.shape[1]
    if cols%128 or cols%length:
        raise ValueError('input and codebook geometry disagree')
    segments=cols//length
    bits=(len(codes)-1).bit_length()
    if len(codes)!=1<<bits or scales.shape!=(rows,cols//128):
        raise ValueError('codebook or scale geometry disagree')
    labels=unpack_labels(packet,segments,bits)
    output=np.zeros((len(inputs),rows),np.float64)
    for segment in range(segments):
        start=segment*length
        table=inputs[:,start:start+length].astype(np.float32) @ codes.astype(np.float32).T
        output+=table[:,labels[:,segment]].astype(np.float64)*float(unit)*scales[None,:,start//128]
    if exceptions is not None:
        indices,values=exceptions
        if indices.shape!=values.shape or indices.shape[:2]!=(rows,cols//128):
            raise ValueError('exception geometry disagrees')
        for block in range(cols//128):
            for j in range(indices.shape[2]):
                address=block*128+indices[:,block,j].astype(np.int32)
                output+=inputs[:,address]*values[None,:,block,j].astype(np.float32)
    if bias is not None:
        if bias.shape!=(rows,):
            raise ValueError('affine bias shape disagrees')
        output+=bias[None,:]
    return output
