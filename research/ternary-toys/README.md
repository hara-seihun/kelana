# Tiny experiments for cheaper low-bit computation

the project lead commissioned twelve GPT-6 Sol researchers on September 23, 2026 to explore
alternatives to straightforward model training. All twelve returned runnable
CPU experiments, reports and results. The nonlinear-gauge experiment also
includes an off-manifold follow-up with finite-precision boundaries.

Read the [synthesis and proposed transfer tests](SYNTHESIS.md) first. The
[shared brief](BRIEF.md) records the starting evidence, quality target and
resource coordination. Each researcher chose its toy and method from an
initial intuition. The commissioning thread is
`eae4f1b8-8088-480a-80b8-605ac5765643`.

## Results

These scores belong to different toy maps and must not be ranked against one
another. None changes the complete Qwen image or its measured language loss.
Each linked report states the map, controls, costs and limitations.

| Experiment | Concrete finding | Scope |
| --- | --- | --- |
| [Composed error](composed-error/README.md) | Local codes conserve the wrong coordinate sum. Coupled trit/scale repair cuts held MSE .46674 to .09171 beyond a proven scale-only floor. | Train-selected nonlinear witness, exact 729-image family. |
| [Observed logits](observed-logits/README.md) | One trit fitted to both current and future softmax observations halves excess NLL .150685 to .075342. | Exact four-state population, paid affine encoder and table. |
| [Nonlinear gauges](nonlinear-gauges/README.md) | Shared residual rotation plus up/down gain gives exact planted ternary blocks and wins on two off-manifold draws. Weight-SSE selection can lose. | RMSNorm/SwiGLU, FP16 boundary stress, no runtime saving. |
| [Discrete geometry](discrete-geometry/README.md) | Radius-two search improves mean held NLL .553739 to .551065; 14 single-flip minima have beneficial pairs across positive barriers. | 40 gated teachers, exact single-flip and full-oracle controls. |
| [Rate allocation](rate-allocation/README.md) | Joint seven-byte images get .035156 error versus .941406 for downstream-weighted allocation. A nine-byte four-bit pair does better still. | Linear residual map, exact declared catalogue and side-byte accounting. |
| [Reachable quotients](reachable-quotients/README.md) | Coefficient-optimal producer loses required distinctions. Worse coefficient fit is exact; ordinary rounding plus query-temperature correction is also exact. | All 27 inputs through two attention steps, consumer-side control. |
| [Packed realization](packed-realization/README.md) | Byte labels carry exact residual state across eight native stages. Full conditional-route fusion is 2.22 times faster than staged lookup at 32 times the table bytes. | AVX-512, 27 states, shared route across 64 lanes. |
| [Recurrent stability](recurrent-stability/README.md) | A 3.064% matrix error removes stabilizing feedback and creates persistent false state. A paid link repairs response better than scale recovery. | Chosen two-state gated recurrence, linear and tanh trajectories. |
| [Calibration sufficiency](calibration-sufficiency/README.md) | Three weighted witnesses choose the optimum; 10,000 random draws choose wrongly 22% of the time. | Known three-state support and masses, amplified rare state. |
| [Coupled codebooks](coupled-codebooks/README.md) | Paired templates win 8/8 motif cases and lose 8/8 unstructured cases at the same four-byte budget. | Exact code search, more arithmetic than scalar ternary. |
| [Tied consumers](tied-consumers/README.md) | Anchor logits recover an exact ternary tied model. Independent embedding fitting has a provable obstruction even with a real-valued body. | Constructed six-token complete map, 18-byte joint image. |
| [Routed sums](routed-sums/README.md) | Actual quantized-route fitting gets .09284 held MSE versus .15439 for original-route joint fitting and .16861 for independent experts. | Top-two of three nonlinear experts, 12 input panels, partial weight quantization. |

## Reproduction and provenance

Each report gives its command and links compact result receipts. Python toys
use standard Python, NumPy or SciPy. The existing scientific interpreter is
`/path/to/workspace/data/fish-s2-pro/venv/bin/python`. Set `OPENBLAS_NUM_THREADS=1`
and `OMP_NUM_THREADS=1` for concurrent CPU experiments. The packed experiment
uses C++20 and requires AVX512VBMI. No model download or GPU is needed.

Parent review inspected the reports and source, including the strongest
controls, storage bills and selection protocol. Recorded results come from
the workers' executions; the parent did not rerun the entire suite.

| Area | Worker thread | Source commit |
| --- | --- | --- |
| Composed error | `8572ab62-af1e-4bc5-baea-b55b42079bbc` | `975670c8` |
| Observed logits | `acfdc855-d66a-4545-8018-5364112d2837` | `31e524af` |
| Nonlinear gauges | `fb276d86-5d77-4a87-bd7a-a07c34cc9ad1` | `3749db68`, `9181edee` |
| Discrete geometry | `bd640fdc-2070-451c-b90a-23961a9c1aa7` | `c89dd3c2` |
| Rate allocation | `5c0dbf82-fc75-4ed5-a233-880e61789ffe` | `137acb6b` |
| Reachable quotients | `a5c49e8b-89b2-4cc4-8915-d0d9da15f506` | `51cc0ae0` |
| Packed realization | `843083c8-9c49-48ec-9ee0-7f4d8d40c65c` | `7d3b1268` |
| Recurrent stability | `ba7d90fd-b9ad-4d9b-9c15-a12ad28c747b` | `5e52ba96` |
| Calibration sufficiency | `f5d15a7b-52b3-4bf0-a1ab-ea02deafe2cc` | `91fc1171` |
| Coupled codebooks | `33cb0f18-0408-46c9-bc55-6d2fea0a6bda` | `02b0ab6d` |
| Tied consumers | `243b0fe4-6280-47c8-a7a3-fe21340b1f20` | `1dcfd63c` |
| Routed sums | `7f73b43b-68b4-45ca-98fc-4b6bbf6c216d` | `957c4240` |

The existing [complete ternary pilot](../ternary/README.md) remains the transfer
reference. Structural matches, conversion efficiency, native realization and
whole-model quality are separate results. The next tests in the synthesis are
proposals, not completed model improvements.
