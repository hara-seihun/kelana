#!/usr/bin/env python3
"""Compare candidates within randomized timing rounds, without deleting slow samples."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np


def block_data(run, trace):
    result={}
    for b in run['timing_blocks']:
        times=run['ms_samples'][b['first_sample']:b['first_sample']+b['calls']]
        observed=[s for s in trace if s['begin_ns']<=b['end_ns'] and s['end_ns']>=b['begin_ns']]
        telemetry={}
        for key in ('gfx_hz','temperature_mc','power_uw','busy_percent','host_load1'):
            values=[s[key] for s in observed if s[key]>=0]
            telemetry[key]={'min':min(values),'max':max(values),'mean':float(np.mean(values))} if values else None
        result[b['round']]={'mean_ms':float(np.mean(times)),'median_ms':float(np.median(times)),
                            'order':b['order'],'telemetry':telemetry}
    return result


def analyze(data, baseline, seed):
    if data.get('format')!='kelana-batch-bench/2':
        raise ValueError('Requires randomized-round format kelana-batch-bench/2')
    rng=np.random.default_rng(seed)
    reports=[]
    for rows in sorted({r['rows'] for r in data['runs']}):
        runs={r['candidate']:r for r in data['runs'] if r['rows']==rows}
        if baseline not in runs:raise ValueError(f'Baseline {baseline} absent at rows={rows}')
        trace=next(t['trace']['samples'] for t in data['telemetry'] if t['rows']==rows)
        base=block_data(runs[baseline],trace)
        for name,run in runs.items():
            if name==baseline:continue
            candidate=block_data(run,trace)
            rounds=sorted(base.keys() & candidate.keys())
            logratios=np.array([np.log(base[r]['mean_ms']/candidate[r]['mean_ms']) for r in rounds])
            bootstrap=rng.choice(logratios,size=(10000,len(rounds)),replace=True).mean(axis=1)
            reports.append({'rows':rows,'baseline':baseline,'candidate':name,'rounds':len(rounds),
                'geomean_round_speedup':float(np.exp(logratios.mean())),
                'round_bootstrap_95pct_interval':np.exp(np.quantile(bootstrap,[.025,.975])).tolist(),
                'total_mean_speedup':float(np.mean(runs[baseline]['ms_samples'])/np.mean(run['ms_samples'])),
                'baseline_slower_rounds':int(np.sum(logratios>0)),
                'round_details':[{'round':r,'baseline':base[r],'candidate':candidate[r],
                                  'speedup':float(np.exp(logratios[i]))} for i,r in enumerate(rounds)]})
    return {'format':'kelana-paired-analysis/1','seed':seed,
            'scope':'All samples retained. Bootstrap resamples rounds as independent units; thermal autocorrelation and outside GPU clients can still confound it. No automatic performance acceptance.',
            'comparisons':reports}


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('input',type=Path);p.add_argument('--baseline',required=True)
    p.add_argument('--seed',type=int,default=7319);p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();report=analyze(json.loads(a.input.read_text()),a.baseline,a.seed)
    report['source']=str(a.input)
    report['source_sha256']=hashlib.sha256(a.input.read_bytes()).hexdigest()
    report['analysis_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    a.out.write_text(json.dumps(report,indent=2)+'\n')
    for c in report['comparisons']:
        print(c['rows'],c['candidate'],'speedup',round(c['geomean_round_speedup'],4),
              'interval',c['round_bootstrap_95pct_interval'],'wins',c['baseline_slower_rounds'],'/',c['rounds'])
