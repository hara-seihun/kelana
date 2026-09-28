# Response-fitted scalar pair scales

The existing layer-0 `scalar_scale8` pair image stores one byte per gate/up pair and sixteen FP16 scales. [response-scalar.py](response-scalar.py) keeps every code index and descriptor unchanged, fits only those sixteen paid scales against the complete BF16 gate/up/down MLP response on actual selected-ternary producer inputs, then exports a new immutable image. Local scoring uses the same selected ternary down projection for the original and fitted scalar images. No FP16 gate/up or BF16 down travels in either image. Both exports have the same 3,145,774-byte physical gate/up payload as the source and decode through `vector-full/codec.py`.

| Train fit positions per 256-token window | Disjoint train check positions | Fit source → fitted | Check source → fitted | Held validation source → fitted |
| ---: | ---: | ---: | ---: | ---: |
| 0:16 | 16:32 | .528175 → .520015 | .508235 → .499633 | .481858 → .474002 |
| 0:128 | 128:160 | .513505 → .501737 | .523416 → .508280 | .481858 → .473776 |

These are relative RMS errors against the original complete BF16 MLP response. Each train fit selects the FP16 scale vector by minimizing complete output error, with four or two prespecified penalties against the original scales. The disjoint train check selects the candidate, including the unchanged-source option. Validation windows 8–11 enter only after export; neither panel uses validation to fit or select scales. The four train windows are 464–467 from the actual selected ternary model. Each split uses the same four windows and positions in every arm. This table measures local response. The [complete-model follow-up](README.md#complete-model-acceptance) also finds lower validation and test NLL for the larger-calibration scalar export, though it still loses to the selected ternary model. No native timing was measured.

[scalar-results.json](scalar-results.json) and [scalar-fit128-results.json](scalar-fit128-results.json) record capture, image, source-checkpoint and common-down hashes, precise positions, candidate penalties, fit/check/validation errors, paid bytes and scale tables. The immutable images and decoder-compatible receipts are at `/path/to/workspace/data/kelana-subbit/vector-full/images/layer00-scalar_response-8bit.{npz,json}` and `/path/to/workspace/data/kelana-subbit/vector-full/images/layer00-scalar_response-fit128-8bit.{npz,json}`. The original remains `layer00-scalar_scale-8bit.npz` there. The data directory is machine-local, not tracked in Git.

Run from the Kelana checkout with the scientific Python environment:

```sh
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=2 MKL_NUM_THREADS=2 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/representations/vector-response/response-scalar.py
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=2 MKL_NUM_THREADS=2 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/representations/vector-response/response-scalar.py --fit-positions 128 --check-positions 32
```

Exports refuse to overwrite existing results. For another run, give it fresh image and report destinations in the script rather than changing or deleting evidence. The experiment uses two CPU threads and no GPU.
