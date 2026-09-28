// Fixed-slot causal KIVI2 cache. Slot addresses are stable until reference count reaches zero.
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cerrno>
#include <fcntl.h>
#include <unistd.h>

constexpr unsigned QC=148, RC=33, KS=18944;
static uint8_t keys[8][KS], qslot[QC][384], rslot[RC][2048];
static uint8_t qrefs[224], rrefs[33], qcount[QC], rcount[RC], arrival[4098];
static uint8_t codes[4096], fields[512], packed[1536];
static unsigned nq=0,nr=0,kchunks=0,krecent=0,rhead=0, tnow=0, phase=0;
static uint64_t comparisons=0, compared_bytes=0, written_records=0, input_bytes=0, snapshots=0;
static unsigned qpeak=0,rpeak=0;
[[noreturn]] void fail(const char* why) { std::fprintf(stderr,"stable: %s at t=%u phase=%u\n",why,tnow,phase); std::exit(1); }
void output(const void* p,size_t n) {
    auto* b=static_cast<const uint8_t*>(p);
    while(n) { ssize_t got=::write(1,b,n); if(got<0 && errno==EINTR) continue; if(got<=0) fail("output"); b+=got; n-=size_t(got); }
}
void input(int fd,void* p,size_t n) {
    auto* b=static_cast<uint8_t*>(p);
    while(n) { ssize_t got=::read(fd,b,n); if(got<0 && errno==EINTR) continue; if(got<=0) fail("short arrival"); b+=got; n-=size_t(got); }
    input_bytes+=4098;
}
float bf(const uint8_t* p) {
    uint32_t bits=uint32_t(p[0] | (uint16_t(p[1])<<8))<<16;
    float v; std::memcpy(&v,&bits,4); return v;
}
void quant(const float* values,unsigned count,uint8_t* digits,uint8_t* halfs) {
    float lo=values[0], hi=values[0];
    for(unsigned i=1;i<count;i++) { lo=std::min(lo,values[i]); hi=std::max(hi,values[i]); }
    double step=(double(hi)-double(lo))/3.0;
    float divisor=static_cast<float>(step);
    for(unsigned i=0;i<count;i++) {
        float v=step==0?0:std::nearbyintf((values[i]-lo)/divisor);
        digits[i]=uint8_t(std::clamp(v,0.0f,3.0f));
    }
    _Float16 a=static_cast<_Float16>(lo), b=static_cast<_Float16>(step);
    std::memcpy(halfs,&a,2); std::memcpy(halfs+2,&b,2);
}
unsigned intern_recent(const uint8_t* rec) {
    unsigned free_slot=RC;
    for(unsigned s=0;s<RC;s++) {
        if(!rcount[s]) { if(free_slot==RC) free_slot=s; continue; }
        comparisons++; compared_bytes+=2048;
        if(!std::memcmp(rslot[s],rec,2048)) { rcount[s]++; return s; }
    }
    if(free_slot==RC) fail("recent admission");
    std::memcpy(rslot[free_slot],rec,2048); written_records+=2048;
    rcount[free_slot]=1; return free_slot;
}
unsigned intern_quant(const uint8_t* rec) {
    unsigned free_slot=QC;
    for(unsigned s=0;s<QC;s++) {
        if(!qcount[s]) { if(free_slot==QC) free_slot=s; continue; }
        comparisons++; compared_bytes+=384;
        if(!std::memcmp(qslot[s],rec,384)) { qcount[s]++; return s; }
    }
    if(free_slot==QC) fail("quant admission");
    std::memcpy(qslot[free_slot],rec,384); written_records+=384;
    qcount[free_slot]=1; return free_slot;
}
void snapshot() {
    unsigned qactive=0,ractive=0;
    for(auto x:qcount) qactive+=x!=0;
    for(auto x:rcount) ractive+=x!=0;
    qpeak=std::max(qpeak,qactive); rpeak=std::max(rpeak,ractive);
    unsigned size=7+8*(kchunks*1536+krecent*256)+nq+nr+qactive*386+ractive*2050;
    uint8_t size_le[4]={uint8_t(size),uint8_t(size>>8),uint8_t(size>>16),uint8_t(size>>24)};
    uint8_t header[7]={uint8_t(tnow),uint8_t(tnow>>8),uint8_t(phase),uint8_t(qactive),uint8_t(ractive),uint8_t(kchunks),uint8_t(krecent)};
    output(size_le,4); output(header,7);
    for(unsigned h=0;h<8;h++) output(keys[h],kchunks*1536+krecent*256);
    output(qrefs,nq);
    for(unsigned j=0;j<nr;j++) output(&rrefs[(rhead+j)%RC],1);
    for(unsigned s=0;s<QC;s++) if(qcount[s]) { uint8_t head[2]={uint8_t(s),qcount[s]}; output(head,2); output(qslot[s],384); }
    for(unsigned s=0;s<RC;s++) if(rcount[s]) { uint8_t head[2]={uint8_t(s),rcount[s]}; output(head,2); output(rslot[s],2048); }
    snapshots++;
}
void flush_key() {
    if(krecent!=32) fail("K schedule");
    for(unsigned h=0;h<8;h++) {
        uint8_t* recent=keys[h]+kchunks*1536;
        float values[32]; uint8_t digits[32];
        for(unsigned c=0;c<128;c++) {
            for(unsigned i=0;i<32;i++) values[i]=bf(recent+(i*128+c)*2);
            quant(values,32,digits,fields+c*4);
            for(unsigned i=0;i<32;i++) codes[i*128+c]=digits[i];
        }
        for(unsigned i=0;i<1024;i++) packed[i]=codes[i*4] | (codes[i*4+1]<<2) | (codes[i*4+2]<<4) | (codes[i*4+3]<<6);
        std::memcpy(packed+1024,fields,512);
        std::memcpy(recent,packed,1536); written_records+=1536;
    }
    kchunks++; krecent=0;
}
void flush_value() {
    if(nr!=33 || nq>=224) fail("V schedule");
    unsigned oldest=rrefs[rhead];
    float values[32]; uint8_t digits[128], halfs[16], record[384];
    for(unsigned h=0;h<8;h++) {
        auto* src=rslot[oldest]+h*256;
        for(unsigned g=0;g<4;g++) {
            for(unsigned i=0;i<32;i++) values[i]=bf(src+2*(g*32+i));
            quant(values,32,digits+g*32,halfs+g*4);
        }
        for(unsigned i=0;i<32;i++) record[h*48+i]=digits[i*4] | (digits[i*4+1]<<2) | (digits[i*4+2]<<4) | (digits[i*4+3]<<6);
        std::memcpy(record+h*48+32,halfs,16);
    }
    qrefs[nq++]=uint8_t(intern_quant(record));
    if(!rcount[oldest]) fail("reference underflow");
    rcount[oldest]--; rhead=(rhead+1)%RC; nr--;
}
int main(int argc,char** argv) {
    if(argc!=2) fail("usage: stable ARRIVALS.bin");
    int fd=::open(argv[1],O_RDONLY); if(fd<0) fail("open arrivals");
    for(unsigned t=1;t<=256;t++) {
        tnow=t; phase=0; input(fd,arrival,sizeof(arrival));
        if(unsigned(arrival[0] | (uint16_t(arrival[1])<<8))!=t) fail("arrival order");
        if(kchunks*1536+(krecent+1)*256>KS) fail("key admission");
        for(unsigned h=0;h<8;h++) std::memcpy(keys[h]+kchunks*1536+krecent*256,arrival+2+h*256,256);
        written_records+=2048; krecent++;
        if(nr==RC) fail("recent ring admission");
        rrefs[(rhead+nr)%RC]=uint8_t(intern_recent(arrival+2050)); nr++;
        snapshot();
        if(krecent==32) flush_key();
        if(nr==33) flush_value();
        phase=1; snapshot();
    }
    uint8_t trailing; if(::read(fd,&trailing,1)!=0) fail("trailing arrivals"); ::close(fd);
    std::fprintf(stderr,"{\"quant_peak\":%u,\"recent_peak\":%u,\"comparisons\":%llu,\"compared_upper_bytes\":%llu,\"record_write_bytes\":%llu,\"input_bytes\":%llu,\"snapshots\":%llu,\"reserved_arrays\":%zu}\n",qpeak,rpeak,(unsigned long long)comparisons,(unsigned long long)compared_bytes,(unsigned long long)written_records,(unsigned long long)input_bytes,(unsigned long long)snapshots,sizeof(keys)+sizeof(qslot)+sizeof(rslot)+sizeof(qrefs)+sizeof(rrefs)+sizeof(qcount)+sizeof(rcount)+sizeof(arrival)+sizeof(codes)+sizeof(fields)+sizeof(packed));
}
