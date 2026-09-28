# A mixed three/four-bit key coordinate

A signed three-bit post-RoPE key cache stores 96 bytes per occupied token/layer instead of the frozen nibble cache's 128. Its attention quality is too far behind at that rate. Spending fourth bits on the coordinates that change the **causal score** most recovers much of the gap: at 112 bytes, a train-selected group allocation scores .282826 versus .275431 for the full nibble layer-0 cache, and .345606 versus .332396 at layer 14. This is a measured key-cache rate/attention-quality trade, not lower weight BPW or native acceleration.

| Key bytes/token/layer | Layer 0 held causal KL | Layer 14 held causal KL | Selection |
| ---: | ---: | ---: | --- |
| 96 | .331007 | .417616 | three bits throughout |
| 104 | .293321 | .354185 | eight promoted bytes across eight groups |
| 112 | .282826 | .345606 | sixteen promoted bytes across eight groups |
| 120 | .279187 | .338131 | twenty-four promoted bytes across eight groups |
| 128 | .275431 | .332396 | full frozen nibble control |

The two-head teacher-to-candidate KL averages four previously inspected, original-producer 256-token validation windows for each of layers 0 and 14. The same paid binary Q/K, selected 128 RoPE planes, full raw K normalization, both query heads, and frozen four-bit key image serve as controls. The three-bit arm trains one FP16 step per selected key coordinate against eight train windows, choosing a clipping quantile from .99, .995, .999 and 1 and a raw or train-centered origin by sampled finite causal KL. This gives each bit width its own step, rather than cutting a bit off the four-bit code. For each coordinate, a train-only individual finite-KL swap ranks promotion to the frozen four-bit codebook. An exact eight-group dynamic program chooses 0, 8, 16, 24 or 32 promotions per group at each whole-byte budget, conditional on those orders. Its 112-byte allocation improves the uniform sixteen-promotions-per-group control from .286991 to .282826 at layer 0 and .348075 to .345606 at layer 14. It is not a global optimum over coordinate subsets or codebooks.

Let `c = clamp(round((k-b)/s-0.5),-4,3)`. Decoding `s*(c+0.5)+b` gives eight symmetrically placed levels. Both the half-step and center are constant across cached positions of a group and disappear in real causal softmax; each observing query instead multiplies its coordinate by `s` once and scores integer codes directly. Promoted coordinates use the frozen nibble arm's `c4` and its own step, with the same constant-center cancellation. The query prepares 512 scaled coordinates/token/layer, quantizes to dynamic signed eight-bit, and splits each query code into two signed nibbles exactly as in [the direct query consumer](../nibble-query-lowering/README.md). The script checks the integer identity `z·c = lo·c + 16 hi·c` for every replayed arm. Score accumulation fits int32. The reported KL includes this quantized query; with a floating prepared query the all-three-bit points score .330907/.417398. This is real softmax arithmetic, not a claim of bit-identical FP32 logits.

Each group packs its 32 base labels into 12 bytes, four three-byte octets, and a fixed fourth-bit plane for its promoted coordinates into 0–4 more bytes. Its 0–32-coordinate mask costs up to 32 static bytes/layer across the eight groups. The selected FP16 steps occupy 512 bytes/layer, and centers at most another 512; the paid Q/K factor image and full 1,024-row K norm producer do not change. Each key write still quantizes 256 coordinates and packs three-bit fields plus its selected fourth bits. Each scored key needs 1,024 signed-nibble products across both heads, just like the four-bit control, *after* three-bit extraction/sign extension and mixed-lane assembly into registers. This is not a cheaper score than nibble; the case for the format is 12.5% less key traffic at 112 bytes and the attained attention error. Do not expand the cache into int4 in memory and call its timing direct. Unpacking, gather placement, query preparation, register use and the full producer must be charged in a native experiment.

The 96-byte arm loses substantially despite using all eight three-bit states and refitting its steps. The useful next question is whether a direct mixed-lane native consumer at realistic occupied contexts saves enough cache traffic to pay its irregular unpack, *after* fresh quantized-upstream and gold-loss acceptance. If it does not, retain the 128-byte nibble or 256-byte centered int8 cache. The old four-window original-producer KL cannot choose a serving default.

`three_bit.py` writes train candidates and per-group/held-window direct-integer scores; `mixed.py` writes each promotion order, individual train swap effects, and all uniform budgets; `allocate.py` exactly allocates group byte counts against their recorded train curves. Full receipts with source, model, capture, paid-image and parent hashes live under `/path/to/workspace/data/kelana-subbit/key-three-bit/`. Reproduce on CPU without the GPU reservation:

```sh
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  suffix=$(printf '%02d' "$layer")
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-three-bit/three_bit.py --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/key-three-bit/layer${suffix}.json"
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-three-bit/mixed.py --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/key-three-bit/layer${suffix}-mixed.json"
  python3 research/quantization-discovery/subbit/key-three-bit/allocate.py --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/key-three-bit/layer${suffix}-allocation.json"
done
```

No GPU, Bonsai executable or resident service changed.
