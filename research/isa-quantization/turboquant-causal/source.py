"""Existing full Qwen Q16/KV8 causal source; K rounded post-RoPE like KIVI."""
import importlib.util
from pathlib import Path
import torch
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
spec=importlib.util.spec_from_file_location('pinned_full_gqa_source',ROOT/'skvq-global-gqa/source.py')
full=importlib.util.module_from_spec(spec);spec.loader.exec_module(full)
FIX_SHA=full.FIX_SHA

def arrays(panel,window):
 src=full.arrays(panel,window)
 src['key']=(src['krot'].permute(1,0,2).to(torch.bfloat16).contiguous()
              .view(torch.uint16).reshape(256,1024).numpy().copy())
 return src
