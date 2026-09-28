#pragma once
#include "telemetry.hpp"
#include <numeric>
#include <random>

namespace kbtiming {
struct Block {
    int round, order, first_sample, calls;
    long long begin_ns, end_ns;
    double wall_ms;
};
struct Samples {std::vector<double> ms;std::vector<Block> blocks;double wall_ms=0;};
inline std::vector<Samples> measure(
    const std::vector<const kelana_batch::Candidate*> &candidates,
    const std::vector<void*> &states, int rows, const float *input, float *output,
    hipStream_t stream, int iterations, int rounds, int warmup, unsigned seed,
    int ramp_ms = 2000) {
    // A call-count warmup can last only milliseconds. Exercise all candidates
    // before measuring so the first batch does not include the idle-clock ramp.
    const auto ramp_end = kbtelemetry::now_ns() + static_cast<long long>(ramp_ms)*1000000;
    size_t ramp_candidate = 0;
    while (kbtelemetry::now_ns() < ramp_end) {
        const size_t ci = ramp_candidate++ % candidates.size();
        for (int k=0;k<16;++k) candidates[ci]->run(states[ci],rows,input,output,stream);
        CHECK(hipStreamSynchronize(stream));CHECK(hipGetLastError());
    }
    std::vector<Samples> result(candidates.size());
    std::vector<size_t> order(candidates.size());std::iota(order.begin(),order.end(),0);
    std::mt19937 rng(seed);
    for(int round=0;round<rounds;++round) {
        std::shuffle(order.begin(),order.end(),rng);
        const int count=iterations/rounds+(round<iterations%rounds);
        for(size_t position=0;position<order.size();++position) {
            const size_t ci=order[position];auto &r=result[ci];auto c=candidates[ci];
            // Rewarm after changing candidates, so cold competing weight images do not
            // masquerade as steady-state performance. All warmup remains outside timing.
            for(int k=0;k<(round==0?warmup:2);++k)c->run(states[ci],rows,input,output,stream);
            CHECK(hipStreamSynchronize(stream));CHECK(hipGetLastError());
            std::vector<hipEvent_t> begin(count),end(count);
            for(int k=0;k<count;++k){CHECK(hipEventCreate(&begin[k]));CHECK(hipEventCreate(&end[k]));}
            Block block{round,int(position),int(r.ms.size()),count,kbtelemetry::now_ns(),0,0};
            for(int k=0;k<count;++k){
                CHECK(hipEventRecord(begin[k],stream));c->run(states[ci],rows,input,output,stream);
                CHECK(hipEventRecord(end[k],stream));
            }
            CHECK(hipStreamSynchronize(stream));CHECK(hipGetLastError());
            block.end_ns=kbtelemetry::now_ns();block.wall_ms=(block.end_ns-block.begin_ns)*1e-6;
            r.wall_ms+=block.wall_ms;r.blocks.push_back(block);
            for(int k=0;k<count;++k){float ms=0;CHECK(hipEventElapsedTime(&ms,begin[k],end[k]));
                r.ms.push_back(ms);CHECK(hipEventDestroy(begin[k]));CHECK(hipEventDestroy(end[k]));}
        }
    }
    return result;
}
inline std::string blocks_json(const Samples &s){
    std::ostringstream o;o.precision(17);o<<'[';bool first=true;
    for(const auto &b:s.blocks){if(!first)o<<',';first=false;
        o<<"{\"round\":"<<b.round<<",\"order\":"<<b.order<<",\"first_sample\":"<<b.first_sample
         <<",\"calls\":"<<b.calls<<",\"begin_ns\":"<<b.begin_ns<<",\"end_ns\":"<<b.end_ns
         <<",\"wall_ms\":"<<b.wall_ms<<'}';}
    o<<']';return o.str();
}
}
