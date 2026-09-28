"""Inspect frozen TRAIN-selected gauge under original train and held causal-pair laws."""
import hashlib,json
import numpy as np
from prepare import HERE,covariance,objective

def run():
 policy=json.loads((HERE/'prepare.json').read_text())
 train=np.load(HERE/'train-pair-moment.npy')
 assert hashlib.sha256(train.astype('<f8').tobytes()).hexdigest()==policy['C_sha256']
 held,count=covariance('held')
 assert count==4*16*32896
 np.save(HERE/'held-pair-moment.npy',held)
 e=np.asarray(policy['integer_e'],dtype=np.float64)
 x=np.asarray(policy['continuous_x'],dtype=np.float64)
 out={'law':'uniform over all causal (i<=t) pairs, 16 Q heads and respective shared KV head, fixed train-only gauge',
      'e':policy['integer_e'],'panels':{}}
 for panel,C,n in [('train',train,policy['train_pair_count']),('held',held,count)]:
  base=float(C.sum());applied=objective(e[1:],C)[0];continuous_train_choice=objective(x[1:],C)[0]
  out['panels'][panel]={'pair_count':n,'C_sha256':hashlib.sha256(C.astype('<f8').tobytes()).hexdigest(),
                       'baseline_F':base,'train_integer_e_F':applied,'train_integer_e_F_ratio_to_baseline':applied/base,
                       'train_continuous_x_F_diagnostic':continuous_train_choice}
 assert out['panels']['train']['train_integer_e_F']==policy['integer_F']
 (HERE/'geometry.json').write_text(json.dumps(out,indent=2)+'\n')
 print(json.dumps(out['panels'],indent=2))
if __name__=='__main__':run()
