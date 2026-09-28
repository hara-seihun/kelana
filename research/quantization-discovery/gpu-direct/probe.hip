#include <hip/hip_runtime.h>
#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <numeric>
#include <random>
#include <stdexcept>
#include <string>
#include <vector>

constexpr int R=5120, K=128, C=43;
#define HIP(x) do { hipError_t e=(x); if(e!=hipSuccess) throw std::runtime_error(hipGetErrorString(e)); } while(0)

// Each wave owns 32 independent rows. Every lane makes one response for the
// current query; the key selects that lane's register through wave shuffle.
__global__ void evaluate(const uint8_t* folded, const uint8_t* bytekeys,
                         const uint8_t* dense, const uint8_t* two,
                         const int8_t* query, int32_t* out, int mode) {
    int row=blockIdx.x*blockDim.x+threadIdx.x;
    if(row>=R) return;
    int lane=threadIdx.x&31, sum=0;
    if(mode==0 || mode==3) {
        int offset=0;
        for(int c=0;c<C;c++) {
            int length=c==42?2:3, width=c==42?4:5;
            int key;
            if(mode==3) key=bytekeys[c*R+row];
            else {
                int bit=row*width, pos=offset+(bit>>3), shift=bit&7;
                int word=folded[pos];
                if(shift+width>8) word|=int(folded[pos+1])<<8;
                key=(word>>shift)&((1<<width)-1);
            }
            int rep=key&((1<<(width-1))-1);
            int sign=(key>>(width-1))&1;
            // Lane 13 is the zero orbit. Lanes 14 and 15 are never selected.
            int code=lane&15;
            int response=(code%3-1)*int(query[3*c]) +
                         ((code/3)%3-1)*int(query[3*c+1]);
            if(length==3) response+=((code/9)%3-1)*int(query[3*c+2]);
            int selected=__shfl(response,rep,32);
            sum+=sign?-selected:selected;
            offset+=(R*width)/8;
        }
    } else if(mode==1) {
        for(int j=0;j<K;j++) sum+=int(int8_t(dense[row*K+j]))*int(query[j]);
    } else {
        for(int j=0;j<K;j++) {
            int code=(two[row*32+(j>>2)]>>((j&3)*2))&3;
            sum+=(code-1)*int(query[j]);
        }
    }
    out[row]=sum;
}

