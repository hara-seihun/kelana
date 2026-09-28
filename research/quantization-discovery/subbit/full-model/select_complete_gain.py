#!/usr/bin/env python3
"""Freeze the complete-model paid gain from eight train-window receipts."""
import json
from pathlib import Path

from narrow_prefix import sha
from mlp_factor_response import ROOT

panels = [ROOT / f'complete-paid-fit-train-{name}.json'
          for name in ('0', '1-2', '3-4', '5-6', '7')]
windows = [window for path in panels for window in json.loads(path.read_text())['windows']]
assert [window['index'] for window in windows] == list(range(8))
means = {key: sum(window['nll'][key] for window in windows) / len(windows)
         for key in windows[0]['nll']}
selected = min(means, key=means.get)
choice = {'format': 'complete-paid-gain-choice/1',
          'selected': [float(value) for value in selected.split(',')],
          'fit_nll': means,
          'fit_receipts': {path.name: sha(path) for path in panels},
          'rule': 'minimum eight-window train mean across nine predeclared paid (down,O) scale pairs'}
(ROOT / 'complete-paid-gain-choice.json').write_text(json.dumps(choice, indent=2) + '\n')
print(json.dumps(choice, indent=2))
