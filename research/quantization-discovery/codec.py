"""The fixed, prefix-free eight-trit codec used in the real-block experiment.

All model-dependent data are in the bitstream. The shared decoder has no learned
codebook. Arithmetic charges in the experiment are a separate abstract model.
"""
import struct


def encode(blocks, scale):
    bits = ''.join(f'{b:08b}' for b in struct.pack('<e', scale))
    for values in blocks:
        if len(values) != 8 or any(v not in (-1, 0, 1) for v in values):
            raise ValueError('an eight-trit block is required')
        if values == [0]*8:
            bits += '0'
        elif values == [-1]*8:
            bits += '100'
        elif values == [1]*8:
            bits += '101'
        elif values == [-1, 1]*4:
            bits += '1100'
        elif values == [1, -1]*4:
            bits += '1101'
        else:
            payload = sum((v+1)*3**i for i, v in enumerate(values))
            bits += '111'+f'{payload:013b}'
    padding = (-len(bits)) % 8
    wire = bits+'0'*padding
    return bytes(int(wire[i:i+8], 2) for i in range(0, len(wire), 8)), len(bits)


def decode(wire, block_count):
    if len(wire) < 2:
        raise ValueError('missing scale')
    scale = struct.unpack('<e', wire[:2])[0]
    bits = ''.join(f'{b:08b}' for b in wire[2:])
    offset, blocks = 0, []
    def take(n):
        nonlocal offset
        if offset+n > len(bits):
            raise ValueError('truncated code')
        result = bits[offset:offset+n]
        offset += n
        return result
    for _ in range(block_count):
        if take(1) == '0':
            blocks.append([0]*8)
        elif take(1) == '0':
            sign = -1 if take(1) == '0' else 1
            blocks.append([sign]*8)
        elif take(1) == '0':
            sign = -1 if take(1) == '0' else 1
            blocks.append([sign, -sign]*4)
        else:
            payload = int(take(13), 2)
            if payload >= 3**8:
                raise ValueError('out-of-alphabet literal')
            values = []
            for _ in range(8):
                values.append(payload % 3-1)
                payload //= 3
            blocks.append(values)
    return blocks, scale, offset+16
