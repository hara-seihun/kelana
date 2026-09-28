# A shared output basis for the two-head narrow-value consumer

The paid rank-28 V/O image has sixteen head-specific `1024 × 28` output decoders. Their sum can instead pass through one shared output basis: concatenate the headwise attended coordinates into `z ∈ R^448`, form `h = Bz ∈ R^k`, then write `Ch ∈ R^1024`. This keeps the already-paid narrow V producer and cache. It never reconstructs a 128-wide value. At `k = 256`, the new output path takes 376,832 factor terms against 458,752, but it adds a 256-coordinate intermediate and another reduction boundary. Including the unchanged V producer, logical factor terms fall from 688,128 to 606,208 per token. These counts are not native time.

The question was whether this extra composition buys enough shared structure to make a **two-bit output factorization** competitive with the existing two-bit output decoder. It does not under response-SVD followed by the existing odd-grid quantizer. The continuous rank limit is surprisingly good, but quantizing its two factors destroys the gain.

## Exact continuous rank limit on the captured producer

For the frozen paid decoder `A ∈ R^(1024×448)` and the eight original-producer train windows' actual narrow, causally attended features `Z ∈ R^(2048×448)`, take the thin QR `Z = QR` and SVD `RAᵀ = UΣVᵀ`. The first `k` singular terms give the exact minimum of `||ZAᵀ − ZBᵀCᵀ||²` over *real* rank-`k` maps, because `R` is invertible on this panel. The minimum relative error against the frozen paid response is the tail energy `Σ_{j>k} σ_j² / Σ_j σ_j²`. The script also applies that train-optimal factorization to four distinct 256-token validation windows and compares both it and the paid decoder to the original attention/O response. The SVD optimum targets the paid response, not the original teacher or held loss. It is not a bitwise FP32 identity.

| Layer | Rank | Exact train paid-response tail | Held error against paid response | Held error against original teacher |
| ---: | ---: | ---: | ---: | ---: |
| 0 | paid 448 | 0 | 0 | .378887 |
| 0 | 192 | .024213 | .043563 | .385821 |
| 0 | 256 | .008723 | .019397 | .378323 |
| 0 | 288 | .005005 | .012509 | .377353 |
| 14 | paid 448 | 0 | 0 | .326195 |
| 14 | 192 | .018875 | .048073 | .325666 |
| 14 | 256 | .008220 | .025520 | .324044 |
| 14 | 288 | .005218 | .017853 | .324007 |

Even rank 256 has a nontrivial 1.9%/2.6% held squared discrepancy from the paid response. Its slightly lower teacher error is cancellation of the paid image's error, not a preservation guarantee. The exact train tail is a rank-family lower bound for reproducing this frozen paid response on these 2,048 rows; it is **not** a lower bound on a new jointly trained V/O image or its teacher loss.

## Paid two-bit factors

The code quantizes the rank-256 factors using the repository's odd four-level code and train-independent row/group scale fitting, with FP16 scales and complete packed image accounting. Output basis `C` has 1,024 rows of 256 codes, and transform `B` has 256 rows of 448 codes. Right V factor bytes and terms stay unchanged. The existing left image stores 147,584 bytes including codes, FP16 row scales and eight descriptors. Two new factor images, including their descriptors, store 117,792 bytes with 32-coordinate scales or 100,384 bytes with 128-coordinate scales. Thus the whole V/O image would be 178,848 or 161,440 bytes rather than 208,640. No weight expansion to int4 is needed for a prospective reader, but no native reader was built or timed.

| Layer | Paid held teacher error | Real rank-256 | Two-bit group-32 | Two-bit group-128 |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .378887 | .378323 | .590752 | .679425 |
| 14 | .326195 | .324044 | .631886 | .726876 |

Group-32 quantization alone produces .33756/.42635 squared discrepancy from the paid response at layers 0/14; group-128 produces .46568/.54705. The extra factorization helps real arithmetic but is fragile under separate nearest-grid fitting. This is a measured negative for the **frozen paid V producer, train-response SVD, and independent two-bit quantization of its factors**, not for co-trained shared output bases. It changes the next question: learn the output basis *inside* the paid two-bit alphabet against composed causal or gold loss, and let the narrow producer move with it. Another SVD truncation or a native lowering of these naive rounded factors is unwarranted.

The CPU reproducer is [`measure.py`](measure.py). The source, model, capture and paid-image hashes, packed factor-array hashes, all ranks, split and per-window errors live in [`data/kelana-subbit/value-cohead-output-rank/`](/path/to/workspace/data/kelana-subbit/value-cohead-output-rank/README.md). Run one layer in a bounded CPU command:

```sh
/path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/value-cohead-output-rank/measure.py --layer 0
/path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/value-cohead-output-rank/measure.py --layer 14
```

There was no GPU run, full-model NLL, native time, Bonsai executable or service change.
