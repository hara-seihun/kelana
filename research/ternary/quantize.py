"""Group-128 ternary weights with optional signed Hadamard input coordinates.

`quantize(W, method="rtn")` minimizes each group's unweighted squared
weight error over one symmetric scale and {-1, 0, 1} codes. With
`method="gptq"`, X (calibration inputs) or H = X.T @ X / len(X) supplies
curvature; a damped full inverse-Hessian factor drives sequential rounding
within each 128-column window and GEMM propagation to later windows. GPTQ
fixes its scales to the RTN solution *before* those updates.

The rotated coordinates use R = D @ H_b, with D the stored signs and H_b
the orthonormal block Hadamard. A consumer can use (X @ R) @ W_rot.T;
`TernaryImage.decode()` instead returns W_rot @ R.T for ordinary X @ W.T.
FP16 scale rounding is part of both methods' returned image.
"""

from dataclasses import dataclass

import torch

GROUP = 128


def _hadamard(x: torch.Tensor, block: int) -> torch.Tensor:
    shape = x.shape
    y = x.reshape(-1, block)
    width = 1
    while width < block:
        pairs = y.reshape(-1, block // (2 * width), 2, width)
        a, b = pairs.unbind(dim=-2)
        y = torch.stack((a + b, a - b), dim=-2).reshape(-1, block)
        width *= 2
    return (y * (block ** -0.5)).reshape(shape)


def _rotate(x: torch.Tensor, signs: torch.Tensor, block: int) -> torch.Tensor:
    return _hadamard(x * signs.to(torch.float32), block)


@dataclass
class TernaryImage:
    codes: torch.Tensor      # int8 [out, in], in rotated coordinates if requested
    scales: torch.Tensor     # float16 [out, in/128]
    signs: torch.Tensor | None  # int8 [in], or None for ordinary coordinates
    rotation_block: int | None

    def decode(self) -> torch.Tensor:
        """Effective FP32 [out, in] weight in the input's original coordinates."""
        w = (self.codes.reshape(-1, self.scales.shape[1], GROUP).float()
             * self.scales.float().unsqueeze(-1)).reshape(self.codes.shape)
        if self.rotation_block is not None:
            # R.T = H_b @ D, whereas `_rotate` applies R = D @ H_b.
            w = _hadamard(w, self.rotation_block) * self.signs.float()
        return w


def _least_squares_groups(w: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
    """Exact per-group LS optimum across every possible nonzero count."""
    magnitude = w.abs()
    ordered, indices = magnitude.sort(dim=-1, descending=True)
    prefix = ordered.cumsum(dim=-1)
    count = torch.arange(1, GROUP + 1, device=w.device, dtype=torch.float32)
    score = prefix.square() / count
    best = score.argmax(dim=-1, keepdim=True)
    scale = (prefix.gather(-1, best) / (best + 1)).squeeze(-1).half()
    selected = (torch.arange(GROUP, device=w.device) <= best).to(torch.int8)
    codes = torch.zeros_like(w, dtype=torch.int8).scatter_(-1, indices, selected)
    codes = codes * w.sign().to(torch.int8)
    return codes, scale


def _inverse_cholesky(h: torch.Tensor, damp: float) -> torch.Tensor:
    """Upper Cholesky of the full inverse damped calibration covariance."""
    eye = torch.eye(h.shape[0], device=h.device, dtype=torch.float32)
    diag = h.diagonal().mean().clamp_min(1e-8)
    # A token count below the input width gives a rank-deficient covariance.
    for multiplier in (1, 10, 100, 1000):
        regularized = h + diag * max(damp, 1e-6) * multiplier * eye
        factor, info = torch.linalg.cholesky_ex(regularized)
        if not info.any().item():
            inverse = torch.cholesky_inverse(factor)
            upper, info = torch.linalg.cholesky_ex(inverse, upper=True)
            if not info.any().item():
                return upper
    raise ValueError("calibration Hessian cannot be stabilized with diagonal damping")


@torch.no_grad()
def quantize(
    W: torch.Tensor,
    *,
    method: str = "rtn",
    rotation_block: int | None = None,
    X: torch.Tensor | None = None,
    H: torch.Tensor | None = None,
    signs: torch.Tensor | None = None,
    seed: int = 0,
    damp: float = 0.01,
    row_chunk: int = 4096,
) -> TernaryImage:
    """Quantize an FP32 [out, in] weight; return codes, FP16 scales and decoder.

    X is [tokens, in], H is [in, in], and both are in original coordinates.
    Supply exactly one for GPTQ. Rotation blocks may be 128 or 1024, provided
    in is divisible by the block width. Signs default to a seeded Rademacher
    draw; pass a +/-1 tensor to reuse the same rotation in several matrices.
    Row chunks bound scratch storage for large tied embedding/head matrices.
    """
    if W.ndim != 2 or W.dtype != torch.float32 or W.shape[1] % GROUP:
        raise ValueError("W must be FP32 [out, in] with in divisible by 128")
    if method not in ("rtn", "gptq"):
        raise ValueError("method must be 'rtn' or 'gptq'")
    if rotation_block not in (None, 128, 1024) or (
        rotation_block is not None and W.shape[1] % rotation_block
    ):
        raise ValueError("rotation_block must be 128 or 1024 and divide in")
    if row_chunk <= 0 or damp < 0:
        raise ValueError("row_chunk must be positive and damp nonnegative")
    if (X is not None and H is not None) or (method == "gptq" and X is None and H is None):
        raise ValueError("GPTQ needs exactly one of X or H")
    if signs is not None and rotation_block is None:
        raise ValueError("signs require a rotation_block")
    n = W.shape[1]
    for name, value, shape in (("X", X, (n,)), ("H", H, (n, n))):
        if value is not None and (value.dtype != torch.float32 or value.device != W.device
                                  or (value.shape[1:] if name == "X" else value.shape) != shape
                                  or (name == "X" and (value.ndim != 2 or value.shape[0] == 0))):
            raise ValueError(f"{name} must be FP32 on W's device with matching dimensions")
    if rotation_block is not None:
        if signs is None:
            generator = torch.Generator(device="cpu").manual_seed(seed)
            signs = (torch.randint(0, 2, (n,), generator=generator, dtype=torch.int8) * 2 - 1).to(W.device)
        elif signs.shape != (n,) or signs.device != W.device or not torch.all((signs == 1) | (signs == -1)).item():
            raise ValueError("signs must be +/-1 [in] on W's device")
        signs = signs.to(torch.int8).clone()

    upper = None
    if method == "gptq":
        if X is not None:
            x = _rotate(X, signs, rotation_block) if rotation_block is not None else X
            h = x.T @ x / x.shape[0]
        else:
            h = H
            if rotation_block is not None:
                # (H @ R), then the same row-vector operation on its transpose:
                # R.T @ H @ R.
                h = _rotate(_rotate(h, signs, rotation_block).T, signs, rotation_block).T
        upper = _inverse_cholesky((h + h.T) * 0.5, damp)

    codes = torch.empty(W.shape, dtype=torch.int8, device=W.device)
    scales = torch.empty((W.shape[0], n // GROUP), dtype=torch.float16, device=W.device)
    for start in range(0, W.shape[0], row_chunk):
        stop = min(start + row_chunk, W.shape[0])
        transformed = (_rotate(W[start:stop], signs, rotation_block)
                       if rotation_block is not None else W[start:stop])
        working = transformed.reshape(-1, n // GROUP, GROUP)
        chunk_codes, chunk_scales = _least_squares_groups(working)
        if upper is not None:
            working = working.reshape(stop - start, n).clone()
            for left in range(0, n, GROUP):
                right = left + GROUP
                scale = chunk_scales[:, left // GROUP].float()
                errors = torch.empty((stop - start, GROUP), dtype=torch.float32, device=W.device)
                for col in range(left, right):
                    value = working[:, col]
                    q = torch.where((scale > 0) & (value.abs() > scale * 0.5),
                                    value.sign(), 0).to(torch.int8)
                    chunk_codes[:, left // GROUP, col - left] = q
                    error = (value - q.float() * scale) / upper[col, col]
                    errors[:, col - left] = error
                    if col + 1 < right:
                        working[:, col + 1:right] -= error[:, None] * upper[col, col + 1:right]
                if right < n:
                    working[:, right:] -= errors @ upper[left:right, right:]
        codes[start:stop] = chunk_codes.reshape(stop - start, n)
        scales[start:stop] = chunk_scales
    return TernaryImage(codes, scales, signs, rotation_block)
