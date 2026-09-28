"""Pin original source, 16 source/event byte parity windows and complete compiled resources."""
import hashlib,json,re,subprocess
from fractions import Fraction
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
ORIG=ROOT/'kivi-value-alphabet-native'
CAND=ROOT/'kivi-value-alphabet'
SHA=lambda b:hashlib.sha256(b).hexdigest()

def kernel_ops(path):
    asm=path.read_text()
    start=asm.index('_ZN8alphabet11flush_valueEPNS_5CacheEPKfii:')
    end=asm.index('.Lfunc_end',start)
    body=asm[start:end]
    lines=[s.strip().split()[0] for s in body.splitlines() if s.startswith('\t') and s.strip().startswith('v_')]
    return {'valu_instructions_static':len(lines),
            'fp64_mul_static':sum('mul_f64' in s for s in lines),
            'fp64_add_static':sum('add_f64' in s for s in lines),
            'fp64_compare_static':sum('cmp' in s and 'f64' in s for s in lines),
            'fp32_mul_static':sum('mul_f32' in s for s in lines)}

def main():
    compiled=json.loads((HERE/'compile-receipt.json').read_text())
    original=json.loads((ORIG/'compile-receipt.json').read_text())
    assert original['source_sha256']['state.hip']==SHA((ORIG/'state.hip').read_bytes())
    assert compiled['source_sha256']['native.hip']==original['source_sha256']['native.hip']
    assert compiled['source_sha256']['reader.hip']==original['source_sha256']['reader.hip']
    assert compiled['source_sha256']['state.hip']==SHA((HERE/'state.hip').read_bytes())
    assert compiled['source_sha256']['threshold_core.hpp']==SHA((HERE/'threshold_core.hpp').read_bytes())
    assert compiled['binary_sha256']==SHA((HERE/'native').read_bytes())
    assert compiled['assembly_sha256']==SHA((HERE/'assembly-gfx1151.s').read_bytes())
    assert len(compiled['device_kernels'])==len(original['device_kernels'])==7
    assert all(k['private_scratch']==0 for k in compiled['device_kernels'])
    selfcheck=subprocess.run([str(HERE/'encoder'),'--selfcheck'],capture_output=True,text=True,check=True)
    assert selfcheck.stdout.strip()=='partial/all-equal tie cases: passed'
    rows=[]
    for layer,panel,range_ in [(0,'held',range(4)),(1,'train',range(8)),(1,'validation',range(4))]:
        table=(CAND/f'layer{layer}-alphabet.f32').read_bytes()
        for n in range_:
            tag=f'{panel}-{n}-layer{layer}'
            path=HERE/f'{tag}-parity.json'
            row=json.loads(path.read_text())
            assert row['window']==tag and row['table_sha256']==SHA(table)
            assert row['encoder_exit']==0 and not row['encoder_stderr']
            r=row['encoder_result']
            assert r['records']==1792 and r['coordinates']==1792*128 and r['threshold_checks']==1792*128*3
            assert r['mismatches']==r['rounded_decision_disagreements']==0
            manifest=CAND/f'{tag}-manifest.json'
            assert SHA(manifest.read_bytes())==row['candidate_manifest_sha256']
            m=json.loads(manifest.read_text())
            assert m['table_sha256']==row['table_sha256']
            for h in range(8):
                donor=(ROOT/('kivi-two-bit-causal' if layer==0 else 'contextual-value-feedback')/
                       (f'{panel}-{n}-head{h}-events.bin' if layer==0 else f'{panel}-{n}-original-h{h}-events.bin'))
                candidate=CAND/f'{tag}-h{h}-events.bin'
                assert SHA(donor.read_bytes())==row['original_event_sha256'][h]==m['heads'][h]['original_events_sha256']
                assert SHA(candidate.read_bytes())==row['candidate_event_sha256'][h]==m['heads'][h]['events_sha256']
            rows.append({'window':tag,'receipt_sha256':SHA(path.read_bytes()),'result':r,'source':row['source'],
                         'source_v_sha256':row['source_v_sha256']})
    assert len(rows)==16
    margins=[(Fraction(int(x['result']['minimum_nonzero_exact_margin']['abs_numerator']))*
              Fraction(2)**x['result']['minimum_nonzero_exact_margin']['binary_exponent'],x['window']) for x in rows]
    smallest,smallest_window=min(margins)
    before=next(x for x in original['device_kernels'] if 'flush_value' in x['symbol'])
    after=next(x for x in compiled['device_kernels'] if 'flush_value' in x['symbol'])
    bill={'original_source_hash':json.loads((ORIG/'prelaunch-receipt.json').read_text())['source_hash'],
          'native_source_sha256':compiled['source_sha256'],
          'original_binary_sha256':original['binary_sha256'],'compiled_binary_sha256':compiled['binary_sha256'],
          'compiled_assembly_sha256':compiled['assembly_sha256'],
          'cpu_source_sha256':SHA((HERE/'encoder.cpp').read_bytes()),
          'cpu_encoder_binary_sha256':SHA((HERE/'encoder').read_bytes()),
          'cpu_duplicate_case_check':selfcheck.stdout.strip(),
          'original_v_kernel':before,'threshold_v_kernel':after,
          'original_v_isa_counts':kernel_ops(ORIG/'assembly-gfx1151.s'),
          'threshold_v_isa_counts':kernel_ops(HERE/'assembly-gfx1151.s'),
          'original_code_body_all_loaded':sum(k['body_bytes'] for k in original['device_kernels']),
          'threshold_code_body_all_loaded':sum(k['body_bytes'] for k in compiled['device_kernels']),
          'threshold_descriptors_all_loaded':sum(k['descriptor_bytes'] for k in compiled['device_kernels']),
          'global_control_bytes':4548612,'global_candidate_bytes':4548628,
          'threshold_max_lds_per_cta':max(k['lds'] for k in compiled['device_kernels'])}
    receipt={'scope':'CPU event parity and gfx1151 compile only; no GPU execution',
             'arithmetic':'separate FP32 multiply/add levels, FP64 adjacent level sums, doubled BF16 source and <= midpoint tie-to-lower, earliest repeated level',
             'bill':bill,
             'source_observations':{'windows':16,'value_events':sum(x['result']['records'] for x in rows),
                                    'coordinates':sum(x['result']['coordinates'] for x in rows),
                                    'threshold_checks':sum(x['result']['threshold_checks'] for x in rows),
                                    'rounded_adjacent_sums':sum(x['result']['rounded_adjacent_sums'] for x in rows),
                                    'rounded_decision_disagreements':sum(x['result']['rounded_decision_disagreements'] for x in rows),
                                    'exact_midpoint_ties':sum(x['result']['exact_midpoint_ties'] for x in rows),
                                    'repeated_level_groups':sum(x['result']['groups_with_repeated_levels'] for x in rows),
                                    'zero_step_groups':sum(x['result']['zero_step_groups'] for x in rows),
                                    'minimum_nonzero_exact_margin':{'window':smallest_window,
                                        'numerator':str(smallest.numerator),'denominator':str(smallest.denominator),
                                        'approx':float(smallest)},
                                    'byte_mismatches':sum(x['result']['mismatches'] for x in rows)},
             'windows':rows}
    (HERE/'results.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({'source_observations':receipt['source_observations'],
                      'original_v':before,'threshold_v':after,'isa':{'original':bill['original_v_isa_counts'],
                      'threshold':bill['threshold_v_isa_counts']}}))
if __name__=='__main__':main()
