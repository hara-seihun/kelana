# NanoQuant binary-factor comparator

[Joint Q/K/V first factors](shared-qkv.md) compare common versus separate input transforms under matched aggregate storage and signed-accumulation budgets.

This is an **ADMM initialization-only adaptation**, not a reproduction of NanoQuant's reported model perplexity or calibration budget. It uses the authors' unmodified `factorize_admm_nanoquant` from [SamsungLabs/NanoQuant](https://github.com/SamsungLabs/NanoQuant), commit `a9e0a430881ff80d83b622c3129e330dc33c04f5`, Apache-2.0. `nanoquant_admm.py` is byte-for-byte the upstream `src/nanoquant/core/admm_nq.py` at that commit, SHA256 `7145ba305ad6f3e1303dc618722c71e210309160ea3a1c6f6b16bb646009c1a6`. Its license is [LICENSE-Apache-2.0](LICENSE-Apache-2.0). The source paper is [arXiv:2602.06694](https://arxiv.org/abs/2602.06694).

The pinned Qwen3-0.6B weights are `Qwen/Qwen3-0.6B` revision `c1899de289a04d12100db370d81485cdf75e47ca`, in `/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b`. The matched comparison uses `/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/`, whose manifest pins the model and eight nonoverlapping 256-token train windows, four validation windows and separate untouched test windows. We fit all 16 supplied matrices at target .55 BPW and three representative matrices across .55/.80/1.00 BPW, using 2,048 actual BF16-producer train-token inputs and 1,024 validation-token inputs per fit. Validation is held out from factor fitting. `activations.py` remains available for a lightweight layer-0 train/test extraction with 512 tokens per split; those earlier runs are not the matched comparison. The input norm uses the train inputs' squared channel means, with 0.4 shrinkage. The output norm is **uniform ones**, whereas the published calibration collects output loss gradients. This difference matters. No nonfact block reconstruction, binary/scale tuning, block propagation or global KD was run. The authors' defaults include 128 calibration sequences of length 2048, 400 ADMM outer iterations, 5 inner iterations, and 8 epochs each of several tuning stages. Here each independent matrix/rate got 400 outer and 5 inner ADMM iterations, seed 0, on 8 CPU threads. The 22 matched-fixture solver timings totaled 152.2 wall seconds on 8 CPU threads; loading fixtures and Python startup are outside that sum. The train and validation token counts are 2,048 and 1,024 for each fit. No GPU reservation was taken.

## Measured results

Relative squared errors are `sum((prediction-reference)^2)/sum(reference^2)`. Held-out response uses 1,024 real validation-token projection inputs, with the actual serialized factor signs and FP16 scales unpacked before evaluation. Matrix weights are BF16 originals. The ADMM continuous-weight error differs slightly from the deployed signed-factor error; the table reports the latter. No row measures language-model loss, perplexity or AMD throughput.

| Matrix | Target BPW | Rank | Payload BPW | Factor bytes + scale bytes | Weight squared error | Held-out response squared error | ADMM seconds |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| layer 0 q_proj 2048×1024 | .55 | 352 | .53906 | 135,168 + 6,144 | .49766 | .09666 | 4.60 |
| layer 0 q_proj 2048×1024 | .80 | 512 | .77344 | 196,608 + 6,144 | .37661 | .07368 | 7.87 |
| layer 0 q_proj 2048×1024 | 1.00 | 640 | .96094 | 245,760 + 6,144 | .30172 | .06025 | 9.16 |
| layer 14 down_proj 1024×3072 | .55 | 384 | .52083 | 196,608 + 8,192 | .52525 | .44383 | 6.95 |
| layer 14 down_proj 1024×3072 | .80 | 576 | .77083 | 294,912 + 8,192 | .38453 | .31712 | 10.92 |
| layer 14 down_proj 1024×3072 | 1.00 | 736 | .97917 | 376,832 + 8,192 | .29658 | .24136 | 15.20 |
| layer 27 q_proj 2048×1024 | .55 | 352 | .53906 | 135,168 + 6,144 | .49727 | .11579 | 4.65 |
| layer 27 q_proj 2048×1024 | .80 | 512 | .77344 | 196,608 + 6,144 | .37601 | .08859 | 7.45 |
| layer 27 q_proj 2048×1024 | 1.00 | 640 | .96094 | 245,760 + 6,144 | .30088 | .07104 | 8.91 |

The complete .55 BPW sweep exposes a failure of weight-space error as a response proxy. The layer 27 down-projection has .57961 weight squared error but only .03420 validation-response squared error, while layer 27 attention output has .57511 and .48098. The 16 response errors have median .31484, ranging .03420 to .48098. The results by layer and module are:

| Layer | MLP down | MLP up | Attention Q | Attention O |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .46096 | .45021 | .09666 | .29092 |
| 7 | .44095 | .41965 | .12511 | .47363 |
| 14 | .44383 | .33837 | .09668 | .29132 |
| 27 | .03420 | .15273 | .11579 | .48098 |

This is a reason to optimize activations and consumer structure together, not to extrapolate a Frobenius metric into perplexity. The published method's gradient-weighted norms and reconstruction tuning could change the ranking.

The rank allocator is the upstream `floor32(target * N*K/(N+K) - 16)`, with a minimum rank of 32. The quantized matrix payload is `ceil(R/8)*N + ceil(K/8)*R + 2*(K+N)` bytes; factors use row-major low-bit-first signs, scales use FP16. Shapes and the ZIP container add 1,256 bytes per `.npz` file beyond the matrix payload. This denominator excludes embeddings, uncompressed model tensors, norms, biases, the LM head, runtime scratch and KV cache. Calling it full-model BPW would be wrong. Raw reports and packed arrays live at `/path/to/workspace/data/kelana-subbit/binary-factors/`. The `.npz` image stores dimensions, scales and both factor planes. Its metadata is counted as serialized file overhead, separately from the payload.

## gfx1151 online work map

For one batch-1 projection of an `N×K` matrix at rank `R`, the packed consumer reads at least the two factor planes and `2*(K+N)` scale bytes, then computes `h = V*(x*scale_pre)` and `y = (U*h)*scale_post`. The two stages need `R*(K+N)` signed accumulations, `K+N` scale multiplications and `2*(K+2R+N)` BF16 bytes of minimum input, intermediate write/read and output traffic, assuming an unfused two-kernel pipeline. The q-projection counts are 1,081,344 / 1,572,864 / 1,966,080 accumulations at the three ranks; down-projection needs 1,572,864 / 2,359,296 / 3,014,656. Dense down-projection uses 3,145,728 MACs, but its BF16 instructions may exploit matrix hardware that packed sign/FMA does not. A hypothetical fused consumer holding all `R` intermediate values across the stages could eliminate the `4R` scratch bytes, not the second factor read or accumulation. Placement in registers/LDS, spills, masking, sign unpack, kernel launches and L2 reuse need a real gfx1151 implementation and profiling. The CUDA kernel's throughput is not an AMD throughput receipt.

This is a sharp warning about direct consumption: near 1 BPW the down projection retains **96% of dense MAC count**, plus two scale streams and packed-sign expansion. Merely compressing its storage will not guarantee faster execution. A worthwhile next experiment is a jointly fitted shared first binary factor for Q/K/V so their stage-1 signed reduction and input scale can be consumed once, then separate second factors finish all three outputs. Count the common factor and any extra ranks against all three original matrices. If a packed-label map can feed attention's next operation directly, measure that boundary rather than materializing three BF16 vectors by default.

## Reproduce

```bash
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/binary-factors
O=/path/to/workspace/data/kelana-subbit/binary-factors
F=/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext
for item in layer00-self_attn_q_proj layer14-mlp_down_proj layer27-self_attn_q_proj; do
  $P "$D/compare.py" --fixture "$F/$item.npz" --rates .55 .8 1 \
    --outer-iters 400 --threads 8 --out "$O/fixtures"
done
for fixture in "$F"/*.npz; do
  case "$fixture" in
    *layer00-self_attn_q_proj.npz|*layer14-mlp_down_proj.npz|*layer27-self_attn_q_proj.npz) continue ;;
  esac
  $P "$D/compare.py" --fixture "$fixture" --rates .55 \
    --outer-iters 400 --threads 8 --out "$O/fixtures"
done
```

`compare.py` accepts any matched `weight/train/validation` fixture; alternatively, supply a matrix key and optional train/held-out `.npy` or `.npz` activations, where `.npz` uses the `x` field. It emits rate-by-rate JSON and factor images. If full-model results become available, compare them at the *same model, calibration tokens, kept tensors and measured endpoint*, without substituting these isolated-layer errors for model quality.
