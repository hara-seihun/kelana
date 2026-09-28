# Coupled proposals, real decision boundaries and continued state

The fifth round pushes the full decoding loop rather than only increasing candidate count. Three parallel workers tested prefix-aware training, cost-fitted dispatch and retrieved continuations. The parent integrated the useful mechanisms, measured continued output and tested forced-span execution under two different grammar contracts. [coupled-results.json](coupled-results.json) contains the aggregate receipts; [summarize_coupled.py](summarize_coupled.py) rebuilds them from the data owner.

## Broader online panel

The fourth round's four-prompt result was 1.39x against its FP32 serial baseline. A new eight-prompt panel gives the original residual tree 34.54 versus 30.30 tokens/s, only 1.14x. All eight generated paths and final next decisions match. The gain depends on the prompts, so neither number should replace the other.

The following fifth-round arms use those same eight prompts, 32 emitted tokens per prompt, the FP32 arithmetic target and the complete paid cycle. Only the retrieval comparison has two separate opposite-order panels; these are sixteen runs of eight prompts, not sixteen independent prompts.

| Comparison | Paired serial tokens/s | Learned 18-node tree | Augmented 18-node tree |
| --- | ---: | ---: | ---: |
| Direct producer, combined forward/reverse panels | 30.12 | 36.75 | 38.35 with one copied edge |
| Rollout-trained direct producer, one panel | 30.25 | 39.51 | 40.66 with one copied edge |

Every emitted token and final next-token decision matches the corresponding serial reference. The combined original-direct retrieval arm uses 352 target calls for 512 tokens, versus 370 calls for the learned-only tree and 512 serial calls. It is 4.35% faster than the learned tree and 1.273x its paired serial baseline. With rollout training, the combined arm uses 169 calls for 256 tokens and reaches 1.344x its paired serial baseline. The producers ran in separate panels, not as a synchronized head-to-head race. These remain single-machine short-context PyTorch results. The device wrapper reports other host work during the panels.

The target is still the pinned BF16 checkpoint promoted to FP32 arithmetic. These numbers are not lossless BF16 throughput and are not results against an optimized native serving engine. The [base online report](README.md) specifies prefill exclusion, full-head verification, masks, KV adoption and synchronization.

## Retrieval becomes cheap enough to use

The [retrieved-span worker](../retrieved-spans/README.md) searches only the visible prompt/generated prefix and the training corpus. The already-computed target first token is an explicit input. No later target token enters retrieval. The online graft reserves a single edge after that root for the top retrieved continuation, then fills the remaining slots from the learned tree in its original order. Duplicate prefixes use one slot. The total remains eighteen nodes, and all accepted tokens still go through the target verifier.

The initial Python query took about 6 ms, more than the learned drafter. Keeping that implementation would have erased the small candidate-quality gain. Batched backward comparisons and a direct token-offset index reduce paired query time to 0.0625 ms with exactly the same ranked candidates in 265 checks. Resident index storage falls from 30.22 MB to 20.75 MB. The online cycle pays lookup, graft construction and any learned work that the graft displaces. Its original-direct draft phase averages 1.40 ms versus 1.15 ms without retrieval in the two combined panels.

Index construction and loading happen once outside generation timing, just as model loading does. Each online receipt separately records that preparation time, resident bytes and token-cache hash. The index is reusable across requests and generations; a one-shot process must add its startup cost. The 96x query improvement is not a 96x decoder gain. It makes a previously uneconomic proposal source usable.

This is a useful instance of the compute/bandwidth idea. The cheap producer supplies a complementary candidate that the neural ranking missed. Spending all spare compute on more candidates from the same ranking had not done that. Prompt/corpus copy proposals are established speculative-decoding techniques; this experiment measures their role inside this particular jointly priced loop.

## Training on states that generation actually visits

The loss-weighting and root-conditioning experiments in [prefix-producer](../prefix-producer/README.md) did not justify a replacement. Early-position weighted fitting improved validation but lost on the original test panel. Giving every position the known root through 5,120 extra weights failed to beat the unchanged producer on validation.

We then changed the training distribution rather than adding another scoring tweak. [capture_rollouts.py](capture_rollouts.py) generated sixteen tokens from each of 512 fresh training-corpus contexts using the FP32 target. Their starting windows exclude both previous training captures. Each trajectory supplies eleven causal hidden-state anchors with a retained root and five residual labels, for 5,632 rows. The rows within one trajectory are correlated. Hidden states are saved in FP16 for approximate draft training; this is not a bitwise target-state interchange format. Capture took 34.19 seconds after model loading.

The [rollout producer](../rollout-producer/README.md) fine-tunes the existing direct model with a declared 1:1 mixture of original and new rows. Validation coverage selects step 160 from 20, 40, 80 and 160, including the unchanged model as a control. No inference architecture, parameter count, head storage or operation count changes. The old 32-context BF16 test fixture loses slightly at eighteen nodes, but the continued FP32 eight-prompt panel improves to 39.51 tokens/s, or 40.66 with retrieval. Both findings are retained. A static initial-prefix proxy and the states reached during full generation are different evaluation distributions.

This suggests training for useful work along actual rollouts rather than treating every corpus boundary as representative. It does not establish that this particular data mixture is generally optimal. A larger independent continued-generation panel is needed before choosing it for a service.

## Measured-cost allocation still loses online

