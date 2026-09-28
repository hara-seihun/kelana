#pragma once
#include "../api.hpp"
#include "sha256.hpp"
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <sstream>
#include <string>
#include <vector>

namespace kbprobe {
inline void checked(hipError_t e) {
    if(e!=hipSuccess){std::fprintf(stderr,"HIP probe failure: %s\n",hipGetErrorString(e));std::exit(1);}
}
}

// timing.hpp also serves the FFN driver, which supplies CHECK itself.
#ifndef CHECK
#define CHECK(call) ::kbprobe::checked(call)
#define KELANA_PROBE_LOCAL_CHECK
#endif
#include "timing.hpp"
#ifdef KELANA_PROBE_LOCAL_CHECK
#undef CHECK
#undef KELANA_PROBE_LOCAL_CHECK
#endif

namespace kbprobe {
struct Case {
    std::string name;
    unsigned long long work_per_call;
    std::function<void(hipStream_t)> launch;
};
struct Config {
    int rows=1;
    int iterations=120;
    int rounds=20;
    int warmup=5;
    int ramp_ms=2000;
    unsigned seed=7319;
    std::string work_unit="MAC";
    std::string scope;
    std::string input_description;
    std::vector<std::string> source_files;
};
inline std::string quote(const std::string &s) {
    std::string r="\"";
    for(unsigned char c:s){
        if(c=='"'||c=='\\'){r+='\\';r+=char(c);}
        else if(c=='\n')r+="\\n";
        else if(c=='\r')r+="\\r";
        else if(c=='\t')r+="\\t";
        else if(c<32){char b[7];std::snprintf(b,sizeof b,"\\u%04x",unsigned(c));r+=b;}
        else r+=char(c);
    }
    return r+'"';
}
inline void fail(const char *why) {std::fprintf(stderr,"Invalid native probe: %s\n",why);std::exit(2);}

// One record group, compatible with paired_analysis.py. It preserves raw elapsed
// times, not rates masquerading as timings. All cases must perform equal work.
inline std::string measure(std::vector<Case> &cases, const Config &config, hipStream_t stream=nullptr) {
    if(!std::getenv("KELANA_GPU_RESEARCH_LOCK"))fail("launch through batched/hardware-run");
    if(cases.empty()||config.rounds<1||config.iterations<config.rounds||config.ramp_ms<1||config.warmup<0)
        fail("empty cases or invalid rounds/iterations/ramp/warmup");
    for(size_t i=0;i<cases.size();++i){
        if(!cases[i].launch||!cases[i].work_per_call||cases[i].work_per_call!=cases[0].work_per_call)
            fail("every case needs a launch and the same positive work count");
        for(size_t j=0;j<i;++j)if(cases[i].name==cases[j].name)fail("duplicate case name");
    }
    if(config.source_files.empty()||config.input_description.empty()||config.scope.empty())
        fail("record source files, input description and comparison scope");
    std::ostringstream sources;sources<<'[';
    for(size_t i=0;i<config.source_files.size();++i){
        const auto sha=kbsha::sha256_file(config.source_files[i]);
        if(sha.empty())fail("cannot fingerprint a declared source file");
        if(i)sources<<',';
        sources<<"{\"path\":"<<quote(config.source_files[i])<<",\"sha256\":"<<quote(sha)<<'}';
    }
    sources<<']';
    const auto binary_sha=kbsha::sha256_file("/proc/self/exe");
    if(binary_sha.empty())fail("cannot fingerprint running executable");
    int device=0;checked(hipGetDevice(&device));hipDeviceProp_t prop{};checked(hipGetDeviceProperties(&prop,device));
    std::vector<kelana_batch::Candidate> adapters;
    adapters.reserve(cases.size());
    for(auto &c:cases)adapters.push_back({c.name.c_str(),kelana_batch::Claim::approximate,
      "Native component timing; correctness is a separate recorded experiment.",nullptr,
      +[](void* state,int,const float*,float*,hipStream_t s){static_cast<Case*>(state)->launch(s);},nullptr,nullptr});
    std::vector<const kelana_batch::Candidate*> candidates;
    std::vector<void*> states;
    for(size_t i=0;i<cases.size();++i){candidates.push_back(&adapters[i]);states.push_back(&cases[i]);}
    const auto clients_before=kbtelemetry::client_snapshot();
    kbtelemetry::Recorder recorder(prop.pciDomainID,prop.pciBusID,prop.pciDeviceID);
    const auto samples=kbtiming::measure(candidates,states,config.rows,nullptr,nullptr,stream,
      config.iterations,config.rounds,config.warmup,config.seed,config.ramp_ms);
    const auto trace=recorder.json();
    const auto clients_after=kbtelemetry::client_snapshot();
    std::ostringstream out;out.precision(17);
    out<<"{\"format\":\"kelana-batch-bench/2\",\"measurement_owner\":\"bench/probe_measure.hpp\","
       <<"\"scope\":"<<quote(config.scope)<<",\"device\":"<<quote(prop.gcnArchName)
       <<",\"seed\":"<<config.seed<<",\"ramp_ms\":"<<config.ramp_ms
       <<",\"executable_sha256\":"<<quote(binary_sha)<<",\"source_files\":"<<sources.str()
       <<",\"input_description\":"<<quote(config.input_description)
       <<",\"work_unit\":"<<quote(config.work_unit)<<",\"work_per_call\":"<<cases[0].work_per_call
       <<",\"clients_before\":"<<clients_before<<",\"clients_after\":"<<clients_after<<",\"runs\":[";
    for(size_t i=0;i<cases.size();++i){
        if(i)out<<',';
        out<<"{\"candidate\":"<<quote(cases[i].name)<<",\"rows\":"<<config.rows<<",\"ms_samples\":[";
        for(size_t j=0;j<samples[i].ms.size();++j){if(j)out<<',';out<<samples[i].ms[j];}
        out<<"],\"timing_blocks\":"<<kbtiming::blocks_json(samples[i])<<'}';
    }
    out<<"],\"telemetry\":[{\"rows\":"<<config.rows<<",\"trace\":"<<trace<<"}]}";
    return out.str();
}
}
