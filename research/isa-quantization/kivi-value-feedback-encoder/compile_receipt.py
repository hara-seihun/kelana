import hashlib
import json
import re
import subprocess
from pathlib import Path

here=Path(__file__).resolve().parent
asm=(here/'native-hip-amdgcn-amd-amdhsa-gfx1151.s').read_bytes()
(here/'assembly-gfx1151.s').write_bytes(asm)
symbol='_Z7flush_vPKhPhPfii'
readelf=subprocess.check_output(['llvm-readelf','--wide','-s',str(here/'native-hip-amdgcn-amd-amdhsa-gfx1151.o')],text=True)
size=int(re.search(r'\d+:\s+[0-9a-f]+\s+(\d+) FUNC\s+GLOBAL PROTECTED\s+\d+ '+symbol,readelf).group(1))
assembly=asm.decode();descriptor=assembly[assembly.index('\t.amdhsa_kernel '+symbol):assembly.index('\t.end_amdhsa_kernel',assembly.index('\t.amdhsa_kernel '+symbol))]
def field(label):return int(re.search(r'\.amdhsa_'+label+r' (\d+)',descriptor).group(1))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
receipt={'target':'gfx1151','compiler':subprocess.check_output(['hipcc','--version'],text=True).splitlines()[0],
         'flags':'--offload-arch=gfx1151 -O3 -ffp-contract=off -save-temps -c',
         'source_sha256':sha(here/'native.hip'),
         'step_bits_sha256':sha(here/'../kivi-resident-cache/step_bits.hpp'),
         'device_object_sha256':sha(here/'native-hip-amdgcn-amd-amdhsa-gfx1151.o'),
         'assembly_sha256':sha(here/'assembly-gfx1151.s'),
         'kernel':{'symbol':symbol,'body_bytes':size,'descriptor_bytes':64,
                   'lds_bytes_per_cta':field('group_segment_fixed_size'),
                   'private_scratch_bytes_per_thread':field('private_segment_fixed_size'),
                   'vgpr':field('next_free_vgpr'),'sgpr':field('next_free_sgpr'),
                   'wave32':field('wavefront_size32')}}
(here/'compile-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
# The retained assembly and receipt own the evidence; build intermediates do not.
for pattern in ('native-hip-*', 'native-host-*', 'native.hip-*.hipfb', 'native.o'):
    for path in here.glob(pattern):
        if path.is_file():
            path.unlink()
print(json.dumps(receipt['kernel']))
