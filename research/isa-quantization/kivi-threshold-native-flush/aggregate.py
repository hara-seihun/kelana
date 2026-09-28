"""Compact parity and emitted-object resource receipt; no device launch."""
from pathlib import Path
from collections import Counter
import json
import re
import subprocess
HERE=Path(__file__).resolve().parent
receipt={arm:[] for arm in ('original','metric')}
for panel,n in (('train',8),('held',4)):
    for i in range(n):
        item=json.loads((HERE/f'{panel}-{i}-parity.json').read_text())
        for arm in receipt:
            receipt[arm].append({'panel':panel,'window':i,**item[arm],'source_sha256':item['source_sha256']})
summary={'source_chunk_bytes_per_window':65536,'source_chunks_per_window':8,
         'metric_model_specific_immutable_fp16_bytes':2304,
         'image_bytes_per_chunk':2560,'arms':{}}
for arm,items in receipt.items():
    summary['arms'][arm]={'matched_windows':sum(x['exact'] for x in items),
                          'mismatching_bytes':sum(x['mismatching_bytes'] for x in items),
                          'mismatching_code_bytes':sum(x['mismatching_code_bytes'] for x in items),
                          'mismatching_fp16_field_bytes':sum(x['mismatching_fp16_field_bytes'] for x in items),
                          'windows':items}
assembly=(HERE/'assembly-gfx1151.s').read_text()
object_path=HERE/'encoder-hip-amdgcn-amd-amdhsa-gfx1151.o'
symbols=subprocess.check_output(['llvm-objdump','--syms',str(object_path)],text=True)
resources={}
for variant,arm in [('0','original'),('1','metric')]:
    name=f'_Z9flush_keyILb{variant}EEvPKtPKDF16_Ph'
    row=next(line for line in symbols.splitlines() if f' .protected {name}' in line and ' F .text.' in line)
    body=int(row.split()[4],16)
    descriptor=next(line for line in symbols.splitlines() if f' .protected {name}.kd' in line)
    descriptor_size=int(descriptor.split()[4],16)
    block=assembly.split(f'\t.amdhsa_kernel {name}\n',1)[1].split('\t.end_amdhsa_kernel',1)[0]
    metrics={k:int(re.search(r'\.'+k+r'\s+(\d+)',block).group(1)) for k in ('amdhsa_group_segment_fixed_size','amdhsa_private_segment_fixed_size','amdhsa_next_free_vgpr','amdhsa_next_free_sgpr')}
    body_asm=assembly.split(f'\t.globl\t{name}\n',1)[1].split(f'\t.end_amdhsa_kernel',1)[0]
    ops=Counter(re.findall(r'^\s*(v_[a-zA-Z0-9_]+|s_barrier|ds_[a-zA-Z0-9_]+)\b',body_asm,re.M))
    def count(prefix):return sum(v for k,v in ops.items() if k.startswith(prefix))
    resources[arm]={'device_body_bytes':body,'descriptor_bytes':descriptor_size,
                    'lds_bytes':metrics['amdhsa_group_segment_fixed_size'],
                    'scratch_bytes_per_thread':metrics['amdhsa_private_segment_fixed_size'],
                    'vgpr':metrics['amdhsa_next_free_vgpr'],'sgpr':metrics['amdhsa_next_free_sgpr'],
                    'static_s_barrier_sites':ops['s_barrier'],
                    'static_fp64_opcode_sites':sum(v for k,v in ops.items() if '_f64' in k),
                    'static_fp32_opcode_sites':sum(v for k,v in ops.items() if '_f32' in k),
                    'static_ds_opcode_sites':sum(v for k,v in ops.items() if k.startswith('ds_')),
                    'static_fp64_division_opcode_sites':sum(v for k,v in ops.items() if (k.startswith('v_div_') or k.startswith('v_rcp_f64')) and '_f64' in k),
                    'selected_static_opcodes':{k:count(k) for k in ('s_barrier','v_fma_f64','v_mul_f64','v_div_scale_f64','v_rndne_f64','v_div_scale_f32')},
                    'symbol':name}
summary['device_compile_only_resources']=resources
summary['static_code_plus_model_metric_bytes']={arm:resources[arm]['device_body_bytes']+resources[arm]['descriptor_bytes']+(2304 if arm=='metric' else 0) for arm in resources}
previous=json.loads((HERE.parent/'kivi-metric-native-flush'/'results.json').read_text())['device_compile_only_resources']
prior_asm=(HERE.parent/'kivi-metric-native-flush'/'assembly-gfx1151.s').read_text()
prior_name=previous['metric']['symbol']
prior_body=prior_asm.split(f'\t.globl\t{prior_name}\n',1)[1].split(f'\t.end_amdhsa_kernel',1)[0]
prior_ops=Counter(re.findall(r'^\s*(v_[a-zA-Z0-9_]+)\b',prior_body,re.M))
prior_div=sum(v for k,v in prior_ops.items() if (k.startswith('v_div_') or k.startswith('v_rcp_f64')) and '_f64' in k)
summary['frozen_quotient_metric_control']={**previous['metric'],'static_fp64_division_opcode_sites':prior_div}
summary['threshold_minus_quotient_metric']={field:resources['metric'][field]-summary['frozen_quotient_metric_control'][field]
    for field in ('device_body_bytes','descriptor_bytes','lds_bytes','scratch_bytes_per_thread','vgpr','sgpr',
                  'static_s_barrier_sites','static_fp64_opcode_sites','static_fp64_division_opcode_sites')}
(HERE/'results.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({arm:{k:v for k,v in data.items() if k!='windows'} for arm,data in summary['arms'].items()}))
print(json.dumps(resources,indent=2))
