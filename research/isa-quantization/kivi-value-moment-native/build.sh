#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
hipcc --offload-arch=gfx1151 -O3 -ffp-contract=off -save-temps native.hip -o native
python3 - <<'PY'
from pathlib import Path
import hashlib,json,re,subprocess
asm=Path('native-hip-amdgcn-amd-amdhsa-gfx1151.s').read_text();Path('assembly-gfx1151.s').write_text(asm)
symbols=subprocess.check_output(['llvm-readelf','--wide','-s','native-hip-amdgcn-amd-amdhsa-gfx1151.o'],text=True)
bodies={m.group(2):int(m.group(1)) for m in re.finditer(r'\d+:\s+[0-9a-f]+\s+(\d+) FUNC\s+GLOBAL\s+PROTECTED\s+\d+\s+(\S+)',symbols)}
paths=['native.hip','moment_reader.hip','flush.hip','../kivi-stable-resident/reader.hip','../kivi-stable-resident/state.hip','../kivi-resident-cache/step_bits.hpp']
sha=lambda b:hashlib.sha256(b).hexdigest()
r={'target':'gfx1151','compiler':subprocess.check_output(['hipcc','--version'],text=True).splitlines()[0],'source_sha256':{p:sha(Path(p).read_bytes()) for p in paths},'device_kernels':[]}
for line in asm.splitlines():
 if '\t.amdhsa_kernel ' not in line:continue
 symbol=line.split()[-1];body=asm[asm.index(line):asm.index('\t.end_amdhsa_kernel',asm.index(line))]
 r['device_kernels'].append({'symbol':symbol,'body_bytes':bodies[symbol],'descriptor_bytes':64,'lds':int(re.search(r'amdhsa_group_segment_fixed_size (\d+)',body).group(1)),'private_scratch':int(re.search(r'amdhsa_private_segment_fixed_size (\d+)',body).group(1)),'vgpr':int(re.search(r'amdhsa_next_free_vgpr (\d+)',body).group(1)),'sgpr':int(re.search(r'amdhsa_next_free_sgpr (\d+)',body).group(1))})
r['assembly_sha256']=sha(asm.encode());r['binary_sha256']=sha(Path('native').read_bytes());Path('compile-receipt.json').write_text(json.dumps(r,indent=2)+'\n')
print('kernels',len(r['device_kernels']),'code bytes',sum(x['body_bytes']+x['descriptor_bytes'] for x in r['device_kernels']))
PY
g++ -O2 -std=c++17 ../kivi-stable-resident/cpu.cpp -o cpu-reference
rm -f native-hip-*.bc native-hip-*.o native-hip-*.out native-hip-*.s native-hip-*.hipi native-hip-*.out.resolution.txt native.hip-*.hipfb native-host-*.bc native-host-*.o native-host-*.s native-host-*.hipi
