"""Count emitted ISA mnemonics within complete query symbols, static not dynamic."""
from collections import Counter
from pathlib import Path
import json
import re

here=Path(__file__).resolve().parent
text=(here/'assembly-gfx1151.s').read_text()
result={}
for mode in (0,1):
    symbol=f'_Z5queryILi{mode}EEvPKhPKfPKtPfiiii'
    start=text.index('\n'+symbol+':')
    end=text.index('\t.size\t'+symbol,start)
    body=text[start:end]
    instructions=Counter()
    for line in body.splitlines():
        m=re.match(r'^\s+([a-z][a-z0-9_]+)(?:\s|$)',line)
        if m and not line.lstrip().startswith(('.', '#')):
            instructions[m.group(1)]+=1
    result['direct' if mode else 'conventional']={
        'static_instruction_lines':sum(instructions.values()),
        'opcodes':dict(sorted(instructions.items())),
    }
(here/'opcode-receipt.json').write_text(json.dumps(result,indent=2)+'\n')
print({key:{'instruction_lines':v['static_instruction_lines'],
    'fma':sum(n for op,n in v['opcodes'].items() if 'fma' in op),
    'exp':sum(n for op,n in v['opcodes'].items() if 'exp' in op),
    'barriers':sum(n for op,n in v['opcodes'].items() if 'barrier' in op)} for key,v in result.items()})
