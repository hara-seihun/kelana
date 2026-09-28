# How few quantized hidden coordinates separate a trained region?

On the twelve fixed 27-state perturbation cubes in [the trained-region study](../../discovery/joint-observer/TRAINED.md), **two A8 hidden codes suffice and are necessary** to distinguish all inputs, if we first compute the complete hidden transform and its 128-wide max-based quantizer. With A4 hidden codes, no pair suffices; a greedy separating set uses six or seven coordinates. These are results about *information at an already computed boundary*, not fast FFN programs.

There is a trap here. Each of the **136 block scales individually separates all 27 states** in every cube in this CPU float64 evaluation. Rounding just those scales to FP32 leaves 135 or 136 of the 136 individually injective, depending on the cube. This does not emulate the FP32 producer. Calling one floating scalar a one-coordinate solution hides the work: each scale is the maximum over 128 transformed hidden entries, and all 136 scale blocks vary with the input. A proposed exact output consumer that keeps the ordinary quantizer still has to construct and carry these dynamic scales. One cannot infer an instruction saving from a sparse code witness or from the cardinality of the scale's image.

## Contract and result

The input, weights and arithmetic follow `research/discovery/joint-observer/trained.py`: trained PTQ1_0 layers 0 and 10, positions 0 and 127, three prescribed triples of fixed-scale A8 input perturbations each, all 27 states. Gate/up projections and SiLU feed the signed normalized 17,408-wide Hadamard, then an A8 (`[-127,127]`) or A4 (`[-7,7]`) max-based quantizer. The observation for this experiment is *which of the 27 inputs occurred*, recovered from chosen integer hidden codes. It is stronger than agreement with a possibly colliding final output; the trained study found 27 distinct 5,120-wide output vectors on each cube. The test deliberately **excludes the dynamic scales from the code witness**, reporting their dependence separately. It does not emulate HIP FP32, FMA contraction or native quantizer ties.

| boundary | exact lower bound | checked upper bound | cases |
| --- | ---: | ---: | ---: |
| A8 codes alone | 2 | 2 | 12/12 |
| A4 codes alone | 3 | 6 or 7 | 12/12 |
| any one float64 scale block | 1 | 1 | 12/12, all 136 blocks each |

The A8 coordinate pairs differ by case. For example, layer 0, position 0, input triple `(2,17,93)` uses hidden coordinates `(13158,14923)`. The A4 bound is not a claim that six coordinates are minimal. Both the lower bound of three and upper bounds of six or seven are statements over *all 17,408 hidden coordinates* of each recorded finite cube, not a sample of hidden features.

## Why the bounds check

There are 351 unordered input pairs. A coordinate's separation mask has bit `(i,j)` set precisely when its codes differ on inputs `i` and `j`. Deduplicate masks, then greedily union masks until all 351 bits are set. The recorded chosen coordinates and 27-by-k code table let a reader check the witness without the model. Exhausting all one-coordinate masks proves the A8 lower bound. For A4, exhaust every distinct pair of masks and confirm no union covers all 351 bits. The same two-mask search is available for any cube where the greedy solution is longer than two. A3-bit synthetic cube and the collision and one/two-coordinate cases have regression checks.

This is a finite exhaustive CPU certificate, not a lower bound on arbitrary ISA programs or on how many *registers* a cleverly relabeled computation needs. A different producer can emit a different coordinate. A floating scale's 27 distinct byte patterns merely give an injective label on this fixed perturbation cube; realizing a decoder for arbitrary real prompts from that label is another problem.

## Executable cost and next experiment

The selected code coordinates still depend on the whole gate/up computation and the 17,408-entry signed Hadamard. In the deployed quantizer, keeping its full code-and-scale interface entails 136 dynamic block maxima over 128 entries apiece, 136 scale outputs or **544 FP32 bytes per row**, and quantization of whichever hidden codes the consumer reads. This is an accounting identity for that implementation, not an ISA-independent lower bound: a joint producer/consumer may avoid materializing the scales. A sparse witness has no measured GPU or whole-model speedup.

The next useful search should move the observation *before* the full hidden Hadamard and max reductions, then show a cheap way to compute the selected label and the final 5,120 outputs or their actual downstream observation. A concrete native experiment would first price computing one selected scale block and its 128-entry reduction **without** the other 135 blocks, then compare the cost of a weight-prepared continuation against the ordinary full hidden-to-down path. The 27-entry per-context lookup is not a fixed trained-weight table: its entries depend on the runtime background activation.

Run each source/data-pinned case separately, usually under a few seconds:

```sh
OPENBLAS_NUM_THREADS=4 python3 research/ffn/quantized-separators/separators.py --layer 0 --anchor 0
OPENBLAS_NUM_THREADS=4 python3 research/ffn/quantized-separators/separators.py --layer 0 --anchor 127
OPENBLAS_NUM_THREADS=4 python3 research/ffn/quantized-separators/separators.py --layer 10 --anchor 0
OPENBLAS_NUM_THREADS=4 python3 research/ffn/quantized-separators/separators.py --layer 10 --anchor 127
python3 -m unittest discover -s research/ffn/quantized-separators -p 'test_*.py'
```

The [four result records](results/) retain manifest and source SHA256, complete witnesses, cover masks, scale-change counts, FP32-rounded scale injectivity and code/scale table hashes. Model data remain under `/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench`. There was no GPU or runtime change.
