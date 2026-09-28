"""Reuse pinned KIVI chronological builder and independent reader on physical folded source."""
import importlib.util
import sys
from source import BASE,HERE


def run(module,panel,window):
    assert module in ('build','replay')
    spec=importlib.util.spec_from_file_location('kivi_original_'+module,BASE/(module+'.py'))
    impl=importlib.util.module_from_spec(spec);spec.loader.exec_module(impl)
    assert impl.HERE==HERE
    impl.run(panel,window)

if __name__=='__main__':run(sys.argv[1],sys.argv[2],int(sys.argv[3]))
