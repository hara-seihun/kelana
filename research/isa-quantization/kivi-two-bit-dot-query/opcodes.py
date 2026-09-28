"""Static ISA counts by symbol; complete bodies, not elapsed or dynamic totals."""
from collections import Counter
import json
from pathlib import Path
import re

here=Path(__file__).resolve().parent
# Exhaustively establish the byte-to-four-unsigned-byte-lanes identity used by
# the mixed-signedness dot operand, independent of any GPU execution.
for code in range(256):
    u=(code|(code<<12))&0x000F000F
    word=(u|(u<<6))&0x03030303
    assert [(word>>(8*i))&255 for i in range(4)]==[(code>>(2*i))&3 for i in range(4)]
source=(here/'assembly-gfx1151.s').read_text()
labels={'conventional':'_Z11query_groupILi0EEvPKPKhPKfPKtPfiiii',
        'byte_dot':'_Z11query_groupILi1EEvPKPKhPKfPKtPfiiii',
        'finish':'_Z8finish_oPKfPf'}
sizes={'conventional':0x3218,'byte_dot':0x3960,'finish':0x174}
lds={'conventional':5632,'byte_dot':8512,'finish':0}
registers={'conventional':{'vgpr':23,'sgpr':44},'byte_dot':{'vgpr':98,'sgpr':56},
           'finish':{'vgpr':12,'sgpr':4}}
result={}
for name,symbol in labels.items():
    start=source.index('\n'+symbol+':')
    end=source.index('\t.size\t'+symbol,start)
    body=source[start:end]
    ops=Counter()
    for line in body.splitlines():
        match=re.match(r'^\s+([a-z][a-z0-9_]+)(?:\s|$)',line)
        if match:ops[match.group(1)]+=1
    result[name]={'body_bytes':sizes[name],'descriptor_bytes':64,
                  'lds_bytes_per_cta':lds[name],'private_scratch_bytes':0,
                  'registers':registers[name],'static_instruction_lines':sum(ops.values()),
                  'static_dot4_sites':sum(n for op,n in ops.items() if op.startswith('v_dot4')),
                  'static_barrier_sites':sum(n for op,n in ops.items() if 'barrier' in op),
                  'opcodes':dict(sorted(ops.items()))}
(here/'opcode-receipt.json').write_text(json.dumps(result,indent=2)+'\n')
print({name:{k:info[k] for k in ('body_bytes','lds_bytes_per_cta','static_instruction_lines',
                                 'static_dot4_sites','static_barrier_sites')} for name,info in result.items()})