The [measured policy](../measured-policy/README.md) fits action value on validation using observed target-cycle costs rather than a hypothetical roofline. Its actions vary budget and depth/breadth preference, including an ordinary serial action. A serial choice still pays for the proposal features used to make it. The maintained builder reproduces mass-first baseline trees after an indexing error was corrected during review.

The original direct producer's online comparison is:

| Arm | Tokens/s | Target calls for 256 tokens |
| --- | ---: | ---: |
| Serial | 30.22 | 256 |
| Fixed eighteen-node mass tree | 36.59 | 185 |
| Fixed six-node depth-biased tree | 35.98 | 206 |
| Learned budget/shape policy | 35.10 | 207 |

The router made 57 serial choices, 71 six-node depth choices, 50 eighteen-node depth choices, 15 eighteen-node mass choices and 14 six-node mass choices. It changes its action but does not improve throughput. All paths and final decisions match serial. Its validation cost model and the previously inspected BF16 fixtures did not predict useful choices on these continued FP32 histories. Confidence, a learned value estimate and a plausible cost model are not substitutes for measuring the chosen actions online.

The rule `gain in useful progress > current rate × added elapsed cost` remains the correct fixed-boundary comparison. The estimate of gain is the weak point here. Retain fixed-budget controls rather than promoting adaptive dispatch merely because it sounds more intelligent.

## Forced spans can be fast, depending on the contract

[forced_runs.py](forced_runs.py) defines eight finite JSON strings with three variable fields and a known literal description. It compares one-token state updates against causal prefill of consecutive token-singleton edges. Both methods skip the output head when a token is forced, and both update every emitted token's transformer KV. The target is FP32. Initial prompt prefill and reusable grammar construction are outside generation timing. A terminal next-token decision is checked after timing to test continuation consistency.

For a protocol that explicitly permits only the canonical token-ID encoding of each string:

| Emitted tokens | Actual branch decisions | Serial target calls | Contracted target calls | Serial tokens/s | Contracted tokens/s | Speedup |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 23 | 3 | 23 | 4 | 34.83 | 150.99 | 4.33x |
| 32 | 3 | 32 | 4 | 35.62 | 242.71 | 6.81x |
| 44 | 3 | 44 | 4 | 35.79 | 343.91 | 9.61x |

These are two order-reversed runs per deliberately constructed protocol size. Both arms emit identical tokens and have the same terminal next-token decision. Long deterministic runs turn sequential calls into batched causal work. This is known-token prefill, not zero-cost transformer state updates or a new speculative algorithm.

Then we keep exactly the same eight allowed output byte strings but admit **every** ordinary-vocabulary tokenization whose bytes remain a legal prefix. The tokenizer/grammar intersection comes from the exact [tokenizer-span experiment](../tokenizer-spans/README.md). Now even the literal description leaves tokenization choices:

| Emitted tokens | Branch decisions | Serial calls | Contracted calls | Speedup |
| ---: | ---: | ---: | ---: | ---: |
| 30 | 28 | 30 | 28 | 1.040x |
| 51 | 49 | 51 | 49 | 1.034x |
| 79 | 77 | 79 | 77 | 1.022x |

Again both implementations of each contract agree on emitted tokens and the final next decision. The canonical-token and full-byte-language contracts are different target laws. We do not claim their token paths, state transitions or branch probabilities are equivalent merely because they permit the same final strings. Indexing the tokenizer and preparing the finite grammar are recorded separately; this finite enumeration is not a general JSON-schema implementation.

This distinction sharpens the Kelana question. If a task only requires a valid protocol record, a canonical-token protocol may be a perfectly acceptable design, and the large forced-run gain is available. If the obligation is to preserve the original model's locally byte-masked token law, hidden tokenization choices still affect continuation state. Removing those choices needs a valid state quotient or a differently trained model whose consumer no longer depends on them. A shared output byte prefix alone is not that witness.

## BF16 backend selection is not enough

Fixing PyTorch SDPA to its math backend removes some earlier mask differences, but does not establish path invariance. In the four-prompt repeated BF16 panel, chain6 and tree6 still diverge from serial at position 17 on one prompt. Tree18 matches on that panel. That tree-specific success is not a universal numerical repair. The fifth-round online comparisons therefore keep the FP32 target and retain all BF16 mismatch evidence.

The unfinished numerical task belongs at the target execution contract: consistent attention and reduction semantics across allowed shapes, or an explicitly different target law. We have not installed an approximate heuristic and called it exact.

## Operations

The existing GPU wrapper owns admission, and all stages fit its fifty-second runtime limit. The new data and source snapshots are linked from [/path/to/workspace/data/kelana-speculative/README.md](/path/to/workspace/data/kelana-speculative/README.md). No new service or compute is involved.

Representative commands from the Kelana root:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
S=$PWD/research/speculative-maps/online/experiment.py
$B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" "$S" --contexts 8 --tokens 32 --dtype float32 --producer direct --methods serial,tree18,graft18 --tag fp32-retrieval
$B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" "$S" --contexts 8 --tokens 32 --dtype float32 --producer rollout --methods serial,tree18,graft18 --tag fp32-rollout
$B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" research/speculative-maps/online/forced_runs.py
$B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" research/speculative-maps/online/forced_runs.py --grammar byte
python3 research/speculative-maps/online/summarize_coupled.py
```

The summarizer reads all retained fifth-round panels. Their receipts record exact arguments and source hashes; logs preserve admission conditions. The parent owns publication of this combined round, including negative model and policy results.
