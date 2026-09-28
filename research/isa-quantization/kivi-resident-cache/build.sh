#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 - <<'PY'
from pathlib import Path
for source,marker,target in (
    ('../kivi-grouped-value-query/consumer.hip','extern "C" void launch_direct','grouped-generated.hip'),
    ('../kivi-two-bit-dot-query/consumer.hip','extern "C" void launch_byte_dot','control-generated.hip'),
):
    content=Path(source).read_text()
    start=content.index(marker)
    end=content.index('\n}',start)+2
    Path(target).write_text(content[:start]+content[end:])
PY
rm -f acceptance.ready
hipcc --offload-arch=gfx1151 -O3 -save-temps native.hip -o native
python3 - <<'PY'
from pathlib import Path
import hashlib,json,re,subprocess
asm=Path('native-hip-amdgcn-amd-amdhsa-gfx1151.s').read_text()
Path('assembly-gfx1151.s').write_text(asm)
symbol_lines=subprocess.check_output(['llvm-readelf','--wide','-s','native-hip-amdgcn-amd-amdhsa-gfx1151.o'],text=True)
bodies={m.group(2):int(m.group(1)) for m in re.finditer(r'\d+:\s+[0-9a-f]+\s+(\d+) FUNC\s+GLOBAL\s+PROTECTED\s+\d+\s+(\S+)',symbol_lines)}
receipt={'target':'gfx1151','compiler':subprocess.check_output(['hipcc','--version'],text=True).splitlines()[0],
  'source_sha256':{str(p):hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in (Path('state.hip'),Path('step_bits.hpp'),Path('native.hip'),Path('../kivi-grouped-value-query/consumer.hip'),Path('../kivi-two-bit-dot-query/consumer.hip'))},
  'device_kernels':[]}
for line in asm.splitlines():
    if '\t.amdhsa_kernel ' not in line:continue
    symbol=line.split()[-1]
    start=asm.index(line);end=asm.index('\t.end_amdhsa_kernel',start)
    body=asm[start:end]
    receipt['device_kernels'].append({'symbol':symbol,'body_bytes':bodies[symbol],'descriptor_bytes':64,'lds':int(re.search(r'amdhsa_group_segment_fixed_size (\d+)',body).group(1)),'private_scratch':int(re.search(r'amdhsa_private_segment_fixed_size (\d+)',body).group(1)),'vgpr':int(re.search(r'amdhsa_next_free_vgpr (\d+)',body).group(1)),'sgpr':int(re.search(r'amdhsa_next_free_sgpr (\d+)',body).group(1))})
receipt['hip_version']=subprocess.check_output(['hipcc','--version'],text=True)
receipt['assembly_sha256']=hashlib.sha256(asm.encode()).hexdigest()
receipt['binary_sha256']=hashlib.sha256(Path('native').read_bytes()).hexdigest()
Path('compile-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
PY
rm -f native-hip-*.bc native-hip-*.o native-hip-*.out native-hip-*.s native-hip-*.hipi native-hip-*.out.resolution.txt native.hip-*.hipfb native-host-*.bc native-host-*.o native-host-*.s native-host-*.hipi
