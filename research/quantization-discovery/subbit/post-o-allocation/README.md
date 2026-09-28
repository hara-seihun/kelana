# Allocate Q head precision against the complete O response

The [mixed-head study](../head-rate/README.md) chooses eight of sixteen rank-88 Q heads for three-bit left codes by sorting independent head attention-KL gains. That assignment is exactly optimal for its train KL objective. It does not optimize the response after O sums the heads. At the same 106,898-byte image rate, a train-only post-O assignment improves the held post-O relative squared error from .024280 to **.022787**. Even heads score .023471. Held attention KL also moves from .100332 to .100268, but that tiny difference is not why this assignment was chosen.

## Quadratic whole-consumer construction

Freeze the two-bit and three-bit left images, shared four-bit right factor, original K/V/O, original input activations and the attention normalization. For each input position let `b` be the two-bit output after O, `t` the original output, and `d_h` the change after O when only head `h` switches to three bits. Q heads have independent attention softmaxes and value responses; O is linear across concatenated head responses. Thus for any binary selection `z`, the real-arithmetic response is `b + sum_h z_h d_h` and its squared error is

`||b-t||² + 2 sum_h z_h <b-t,d_h> + sum_{h,j} z_h z_j <d_h,d_j>`.

The cross terms matter. We form this Gram matrix on eight 256-token training windows, enumerate all `C(16,8) = 12,870` fixed-cardinality masks, and select the minimum. This is the global minimum **within the frozen two-choice family, exactly eight upgraded whole heads, these training observations and the real-additive squared-output surrogate**. It is not an optimum for unfrozen codewords, attention KL, gold loss or the complete model. The FP32 consumer's O accumulation can round differently from the separately projected head sum. The four measured arms differ between quadratic and actual FP32 error by at most `3.20e-9` on validation; the allocation uses the quadratic, and all reported held consumer metrics replay the actual attention and O map.

Each selected head switches 128 rows x 88 left codes from two to three bits, costing 1,408 bytes. The saved packed image has 106,898 paid payload bytes including mask, scales, shared right factor and shape descriptor, or .407784 matrix BPW. It uses the same 270,336 factor terms per query as the uniform images. The offline Gram and enumeration are training work; online mixed-bit extraction, grouped dispatch, two factor passes, scratch and boundary conversion have not been measured. No inference speedup or complete-model quality follows from a CPU fit.

| Train-selected eight three-bit heads | Train post-O error | Held post-O error | Held attention KL |
| --- | ---: | ---: | ---: |
| Post-O quadratic: 0,1,2,4,5,7,10,13 | **.003005** | **.022787** | .100268 |
| Attention-KL top eight: 0,2,4,6,8,10,11,13 | .003194 | .024280 | **.100332** |
| Even heads: 0,2,4,6,8,10,12,14 | .003253 | .023471 | .100640 |
| Reverse attention-KL gain | .004190 | .023623 | .104986 |

The post-O selection cuts held squared error by 6.15% against attention-KL selection and 2.91% against even heads at identical paid bytes and factor terms. The held-only post-O oracle substitutes head 12 for 13 and scores .021972. It is a diagnostic, never the selected image. The gap warns that eight training windows still do not settle allocation under new text or quantized upstream activations. The current next experiment is fresh independent captures and whole-model continuation with the two equal-rate masks; spend native mixed-bit dispatch work only if the quality persists.

`allocate.py` reconstructs responses from the pinned Qwen3-0.6B layer-0 fixture and frozen images. It records source, model, fixture and input-image hashes, training and held scores, exact selected mask and packed-image hash under `/path/to/workspace/data/kelana-subbit/post-o-allocation/`. `train.json` selects the mask; `validation.json` reads that mask and also records its own oracle separately. `run-train.log` and `run-validation.log` retain command output. No GPU or resident service was used.

```sh
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=1 $P research/quantization-discovery/subbit/post-o-allocation/allocate.py --split train
OPENBLAS_NUM_THREADS=1 $P research/quantization-discovery/subbit/post-o-allocation/allocate.py --split validation
```
