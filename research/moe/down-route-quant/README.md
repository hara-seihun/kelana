# Recode routed Qwen down weights on actual producer inputs

The installed Qwen3.6-35B-A3B GGUF stores layer-0 routed down matrices as Q5_K. We decoded that bank, recoded every selected expert to the existing native Q4_K format, and evaluated the complete eight-expert weighted down sum on the captured 113 train and 126 held real-text tokens. The second Q4_K arm gives GGML's weighted quantizer train-only coordinate weights derived from the actual post-SwiGLU hiddens and normalized route scores. It reuses Q4_K's 144-byte block and the existing native Q4_K reader; it does not introduce another format or a new reader.

| Layer-0 down image | Bytes per expert | Train routed-sum RMS vs decoded Q5_K | Held routed-sum RMS vs decoded Q5_K |
| --- | ---: | ---: | ---: |
| Installed Q5_K | 720,896 | 0 | 0 |
| Q4_K reference recode | 589,824 | .04794 | .04901 |
| Q4_K train-weighted recode | 589,824 | .03293 | .04611 |

The train-weighted arm improves 99 of 126 held token errors relative to the reference Q4 recode, but its train advantage of 31.3% relative RMS contracts to 5.9% on held. The weighted arm uses each expert's score-weighted hidden-coordinate RMS, floored at 10% of the coordinate mean. Experts absent on train receive the reference quantizer; 153 experts occur on both train and held, while 35 held experts have no train assignment. These sparse per-expert samples are a poor place to optimize more quantizer parameters. The held Q4 penalty is roughly 4.6% of the Q5 routed output at this one layer, before errors propagate through any subsequent layer.

At the same format rate the weighted image does win locally. But the prize for changing Q5_K down alone is small: 131,072 bytes per selected expert, or 41,943,040 bytes per token if all forty layers behave like layer 0. That is 1.597% of the model's conditional 2,626,187,904-byte one-read stream, before route grouping, cache effects, any new image creation, or serving work. The full forty-layer bank would shrink 1,342,177,280 bytes. Online work still includes eight down matvecs and the weighted sum. Q4_K and Q5_K execute different native instructions, so fewer bytes do not imply lower elapsed time. This is not enough local fidelity and traffic leverage to justify a full-image conversion or claim a model-quality improvement. A useful next question is joint recoding of gate/up and down against complete-model held loss, with enough distinct routed training activations per expert. The independent native MMQ width experiment prices scheduling without changing weights.

The offline contract is dequantized installed Q5_K weights, native GGML Q4_K quantizers and decoder, FP32 CPU BLAS expert products, and FP64 score-weighted accumulation. The captured native down outputs differ from the offline Q5 reproduction by .01345/.01513 relative RMS on train/held, so this receipt cannot certify native FP32 bit identity. No output image or Bonsai executable changed. Language loss, throughput, prompt grouping costs, and other layers have not been measured for the proposed image. The Q4 representations generated here exist in memory during the experiment, not as a complete model image; the byte counts include the actual native Q4_K block size rather than an entropy estimate.

[The receipt](/path/to/workspace/data/qwen-moe/down-route-quant/receipt.json) binds all four disjoint expert-array shards to the source hash, GGUF acquisition, installed library, inventory and input capture. Its per-token errors and raw partial output arrays are retained beside it. From the Kelana root, with NumPy and the installed runtime:

```sh
for span in '0 32' '32 128' '128 224' '224 256'; do
  set -- $span
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 python3 research/moe/down-route-quant/experiment.py \
    --first "$1" --last "$2" --output "/path/to/workspace/data/qwen-moe/down-route-quant/part-$1-$2.npz"
done
python3 research/moe/down-route-quant/summarize.py
```

Each expert shard can run independently on CPU and holds no GPU lock. The native runtime and resident service were untouched.