template<class T> std::vector<T> load(const std::string& path,size_t count) {
    std::vector<T> v(count); std::ifstream f(path,std::ios::binary);
    if(!f.read(reinterpret_cast<char*>(v.data()),count*sizeof(T))) throw std::runtime_error("cannot load "+path);
    return v;
}
void store(const std::string& path,const std::string& value) {
    std::ofstream f(path); f<<value;
}
int main(int argc,char** argv) {
 try {
    if(argc!=4) throw std::runtime_error("usage: probe WEIGHTS.i8 QUERIES.i8 RESULTS.json");
    auto w=load<int8_t>(argv[1],R*K);
    auto qs=load<int8_t>(argv[2],12*K);
    std::vector<uint8_t> folded, bytekeys(C*R), dense(w.begin(),w.end()), two(R*32,0);
    for(int row=0;row<R;row++) for(int j=0;j<K;j++) {
        int v=w[row*K+j];
        if(v < -1 || v > 1) throw std::runtime_error("non-ternary weight");
        two[row*32+(j>>2)]|=uint8_t(v+1)<<((j&3)*2);
    }
    for(int c=0;c<C;c++) {
        int length=c==42?2:3, width=c==42?4:5, count=length==2?9:27;
        size_t base=folded.size(); folded.resize(base+(R*width)/8,0);
        for(int row=0;row<R;row++) {
            int code=0, factor=1;
            for(int j=0;j<length;j++) {code+=(int(w[row*K+3*c+j])+1)*factor;factor*=3;}
            int rep=std::min(code,count-1-code), sign=code>count-1-code;
            int key=rep|(sign<<(width-1)); bytekeys[c*R+row]=key;
            int bit=row*width;
            folded[base+(bit>>3)]|=uint8_t(key<<(bit&7));
            if((bit&7)+width>8) folded[base+(bit>>3)+1]|=uint8_t(key>>(8-(bit&7)));
        }
    }
    // Independent host roundtrip over the serialized image, including the tail.
    size_t offset=0;
    for(int c=0;c<C;c++) {
        int length=c==42?2:3,width=c==42?4:5,count=length==2?9:27;
        for(int row=0;row<R;row++) {
            int bit=row*width, val=folded[offset+(bit>>3)];
            if((bit&7)+width>8) val|=int(folded[offset+(bit>>3)+1])<<8;
            int key=(val>>(bit&7))&((1<<width)-1);
            if(key!=bytekeys[c*R+row]) throw std::runtime_error("packed key mismatch");
            int code=key&((1<<(width-1))-1);
            if(code>=(count+1)/2) throw std::runtime_error("invalid orbit");
            if(key>>(width-1)) code=count-1-code;
            for(int j=0;j<length;j++) {
                if(code%3-1!=w[row*K+3*c+j]) throw std::runtime_error("wire mismatch");
                code/=3;
            }
        }
        offset+=(R*width)/8;
    }
    uint8_t *fw,*bk,*dw,*tw; int8_t* q; int32_t* out;
    HIP(hipMalloc(&fw,folded.size())); HIP(hipMalloc(&bk,bytekeys.size()));
    HIP(hipMalloc(&dw,dense.size())); HIP(hipMalloc(&tw,two.size()));
    HIP(hipMalloc(&q,qs.size())); HIP(hipMalloc(&out,R*sizeof(int32_t)));
    HIP(hipMemcpy(fw,folded.data(),folded.size(),hipMemcpyHostToDevice));
    HIP(hipMemcpy(bk,bytekeys.data(),bytekeys.size(),hipMemcpyHostToDevice));
    HIP(hipMemcpy(dw,dense.data(),dense.size(),hipMemcpyHostToDevice));
    HIP(hipMemcpy(tw,two.data(),two.size(),hipMemcpyHostToDevice));
    HIP(hipMemcpy(q,qs.data(),qs.size(),hipMemcpyHostToDevice));
    std::vector<int32_t> got(R);
    auto launch=[&](int i,int mode){hipLaunchKernelGGL(evaluate,dim3((R+127)/128),dim3(128),0,0,fw,bk,dw,tw,q+i*K,out,mode);HIP(hipGetLastError());};
    for(int i=0;i<12;i++) for(int mode=0;mode<4;mode++) {
        launch(i,mode);HIP(hipMemcpy(got.data(),out,R*4,hipMemcpyDeviceToHost));
        for(int row=0;row<R;row++) {
            int expected=0;
            for(int j=0;j<K;j++) expected+=int(w[row*K+j])*int(qs[i*K+j]);
            if(got[row]!=expected) throw std::runtime_error("GPU mismatch query="+std::to_string(i)+" mode="+std::to_string(mode)+" row="+std::to_string(row));
        }
    }
    hipFuncAttributes attr{};HIP(hipFuncGetAttributes(&attr,(void*)evaluate));
    int active=0;HIP(hipOccupancyMaxActiveBlocksPerMultiprocessor(&active,evaluate,128,0));
    hipDeviceProp_t prop{};HIP(hipGetDeviceProperties(&prop,0));
    hipEvent_t begin,end;HIP(hipEventCreate(&begin));HIP(hipEventCreate(&end));
    std::array<std::vector<float>,4> times;
    // Interleave controls and candidate for every query, rotating their order.
    for(int round=0;round<9;round++) for(int i=0;i<12;i++) for(int step=0;step<4;step++) {
        int mode=(round+i+step)%4;
        launch(i,mode); HIP(hipDeviceSynchronize());
        HIP(hipEventRecord(begin));
        for(int repeat=0;repeat<32;repeat++) launch(i,mode);
        HIP(hipEventRecord(end));HIP(hipEventSynchronize(end));
        float ms; HIP(hipEventElapsedTime(&ms,begin,end));
        times[mode].push_back(ms*1000/32);
    }
    const char* names[]={"folded_packed_shuffle","dense_int8","two_bit_decode","folded_byte_shuffle"};
    std::string json="{\n  \"device\": \""+std::string(prop.name)+"\", \"rows\": 5120, \"columns\": 128, \"queries\": 12, \"rounds\": 9, \"calls_per_sample\": 32, \"correct_outputs\": 48,\n";
    json+="  \"scale_bytes\": 10240, \"weight_bytes\": {\"folded_packed_shuffle\": "+std::to_string(folded.size())+", \"dense_int8\": "+std::to_string(dense.size())+", \"two_bit_decode\": "+std::to_string(two.size())+", \"folded_byte_shuffle\": "+std::to_string(bytekeys.size())+"},\n";
    json+="  \"scratch_bytes\": {\"folded_packed_shuffle\": 0, \"folded_byte_shuffle\": 0, \"dense_int8\": 0, \"two_bit_decode\": 0}, \"query_bytes\": 128, \"output_bytes\": 20480,\n";
    json+="  \"kernel_resources\": {\"registers_per_thread\": "+std::to_string(attr.numRegs)+", \"static_shared_bytes\": "+std::to_string(attr.sharedSizeBytes)+", \"max_active_blocks_per_multiprocessor_at_128_threads\": "+std::to_string(active)+", \"multiprocessor_count\": "+std::to_string(prop.multiProcessorCount)+"},\n  \"us_per_kernel\": {\n";
    for(int mode=0;mode<4;mode++) {
        json+="    \""+std::string(names[mode])+"\": [";
        for(size_t k=0;k<times[mode].size();k++) {if(k)json+=",";json+=std::to_string(times[mode][k]);}
        json+="]";json+=mode==3?"\n":",\n";
    }
    json+="  }\n}\n";store(argv[3],json);
    for(int mode=0;mode<4;mode++) {
        auto v=times[mode];std::sort(v.begin(),v.end());
        printf("%s %.4f us\n",names[mode],v[v.size()/2]);
    }
    hipFree(fw);hipFree(bk);hipFree(dw);hipFree(tw);hipFree(q);hipFree(out);
 } catch(const std::exception& e) {fprintf(stderr,"probe: %s\n",e.what());return 1;}
}
