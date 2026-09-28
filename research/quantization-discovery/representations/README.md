# Quantization representations and executable decompositions

There is no reason to assume that `weight = small scalar code × group scale`
is optimal for either storage or execution. the project lead commissioned this round on
September 23, 2026 to investigate alternatives and bring the existing research
together. Start with the [existing-work map](MAP.md), organized by encoded
object, scale placement, direct consumer, access pattern and acceptance level.
The [synthesis](SYNTHESIS.md) compares the new results and their limits. The
[research brief](BRIEF.md) gives the round's questions and coordination.

## The object being optimized

A candidate is a stored model image plus a program accepting the actual input
representation and producing the required observation. It can encode vectors,
factors, a dictionary, an operator, a recurrent state or an entire region. It
need not reconstruct individual weights or a recognizable intermediate.

Compare four costs separately:

1. Held complete-model loss, or the precisely stated smaller observation.
2. Physical model and runtime-state bytes, including all metadata and padding.
3. Recurring execution, including input preparation, addressing, reductions
   and live boundary conversions.
4. Offline conversion effort and calibration data.

The scale may move into an exponent, table, activation, accumulator or another
consumer. It is removed only if the complete map no longer pays its
information or computation elsewhere. Conversely, a stored scale need not
mean a floating multiplication in the hot loop. The compact scaled-FP16 work
in the map already demonstrates that distinction.

No format is declared globally optimal. An exact search can certify a frozen
finite family; different budgets, hardware and consumers produce different
frontiers. Even a native local win still needs its complete-model quality and
full-path cost.

## Current round

Six GPT-6 Sol researchers returned independent runnable experiments. The table
links their reports, including controls that rejected otherwise attractive
representations. Each report owns its source, measured costs and provenance.

| Area | Question | Worker thread |
| --- | --- | --- |
| [Vector geometry](vector-geometry/README.md) | A one-byte polar code beats scalar/scale controls on real weight pairs and a partial real-input SiLU map; a linear anisotropic observation reverses the ranking. | `357a75a0-4fde-4feb-8ae8-f17c3332ec90` |
| [Additive programs](additive-programs/README.md) | Shared template plus residual wins on planted correlated rows and loses to five-bit scalar on actual Qwen rows. | `b248e25e-a0fb-4717-b54f-85fbe503b59f` |
| [Joint operators](joint-operators/README.md) | A generic bilinear gate contracts to a smaller, more accurate direct quadratic image. The polynomial shortcut loses on SiLU. | `f2a13999-81a2-4d17-a60d-25a3af591485` |
| [Joint operands](joint-operands/README.md) | One diagonal improves Q4/Q4 response across 16 actual routed experts while preserving their shared input code. Original GGUF/Q8 is much better. | `c8f96faf-a953-45f1-9546-b97fd3b74010` |
| [Entropy and execution](entropy-execution/README.md) | Exact paged scales save 2.38% of a real Bonsai image but slow the measured native dot reader. | `ed0f7c54-c4f1-48af-a6ee-ac6dc3bc9da2` |
| [Response dictionaries](response-dictionaries/README.md) | Real eight-trit motifs show no reuse advantage over an independent-trit control; learned small dictionaries have large held error. | `0bd3abda-b2c0-443f-9b72-9a0e8910210e` |

The separate [real paired-repair experiment](../../ternary/paired-repair/README.md),
owned by thread `6b89d4a6-bcc9-4203-af4a-015b1cc3d971`, is complete. It screened
139,300 local pairs and compared six full-model nominees with matched singles
and scale-only edits. A proposal-panel interaction did not survive separate
text. The frozen paired image worsens test NLL from 4.646432 to 4.646920 and
validation from 4.733112 to 4.733498 at unchanged 128,678,649 payload bytes and
1.72708553 BPW. The source `expanded-scale384` remains selected. This is repair
within the existing format, not a constraint on the new decomposition families.

## Full-layer transfer

The [complete gate/up study](vector-full/README.md) takes joint pair codes to
all 3,072 hidden channels at early, middle and late Qwen3-0.6B layers. It uses
fresh inputs from the selected complete ternary image and compares lower
index rates, fitted scalar controls and complete-model substitutions. The
[direct native reader](vector-native/README.md) measures the packed
index-to-gate/up-to-SiLU path separately. These reports distinguish local
response, whole-model loss and native speed rather than treating one as proof
of another.

## Response-aware fitting

The [response search](vector-response/README.md) fits actual packed indices
against the full nonlinear MLP output, with a response-fitted scalar control.
The three-bit pair's layer-0 replacement improves complete-model test NLL
from 4.792683 to 4.702836 at identical bytes, and validation improves too.
It still loses to selected ternary at 4.646432. The eight-bit pair repair
worsens held quality. This establishes a useful local repair mechanism, not
a replacement model or a universal advantage for joint codes.

## Adding findings

Detailed reports stay with the source that produced them. Link the closest
controls and state what changed in the encoded map, rather than adding another
unstructured chronological result feed. The round synthesis should distinguish
existence witnesses, practical converters, paid native programs and complete
model results. A failed family remains useful evidence with its restrictions
stated; it is not a rejection of all decompositions.
