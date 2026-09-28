import json
from pathlib import Path
p=Path(__file__).resolve().parent
r=[json.loads((p/f'{panel}-{i}-result.json').read_text()) for panel,n in [('train',8),('held',4)] for i in range(n)]
for x in r:
 assert x['prefixes_checked']==len(x['states'])==256
 assert x['per_head_reference_mass_reads']==16*sum(z['quant_positions']+z['recent_positions'] for z in x['states'])
 assert x['per_head_grouped_record_mixes']==16*sum(z['quant_unique']+z['recent_unique'] for z in x['states'])
full=lambda a:sum(x[a]*x['teacher_full_o_sq'] for x in r)/sum(x['teacher_full_o_sq'] for x in r)
summary={'windows':12,'query_states':3072,'q_head_states':49152,
         'train_normalized_sse':{k:sum(x[k]*x['teacher_full_o_sq'] for x in r[:8])/sum(x['teacher_full_o_sq'] for x in r[:8]) for k in ('ordered_normalized_sse','grouped_normalized_sse')},
         'held_normalized_sse':{k:sum(x[k]*x['teacher_full_o_sq'] for x in r[8:])/sum(x['teacher_full_o_sq'] for x in r[8:]) for k in ('ordered_normalized_sse','grouped_normalized_sse')},
         'all_normalized_sse':{k:full(k) for k in ('ordered_normalized_sse','grouped_normalized_sse')},
         'max_abs_output_difference':max(x['max_abs_output_difference'] for x in r),
         'per_head_reference_mass_reads':sum(x['per_head_reference_mass_reads'] for x in r),
         'per_head_control_reference_reads':sum(x['per_head_control_reference_reads'] for x in r),
         'per_head_grouped_record_mixes':sum(x['per_head_grouped_record_mixes'] for x in r),
         'per_head_control_record_mixes':sum(x['per_head_control_reference_reads'] for x in r),
         't256':[{'window':f"{x['panel']}-{x['window']}",**x['states'][-1],
                  'per_query_control_value_products':16*128*256,
                  'per_query_grouped_value_products':16*128*(x['states'][-1]['quant_unique']+x['states'][-1]['recent_unique']),
                  'per_query_mass_additions':16*256} for x in r]}
(p/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='t256'},indent=2))
