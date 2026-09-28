# Drafting after a retained target token

The first Qwen pilot trained against corpus continuation labels. This experiment instead generates 2,048 six-token greedy continuations with the original BF16 Qwen3-0.6B target, then trains a five-position residual drafter from the target's initial normalized hidden feature and its retained first token. It excludes the pilot's 128 train window starts. Validation and test remain the original separate 32-context target-greedy fixtures. Code is in [experiment.py](experiment.py); [data receipts](/path/to/workspace/data/kelana-speculative/residual-drafter/README.md) keep the capture, checkpoints, hashes and per-context results. No target weight changes or serving verifier are involved.

The residual model has a 1,024-to-256 trunk, five 128-wide states, a learned hidden correction, and a 32-dimensional shared predecessor/successor code. Its output head consists of frozen rows of the target's tied embedding. The vocabulary first takes all 2,561 tokens observed in target-generated training trajectories, then fills to 4,096 or 8,192 using token frequency in the *training* corpus fixture. It never uses validation or test labels to choose rows. An unknown first token maps to the learned unknown code for conditioning, but remains the correct retained root within that context. An unknown residual token cannot enter a proposal. Training uses 200 AdamW updates and residual-only cross entropy, with the lowest validation in-vocabulary loss checkpoint selected among steps 50, 100 and 200. Both panels selected step 200. A prior 512-context capture overfit by step 100; that capture was replaced with the 2,048-context fixture before these reported fits.

Trees have six, 18, 32 or 64 total candidate nodes. The known target token occupies **one node**, leaving five, 17, 31 or 63 newly proposed nodes. The reference heap orders descendants by proposal path probability. The static pool selects 16 tokens from each position's base scores; the adaptive pool selects 16 after scoring each distinct position/predecessor row. Both normalize each row over the entire draft vocabulary. A tree match counts one target-produced exit/bonus token. The raw reported means therefore include one already-known first token and one target bonus; subtract two for newly accepted residual tokens. The original `conditional-s200` tree and the unchanged `first-token-graft` construction from candidate-repair are recomputed on precisely the same held contexts and node budgets.

| Held split / nodes | Conditional s200 | First-token graft s200 | Residual 4,096 static | Residual 4,096 adaptive | Residual 8,192 static | Residual 8,192 adaptive |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Validation / 6 | 2.2813 | 2.5000 | 2.7188 | 2.7188 | 2.6250 | 2.6250 |
| Validation / 64 | 2.6563 | 2.8438 | 3.0625 | 3.0938 | 3.0625 | 3.0938 |
| Test / 6 | 1.9063 | 2.2500 | 2.4063 | 2.4063 | 2.4375 | 2.4375 |
| Test / 18 | 2.0625 | 2.5000 | 2.5313 | 2.5313 | 2.5625 | 2.5625 |
| Test / 32 | 2.1250 | 2.5000 | 2.5938 | 2.5938 | 2.5938 | 2.5938 |
| Test / 64 | 2.1875 | 2.5625 | 2.6250 | 2.5938 | 2.6563 | 2.6563 |

The 4,096-row static drafter reaches 1.0625 newly accepted residual tokens on validation and 0.6250 on test at 64 nodes. The old graft reaches 0.8438 and 0.5625. The larger shortlist reaches 0.6563 on test but costs twice the head storage and projection; its validation 64-node mean matches 4,096. This is candidate coverage, **not a throughput gain**. Greedy path membership does not implement tree attention, online verification, target distribution acceptance or KV continuation.

Missing support remains the main obstacle. On test, 12 of 160 residual labels lie outside the 4,096-row vocabulary and 90 of 160 lie outside the position-wise top-16 pool, including the vocabulary misses. At 8,192 rows, those counts become ten and 86. Dynamic predecessor-conditioned top-16 actually misses 95 and 92, respectively. Both arms score roughly 30 distinct conditioned correction rows per test context to rank tree paths; the dynamic arm also reranks its 16-token pool for each row rather than selecting five base position pools. Dynamic selection gains 0.0313 on validation at 64 nodes for both head sizes, but gains nothing on test at that budget. Widening the static shortlist mostly adds frozen rows with no target-generated positive label, which explains why vocabulary inclusion by itself does not fix top-16 retrieval. The next useful experiment needs more diverse target-generated positives or a candidate objective trained to put held continuations into a small pool; dynamic top-16 over the current scores is not that objective.

Costs are explicit. The 4,096 and 8,192 models contain 696,256 and 827,328 learned parameters, plus 4,194,304 and 8,388,608 frozen shared head values stored as FP32 in these references (16 and 32 MiB), and 32/64 KiB of int64 vocabulary IDs. They make five shortlist projections per context, scoring 20.97M or 41.94M scalar output products (roughly twice those numbers in multiply-add FLOPs), before selection and cached correction rows. On the 32 test contexts, tree construction scored 961 or 982 distinct correction rows for static pools and 1,002 or 1,020 for dynamic pools. The unused greedy-chain construction was removed from this count and the reference. The original conditional-s200 model has 663,616 active learned parameters, a 2,048-row frozen head (8 MiB), and six 2,048-row projections. These are model/reference operation counts, not measured hardware traffic. The exact retained first token is free **only if the previous target pass already computed and handed it over**. Reconstructing it from hidden otherwise adds a 151,936-by-1,024 BF16 output projection, about 311 MB of streamed weights and 311 million FLOPs per context. BF16 output rounding and argmax tie behavior matter, as candidate-repair established.

## Reproduce

The target capture and fits are bounded GPU stages through Bonsai's exclusive admission wrapper. They use the pinned target, corpus and PyTorch runtime already installed on this machine. Each command stays under 50 seconds. The evaluation is CPU-only and takes a few seconds.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
S=$PWD/research/speculative-maps/residual-drafter/experiment.py
$B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" "$S" capture --windows 2048 --batch 32
for v in 4096 8192; do
  $B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" "$S" fit --vocab "$v" --steps 200
  "$P" "$S" evaluate --vocab "$v" --steps 200
done
```

The capture costs about 20.5 seconds of target execution after model load; optimizer loops took 0.90 and 1.48 seconds. CPU evaluation reconstructs the old controls and both new trees, not inference throughput. Source hashes and target revision are in the receipts. Preserve the existing pilot fixtures and checkpoints unchanged.
