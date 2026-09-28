// CPU-side fixed physical coordinates. Uses the independently audited stable-slot maintainer
// as a quantization/transition oracle, then emits this candidate's exact raw layout.
#define main stable_records_entry
#include "../kivi-stable-records/stable.cpp"
#undef main
#include <vector>
struct DeviceImage {
    uint8_t key[8][18944], quant[148][384], recent[33][2048];
    uint8_t qref[224],rref[33],qcount[148],rcount[33];
    int32_t t,phase,nq,nr,error;
};
static_assert(sizeof(DeviceImage)==276428);
struct ControlImage {
    uint8_t key[8][18944],quant[8][224*48],recent[8][33*256];
    int32_t error;
};
static_assert(sizeof(ControlImage)==305156);
int chosen_mode=1;
void frame() {
    if(!chosen_mode) {
        ControlImage image{};
        std::memcpy(image.key,keys,sizeof(keys));
        for(unsigned j=0;j<nq;j++)for(unsigned h=0;h<8;h++)
            std::memcpy(image.quant[h]+48*j,qslot[qrefs[j]]+48*h,48);
        for(unsigned j=0;j<nr;j++)for(unsigned h=0;h<8;h++)
            std::memcpy(image.recent[h]+((tnow-nr+j)%33)*256,rslot[rrefs[(rhead+j)%33]]+256*h,256);
        uint8_t head[8]={0,uint8_t(phase),uint8_t(tnow),uint8_t(tnow>>8),uint8_t(sizeof(image)),uint8_t(sizeof(image)>>8),uint8_t(sizeof(image)>>16),uint8_t(sizeof(image)>>24)};
        output(head,8);output(&image,sizeof(image));return;
    }
    DeviceImage image{};
    std::memcpy(image.key,keys,sizeof(keys));
    for(int s=0;s<148;s++)if(qcount[s])std::memcpy(image.quant[s],qslot[s],384);
    for(int s=0;s<33;s++)if(rcount[s])std::memcpy(image.recent[s],rslot[s],2048);
    std::memcpy(image.qref,qrefs,sizeof(qrefs));
    for(unsigned j=0;j<nr;j++)image.rref[(tnow-nr+j)%33]=rrefs[(rhead+j)%33];
    std::memcpy(image.qcount,qcount,sizeof(qcount));std::memcpy(image.rcount,rcount,sizeof(rcount));
    image.t=tnow;image.phase=phase;image.nq=nq;image.nr=nr;
    uint8_t head[8]={1,uint8_t(phase),uint8_t(tnow),uint8_t(tnow>>8),uint8_t(sizeof(image)),uint8_t(sizeof(image)>>8),uint8_t(sizeof(image)>>16),uint8_t(sizeof(image)>>24)};
    output(head,8);output(&image,sizeof(image));
}
int main(int argc,char** argv) {
    if(argc!=3 || (std::strcmp(argv[2],"stable") && std::strcmp(argv[2],"control")))fail("usage: cpu ARRIVALS.bin stable|control");
    chosen_mode=std::strcmp(argv[2],"stable")==0;
    int fd=::open(argv[1],O_RDONLY);if(fd<0)fail("open arrivals");
    for(unsigned t=1;t<=256;t++) {
        tnow=t;phase=0;input(fd,arrival,sizeof(arrival));
        if(unsigned(arrival[0] | (uint16_t(arrival[1])<<8))!=t)fail("arrival order");
        if(kchunks*1536+(krecent+1)*256>KS)fail("key admission");
        for(unsigned h=0;h<8;h++)std::memcpy(keys[h]+kchunks*1536+krecent*256,arrival+2+h*256,256);
        krecent++;
        if(nr==RC)fail("recent admission");
        rrefs[(rhead+nr)%RC]=uint8_t(intern_recent(arrival+2050));nr++;
        frame();
        if(krecent==32)flush_key();
        if(nr==33)flush_value();
        phase=1;frame();
    }
    uint8_t trailing;if(::read(fd,&trailing,1)!=0)fail("trailing arrivals");::close(fd);
}
