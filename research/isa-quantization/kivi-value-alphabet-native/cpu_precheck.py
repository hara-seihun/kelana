"""Stream independent original control states and frozen candidate V events into physical maps."""
import json,struct,subprocess,sys,tempfile
from pathlib import Path
import audit
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
SIZE=audit.SIZE

def run(tag):
    arrival,histories=audit.source(tag)
    with tempfile.TemporaryFile() as output:
        for mode in (0,1):
            proc=subprocess.Popen([str(HERE/'cpu-reference'),str(ROOT/'kivi-value-intern'/f'{tag}-events.bin'),'control'],stdout=subprocess.PIPE)
            try:
                for t in range(1,257):
                    for phase in (0,1):
                        header=proc.stdout.read(8)
                        assert len(header)==8
                        arm,ph,stamp,n=struct.unpack('<BBHI',header)
                        assert (arm,ph,stamp,n)==(0,phase,t,SIZE)
                        blob=bytearray(proc.stdout.read(n));assert len(blob)==n
                        if mode:
                            nv=max(0,t-33)+(phase if t>=33 else 0)
                            for h,(_,_,candidate,_,_) in enumerate(histories):
                                at=8*audit.KC+h*224*48
                                blob[at:at+nv*48]=b''.join(candidate[:nv])
                            header=struct.pack('<BBHI',mode,phase,t,SIZE)
                        output.write(header);output.write(blob)
                assert proc.stdout.read(1)==b'' and proc.wait(timeout=5)==0
            finally:
                if proc.poll() is None:proc.kill();proc.wait()
        output.seek(0)
        # audit accepts a path; /proc/self/fd resolves the streamed temporary file.
        result=audit.audit(tag,f'/proc/self/fd/{output.fileno()}')
    return result
if __name__=='__main__':print(json.dumps(run(sys.argv[1])))
