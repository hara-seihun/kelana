// Fixed-format, single-arena causal KIVI2 V interner. No donor quantized events enter this process.
#include <algorithm>
#include <array>
#include <cassert>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cerrno>
#include <fcntl.h>
#include <unistd.h>

constexpr size_t CAP = 266240;
static uint8_t image[CAP], chunk[12288], moving[2048], arrival[4098];
static size_t length = 5, used_peak = 5, moved = 0, compared = 0, inserted = 0;
static size_t quantized = 0, recent = 0, key_chunks = 0, key_recent = 0;

[[noreturn]] void fail(const char* why) { std::fprintf(stderr, "maintain: %s\n", why); std::exit(1); }
void shift(size_t pos, size_t n) {
    if (pos > length || length + n > CAP) fail("arena capacity exhausted");
    moved += length-pos; std::memmove(image+pos+n, image+pos, length-pos); length += n;
    used_peak = std::max(used_peak, length); inserted += n;
}
void erase(size_t pos, size_t n) {
    if (pos+n > length) fail("erase out of bounds");
    moved += length-pos-n; std::memmove(image+pos, image+pos+n, length-pos-n); length -= n;
}
size_t keys_end() { return 5+8*(key_chunks*1536+key_recent*256); }
size_t qbase() { return keys_end(); }
size_t qrefs() { return qbase()+image[3]*384; }
size_t rbase() { return qrefs()+quantized; }
size_t rrefs() { return rbase()+image[4]*2048; }
void invariant() {
    if (length != rrefs()+recent || image[3]>quantized || image[4]>recent || quantized>224 || recent>33) fail("layout invariant");
}
void put_ref(bool q, const uint8_t* record) {
    const size_t width=q?384:2048, base=q?qbase():rbase();
    const size_t count=image[q?3:4], refs=q?qrefs():rrefs();
    size_t found=count;
    for (size_t i=0;i<count;i++) {
        compared++;
        if (!std::memcmp(image+base+i*width, record, width)) { found=i; break; }
    }
    if (found==count) {
        shift(refs, width);
        std::memcpy(image+refs,record,width);
        image[q?3:4]++;
    }
    const size_t end=q?qrefs()+quantized:rrefs()+recent;
    shift(end,1); image[end]=static_cast<uint8_t>(found);
    if(q) quantized++; else recent++;
    invariant();
}
float bf(uint8_t lo, uint8_t hi) {
    uint32_t word=uint32_t(lo | (uint16_t(hi)<<8))<<16;
    float result; std::memcpy(&result,&word,4); return result;
}
void quant(const float* values, size_t count, uint8_t* codes, uint8_t* fields) {
    float lo=values[0], hi=values[0];
    for(size_t i=1;i<count;i++) { lo=std::min(lo,values[i]); hi=std::max(hi,values[i]); }
    double step=(double(hi)-double(lo))/3.0;
    float divisor=static_cast<float>(step);
    for(size_t i=0;i<count;i++) {
        float v=step==0 ? 0 : std::nearbyintf((values[i]-lo)/divisor);
        codes[i]=static_cast<uint8_t>(std::clamp(v,0.0f,3.0f));
    }
    _Float16 low_half=static_cast<_Float16>(lo), step_half=static_cast<_Float16>(step);
    std::memcpy(fields,&low_half,2); std::memcpy(fields+2,&step_half,2);
}
void value_flush() {
    if(recent!=33) fail("V flush schedule");
    size_t base=rbase(), refs=rrefs();
    uint8_t ref=image[refs];
    std::array<float,32> values{};
    uint8_t codes[128], fields[16], packed[384];
    for(size_t h=0;h<8;h++) {
        const uint8_t* source=image+base+size_t(ref)*2048+h*256;
        for(size_t group=0;group<4;group++) {
            for(size_t i=0;i<32;i++) values[i]=bf(source[(group*32+i)*2],source[(group*32+i)*2+1]);
            quant(values.data(),32,codes+group*32,fields+group*4);
        }
        for(size_t i=0;i<32;i++) packed[h*48+i]=codes[i*4] | (codes[i*4+1]<<2) | (codes[i*4+2]<<4) | (codes[i*4+3]<<6);
        std::memcpy(packed+h*48+32,fields,16);
    }
    put_ref(true,packed);
    refs=rrefs(); erase(refs,1); recent--;
    // Canonical first-use permutation of the remaining FIFO references.
    size_t next=0;
    for(size_t p=0;p<recent;p++) {
        refs=rrefs(); uint8_t index=image[refs+p];
        if(index<next) continue;
        if(index!=next) {
            base=rbase();
            std::memcpy(moving,image+base+next*2048,2048);
            std::memcpy(image+base+next*2048,image+base+index*2048,2048);
            std::memcpy(image+base+index*2048,moving,2048);
            moved+=4096;
            for(size_t j=0;j<recent;j++) {
                uint8_t& x=image[refs+j];
                if(x==index) x=static_cast<uint8_t>(next);
                else if(x==next) x=index;
            }
        }
        next++;
    }
    if(next<image[4]) { erase(rbase()+next*2048,(image[4]-next)*2048); image[4]=static_cast<uint8_t>(next); }
    invariant();
}
void key_flush() {
    if(key_recent!=32) fail("K flush schedule");
    for(size_t h=0;h<8;h++) {
        size_t start=5+h*(key_chunks*1536+8192)+key_chunks*1536;
        std::array<float,32> values{}; uint8_t codes[4096], fields[512];
        for(size_t c=0;c<128;c++) {
            for(size_t t=0;t<32;t++) values[t]=bf(image[start+(t*128+c)*2],image[start+(t*128+c)*2+1]);
            uint8_t digits[32]; quant(values.data(),32,digits,fields+c*4);
            for(size_t t=0;t<32;t++) codes[t*128+c]=digits[t];
        }
        for(size_t i=0;i<1024;i++) chunk[h*1536+i]=codes[4*i] | (codes[4*i+1]<<2) | (codes[4*i+2]<<4) | (codes[4*i+3]<<6);
        std::memcpy(chunk+h*1536+1024,fields,512);
    }
    // Process from the last head so prior head offsets remain unchanged.
    for(int h=7;h>=0;h--) {
        size_t start=5+size_t(h)*(key_chunks*1536+8192)+key_chunks*1536;
        // Replace the 8192-byte recent slab by the 1536-byte quantized chunk.
        erase(start,8192); shift(start,1536);
        std::memcpy(image+start,chunk+h*1536,1536);
    }
    key_chunks++; key_recent=0; invariant();
}
void arrival_step(unsigned t) {
    if(arrival[0]!=uint8_t(t) || arrival[1]!=uint8_t(t>>8)) fail("arrival sequence");
    for(int h=7;h>=0;h--) {
        size_t end=5+size_t(h+1)*(key_chunks*1536+key_recent*256);
        shift(end,256); std::memcpy(image+end,arrival+2+h*256,256);
    }
    key_recent++;
    put_ref(false,arrival+2050);
    image[0]=uint8_t(t); image[1]=uint8_t(t>>8); image[2]=0; invariant();
}
void write_exact(const uint8_t* bytes, size_t count) {
    while(count) {
        ssize_t n=::write(STDOUT_FILENO,bytes,count);
        if(n<0 && errno==EINTR) continue;
        if(n<=0) fail("snapshot output");
        bytes+=n; count-=size_t(n);
    }
}
void snapshot() {
    uint32_t n=static_cast<uint32_t>(length);
    write_exact(reinterpret_cast<const uint8_t*>(&n),4);
    write_exact(image,length);
}
int main(int argc, char** argv) {
    if(argc!=2) fail("usage: maintain ARRIVAL-EVENTS.bin");
    int input=::open(argv[1],O_RDONLY); if(input<0) fail("arrival input");
    for(unsigned t=1;t<=256;t++) {
        size_t n=0;
        while(n<sizeof(arrival)) {
            ssize_t got=::read(input,arrival+n,sizeof(arrival)-n);
            if(got<0 && errno==EINTR) continue;
            if(got<=0) fail("short arrivals");
            n+=size_t(got);
        }
        arrival_step(t); snapshot();
        if(key_recent==32) key_flush();
        if(recent==33) value_flush();
        image[2]=1; invariant(); snapshot();
    }
    uint8_t extra;
    if(::read(input,&extra,1)!=0) fail("extra arrivals");
    ::close(input);
    std::fprintf(stderr,"{\"arena_capacity\":%zu,\"arena_used_peak\":%zu,\"reserved_working_bytes\":%zu,\"moved_bytes\":%zu,\"inserted_bytes\":%zu,\"record_comparisons\":%zu,\"final_bytes\":%zu}\n",CAP,used_peak,sizeof(image)+sizeof(chunk)+sizeof(moving)+sizeof(arrival),moved,inserted,compared,length);
}
