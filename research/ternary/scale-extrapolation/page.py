#!/usr/bin/env python3
"""Materialize the selected extrapolated image with the checked exact page codec."""
import importlib.util
from pathlib import Path

source = Path(__file__).resolve().parents[1]/'exact-rate/measure.py'
spec = importlib.util.spec_from_file_location('exact_ternary_page', source)
codec = importlib.util.module_from_spec(spec)
spec.loader.exec_module(codec)
codec.ROOT = Path('/path/to/workspace/data/kelana-subbit/ternary/scale-extrapolate-1.5')
codec.OUT = Path('/path/to/workspace/data/kelana-subbit/ternary/scale-extrapolation/page-1.5')
codec.main()
