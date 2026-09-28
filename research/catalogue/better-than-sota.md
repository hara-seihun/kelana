# Better than SOTA on something

[Research desk](README.md) · [All source documents](inventory.md)

Generated from the domain JSON records. Edit those records, then run `catalogue.py build`.

## Model conversion and quantization representations

- [Exact calibrated Qwen3-0.6B affine image in native llama.cpp](conversion.md#conversion-affine-q4-native-gguf): The exact executable Kelana image wins both bytes and native perplexity versus named published stock formats; its observed decode speed is also higher on this model/device/workload.

## Bonsai and Qwen runtime research

- [Bonsai 27B batched ternary generation on Radeon 8060S](runtime.md#runtime-bonsai-batched-ternary-8060s): A model-and-device-specific throughput record for Bonsai 2 27B ternary generation on the Radeon 8060S. Packed pair-code FFNs, shared batched weight work and the recurrent execution route sustain roughly 600 aggregate tokens/s at 64 streams without a speculative drafter.
- [Bonsai 27B full-model document prefill on Radeon 8060S](runtime.md#runtime-bonsai-document-prefill-8060s): Model/device-specific prefill achievements, separate from generation throughput. Full-layer batched ternary execution and shape-specific recurrent layout exceed 900 prompt tokens/s on the recorded document workloads.
- [Bonsai native serving ingestion and concurrent decode](runtime.md#runtime-bonsai-serving-routes): Model/device-specific serving achievements have their own request boundary. They are not represented by the faster offline batch-driver numbers.
- [Packed AWQ GEMM against upstream SGLang HIP](runtime.md#runtime-sglang-awq-packed-gfx1151): The proposed upstream SGLang gfx1151 HIP AWQ path consumes packed four-bit weights for 1–16 rows instead of dequantizing whole matrices before torch.matmul. It uses FP32 partial accumulation and leaves checkpoint storage unchanged.
