"""No fitting: exact covariance transfer of two fixed decoded full-row error maps."""
from pathlib import Path
import importlib.util
import json
import numpy as np

HERE=Path(__file__).resolve().parent
READER=HERE.parent/'quip-full-row-slab/replay.py'
spec=importlib.util.spec_from_file_location('full_row_replay',READER)
reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)


def row_keys(x):
    return np.ascontiguousarray(x).view(np.dtype((np.void,x.dtype.itemsize*x.shape[1]))).ravel()


def main():
    with np.load(reader.FIX) as f:
        W=f['weight'][:128].astype(np.float64)
        Xt=f['train'].astype(np.float64)
        Xh=f['validation'].astype(np.float64)
    assert Xt.shape==(2048,1024) and Xh.shape==(1024,1024)
    unique_train=np.unique(row_keys(Xt));unique_held=np.unique(row_keys(Xh))
    overlap=np.intersect1d(unique_train,unique_held)
    held_novel=~np.isin(row_keys(Xh),unique_train)
    Ht=Xt.T@Xt/len(Xt);Hh=Xh.T@Xh/len(Xh)
    eigen,U=np.linalg.eigh(Ht)
    threshold=eigen[-1]*1e-10
    rank=int((eigen>threshold).sum())
    assert rank==896 and eigen[128]>threshold and eigen[127]<=threshold
    null=U[:,:128];supported=U[:,128:];positive=eigen[128:]
    null_train=float(np.linalg.norm(Xt@null)**2/len(Xt))
    null_held=float(np.linalg.norm(Xh@null)**2/len(Xh))
    assert null_train<1e-20 and null_held>0
    hd=np.sum(supported*(Hh@supported),axis=0)
    generalized_mat=(supported.T@Hh@supported)/np.sqrt(positive[:,None]*positive[None,:])
    gamma,V=np.linalg.eigh((generalized_mat+generalized_mat.T)*.5)
    teacher={'train_per_state':float(np.linalg.norm(Xt@W.T)**2/len(Xt)),
             'held_per_state':float(np.linalg.norm(Xh@W.T)**2/len(Xh))}
    out={'source':{'train_rows':len(Xt),'held_rows':len(Xh),'unique_train_input_rows':len(unique_train),
                   'unique_held_input_rows':len(unique_held),'unique_overlap':len(overlap),
                   'held_tokens_with_input_not_seen_in_train':int(held_novel.sum()),
                   'held_tokens_with_seen_input':int((~held_novel).sum())},
         'teacher_output_energy':teacher,
         'train_covariance':{'rank':rank,'nullity':1024-rank,
                             'smallest_positive_eigenvalue':float(positive[0]),
                             'largest_eigenvalue':float(positive[-1]),
                             'null_projected_train_input_energy_per_state':null_train,
                             'null_projected_held_input_energy_per_state':null_held,
                             'support_restricted_generalized_held_to_train_max':float(gamma[-1]),
                             'unrestricted_generalized_held_to_train_bound':'infinite'},'images':{}}
    for name,fn in (('quip_rvq3',reader.quip),('scalar_group128',reader.scalar)):
        decoded,receipt=fn()
        D=decoded-W
        Ps=D@supported
        P0=D@null
        train_mse=float(np.linalg.norm(Xt@D.T)**2/len(Xt))
        held_mse=float(np.linalg.norm(Xh@D.T)**2/len(Xh))
        held_null=float(np.linalg.norm((Xh@null)@P0.T)**2/len(Xh))
        held_support=float(np.linalg.norm((Xh@supported)@Ps.T)**2/len(Xh))
        held_cross=held_mse-held_null-held_support
        diag_held=float(np.dot(hd,np.sum(Ps*Ps,axis=0)))
        generalized_energy=np.sum(((Ps*np.sqrt(positive))@V)**2,axis=0)
        assert np.isclose(train_mse,np.dot(positive,np.sum(Ps*Ps,axis=0)),rtol=1e-8)
        assert np.isclose(held_support,np.dot(gamma,generalized_energy),rtol=1e-7)
        null_feature=Xh@null
        null_token_scores=np.sum((null_feature@P0.T)**2,axis=1)
        gen=[]
        for k in (1,10,100,448):
            gen.append({'top_supported_modes':k,'smallest_gamma_in_top_set':float(gamma[-k]),
                        'train_error_energy_fraction':float(generalized_energy[-k:].sum()/train_mse),
                        'held_support_error_fraction':float(np.dot(gamma[-k:],generalized_energy[-k:])/held_support)})
        out['images'][name]={
            'image_sha256':receipt['image_sha256'],
            'coefficient_error_frobenius_squared':float(np.sum(D*D)),
            'coefficient_nullspace_fraction':float(np.sum(P0*P0)/np.sum(D*D)),
            'train_error_per_state':train_mse,'held_error_per_state':held_mse,
            'error_energy_held_to_train_factor':held_mse/train_mse,
            'teacher_energy_held_to_train_factor':teacher['held_per_state']/teacher['train_per_state'],
            'train_relative_squared_error':train_mse/teacher['train_per_state'],
            'held_relative_squared_error':held_mse/teacher['held_per_state'],
            'held_error_null_component':held_null,'held_error_supported_component':held_support,
            'held_error_null_support_cross_term':held_cross,
            'held_null_fraction':held_null/held_mse,
            'held_supported_fraction':held_support/held_mse,
            'held_null_error_from_novel_tokens_fraction':float(null_token_scores[held_novel].sum()/null_token_scores.sum()),
            'held_total_error_novel_tokens_fraction':float(np.sum((Xh[held_novel]@D.T)**2)/np.sum((Xh@D.T)**2)),
            'held_supported_diagonal_in_train_eigenbasis':diag_held,
            'held_supported_cross_mode_interference':held_support-diag_held,
            'generalized_supported_high_variance_modes':gen}
    out['relative_contrast']={
        'held_numerator_quip_over_scalar':out['images']['quip_rvq3']['held_error_per_state']/out['images']['scalar_group128']['held_error_per_state'],
        'train_numerator_quip_over_scalar':out['images']['quip_rvq3']['train_error_per_state']/out['images']['scalar_group128']['train_error_per_state'],
        'coefficient_error_quip_over_scalar':out['images']['quip_rvq3']['coefficient_error_frobenius_squared']/out['images']['scalar_group128']['coefficient_error_frobenius_squared'],
        'null_held_error_quip_over_scalar':out['images']['quip_rvq3']['held_error_null_component']/out['images']['scalar_group128']['held_error_null_component'],
        'supported_held_error_quip_over_scalar':out['images']['quip_rvq3']['held_error_supported_component']/out['images']['scalar_group128']['held_error_supported_component']}
    (HERE/'results.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps(out,indent=2))

if __name__=='__main__':main()
