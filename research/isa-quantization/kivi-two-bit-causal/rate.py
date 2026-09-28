"""Exact represented-state rates; no quantizer or quality computation."""
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent
PROGRAM=196624

def before(t):
    if not t:return 0
    rk=1+(t-1)%32
    rv=min(t,33)
    return 8*(48*(2*t-rk-rv)+256*(rk+rv))

def final(t):
    rk=t%32
    rv=min(t,32)
    return 8*(48*(2*t-rk-rv)+256*(rk+rv))

def peak(t):
    return max(before(t),before(32*(t//32)))

def turbo(t):
    return PROGRAM+736*t

def threshold(fn):
    # For each residue, the difference from Turbo has slope32 per token.
    residue=[]
    for r in range(32):
        t=64+r
        intercept=fn(t)-768*t
        assert fn(t+32)-fn(t)==768*32
        m=max(2,(PROGRAM-intercept-32*r)//1024+1)
        first=32*m+r
        assert fn(first)>turbo(first)
        if first-32>=64:assert fn(first-32)<=turbo(first-32)
        residue.append({'mod32':r,'kivi_intercept':intercept,'first_strict_turbo_win_in_residue':first})
    first=min(row['first_strict_turbo_win_in_residue'] for row in residue)
    permanent=max(row['first_strict_turbo_win_in_residue']-32 for row in residue)+1
    assert all(fn(t)<=turbo(t) for t in range(1,first))
    assert all(fn(t)>turbo(t) for t in range(permanent,permanent+64))
    return {'first_turbo_smaller':first,'permanently_turbo_smaller_from':permanent,'residue_certificates':residue}

assert peak(256)==304768 and final(256)==249856
# Independently simulate each count transition over8192 tokens in milliseconds.
qk=rvk=qv=rvv=0
high=0
for t in range(1,8193):
    rvk+=1;rvv+=1
    actual=8*(qk*48+qv*48+256*(rvk+rvv))
    assert actual==before(t)
    high=max(high,actual)
    assert high==peak(t)
    if rvk==32:qk+=32;rvk=0
    if rvv>32:qv+=1;rvv-=1
    assert 8*(48*(qk+qv)+256*(rvk+rvv))==final(t)
r={'state_contract':'Cache plus once-per-pool literal sketch matrices; common source/code/scratch excluded from both. No longer-context quality measured.',
   't256':{'kivi2_peak':peak(256),'kivi2_final':final(256),'turbo_dynamic':736*256,'turbo_shared_program':PROGRAM,'turbo_total_one_sequence':turbo(256)},
   'peak_crossing':threshold(peak),'final_crossing':threshold(final),
   'two_sequences_t256':{'kivi2_peak':2*peak(256),'turbo_peak':PROGRAM+2*736*256},
   'examples':{str(t):{'kivi_peak':peak(t),'kivi_final':final(t),'turbo_one_sequence':turbo(t)} for t in (256,1024,2048,4096,8192)}}
(HERE/'rate.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps({k:v for k,v in r.items() if k not in ('peak_crossing','final_crossing')},indent=2))
for name in ('peak_crossing','final_crossing'):print(name,{k:v for k,v in r[name].items() if k!='residue_certificates'})
