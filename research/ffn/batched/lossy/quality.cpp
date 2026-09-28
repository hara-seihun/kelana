#include "policy.hpp"
#include "engine.h"
#include "tokenizer.h"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

using namespace halo;
struct Observation { int prompt,position,target;std::vector<float> logits; };
struct Config { int bits,layers,stochastic,consumer=0; };
Config parse_config(const std::string &entry) {
    Config c{};
    int fields=std::sscanf(entry.c_str(),"%d:%d:%d:%d",&c.bits,&c.layers,&c.stochastic,&c.consumer);
    if(fields<3 || c.bits<2 || c.bits>8 || c.layers<0 || c.layers>64 ||
        c.stochastic<0 || c.stochastic>1 || c.consumer<0 || c.consumer>4)
        throw std::runtime_error("invalid config "+entry);
    return c;
}
struct Metrics { double kl=0,tv=0,nll_delta=0,max_logit=0,entropy=0;bool changed=false; };
Metrics compare(const Observation &a,const Observation &b){
    if(a.logits.size()!=b.logits.size())throw std::runtime_error("logit shape mismatch");
    double ma=*std::max_element(a.logits.begin(),a.logits.end());
    double mb=*std::max_element(b.logits.begin(),b.logits.end());
    double za=0,zb=0;
    for(size_t i=0;i<a.logits.size();++i){
        if(!std::isfinite(a.logits[i]) || !std::isfinite(b.logits[i]))throw std::runtime_error("nonfinite logit");
        za+=std::exp(double(a.logits[i])-ma);zb+=std::exp(double(b.logits[i])-mb);
    }
    za=ma+std::log(za);zb=mb+std::log(zb);
    Metrics m;
    for(size_t i=0;i<a.logits.size();++i){
        double la=a.logits[i]-za,lb=b.logits[i]-zb,p=std::exp(la),q=std::exp(lb);
        m.kl+=p*(la-lb);m.tv+=std::fabs(p-q)/2;m.entropy-=p*la;
        m.max_logit=std::max(m.max_logit,std::fabs(double(a.logits[i])-b.logits[i]));
    }
    m.nll_delta=(zb-b.logits[a.target])-(za-a.logits[a.target]);
    m.changed=std::max_element(a.logits.begin(),a.logits.end())-a.logits.begin()!=
              std::max_element(b.logits.begin(),b.logits.end())-b.logits.begin();
    return m;
}
int main(int argc,char **argv)try{
    std::string model="/path/to/workspace/data/bonsai2/PTQ1_0.gguf",out;
    int tokens=64,seed=812735;
    bool direct=false,down=false;
    std::string reference_config="8:0:0:0";
    std::string configuration="8:0:0,4:1:0,4:8:0,4:32:0,4:64:0,6:64:0,4:64:1";
    for(int i=1;i<argc;++i){
        std::string a=argv[i];auto next=[&]{if(i+1>=argc)throw std::runtime_error("missing argument");return std::string(argv[++i]);};
        if(a=="--out")out=next();else if(a=="--tokens")tokens=std::stoi(next());
        else if(a=="--seed")seed=std::stoi(next());else if(a=="--configs")configuration=next();
        else if(a=="--direct")direct=true;else if(a=="--down")down=true;
        else if(a=="--reference")reference_config=next();
        else if(a=="--model")model=next();else throw std::runtime_error("unknown argument "+a);
    }
    if(out.empty() || tokens<8 || tokens%8)throw std::runtime_error("--out FILE and token count divisible by8 required");
    std::vector<Config> configs;std::stringstream cs(configuration);std::string entry;
    while(std::getline(cs,entry,',')){
        Config c=parse_config(entry);
        if(direct && c.stochastic)throw std::runtime_error("direct quantization currently supports nearest rounding; choose --configs without stochastic entries");
        configs.push_back(c);
    }
    std::vector<std::string> prompts={
        "A researcher is comparing two ways to multiply matrices. The first method performs every multiplication separately. The second method shares intermediate sums across many outputs. To make a fair comparison, she records the cost of preparing the inputs, reading the weights, and producing the final answers. She also checks that rounding errors do not accumulate when the same computation appears repeatedly in a larger system. Explain why a reduction in the number of arithmetic instructions does not necessarily imply a reduction in total running time, and give an example involving memory access.",
        "On Saturday morning, the train left the coastal town and climbed into the mountains. Maya had packed a notebook, a small camera, and enough food for the afternoon. At the next station she met an engineer who was travelling to inspect a bridge. They discussed the weather and the history of the railway before the conversation turned to the unusual rock formations outside the window. By noon, clouds had gathered over the highest peaks, but the valley below was still bright. Describe what they might notice as the train approaches the old stone viaduct."
    };
    Tokenizer tokenizer;tokenizer.load(model);
    std::vector<std::vector<int>> tokenized;
    for(auto &p:prompts){auto t=tokenizer.encode(p,false);if(int(t.size())<tokens+1)throw std::runtime_error("prompt too short");t.resize(tokens+1);tokenized.push_back(std::move(t));}
    unsetenv("HALO_STOP");unsetenv("HALO_LAYERS");unsetenv("HALO_DUMP");
    Engine engine;engine.load(model,8,1);
    auto evaluate=[&](Config c,unsigned (&counts)[64]){
        std::vector<Observation> observations;reset_quant_counts();
        uint64_t mask=c.layers==64?~uint64_t(0):((uint64_t(1)<<c.layers)-1);
        unsigned sample=0;
        for(size_t p=0;p<tokenized.size();++p){
            engine.reset();
            for(int pos=0;pos<tokens;pos+=8){
                set_quant_policy({mask,unsigned(seed),sample++,c.bits,c.stochastic,int(direct),int(down),c.consumer});
                std::vector<Engine::Seq*> sequences{&engine.seq0};
                std::vector<std::vector<int>> input{std::vector<int>(tokenized[p].begin()+pos,tokenized[p].begin()+pos+8)};
                std::vector<int> argmax;engine.forward(sequences,input,true,&argmax);
                for(int row=0;row<8;++row){
                    Observation o{int(p),pos+row,tokenized[p][pos+row+1],{}};
                    engine.get_logits(o.logits,row);
                    observations.push_back(std::move(o));
                }
            }
        }
        read_quant_counts(counts);
        unsigned expected=unsigned(prompts.size()*tokens*((halo::D+(down?halo::FF:0))/1024));
        for(int l=0;l<64;++l)if(counts[l]!=(c.bits<8 && l<c.layers?expected:0u))
            throw std::runtime_error("intervention count mismatch at layer "+std::to_string(l)+": "+std::to_string(counts[l]));
        unsigned consumers[64];read_consumer_counts(consumers);
        unsigned expected_consumer=unsigned(prompts.size()*tokens*(halo::FF/1024));
        for(int l=0;l<64;++l)if(consumers[l]!=(c.consumer && l<c.layers?expected_consumer:0u))
            throw std::runtime_error("consumer intervention count mismatch at layer "+std::to_string(l));
        return observations;
    };
    unsigned counts[64],consumers[64];
    Config reference=parse_config(reference_config);
    if(direct && reference.stochastic)throw std::runtime_error("direct stochastic reference unsupported");
    auto baseline=evaluate(reference,counts);
    std::ofstream file(out);if(!file)throw std::runtime_error("cannot open output");
    file<<std::setprecision(17)<<"{\n\"format\":\"kelana-lossy-quality/1\",\n\"tokens_per_prompt\":"<<tokens
        <<",\n\"prompts\":2,\n\"seed\":"<<seed
        <<",\n\"reference_config\":\""<<reference_config<<"\""
        <<",\n\"direct_float_quantization\":"<<(direct?"true":"false")
        <<",\n\"include_down_input\":"<<(down?"true":"false")
        <<",\n\"scope\":\"Native full-model teacher-forced logits; selected FFN activation quantizers and optional packed-half polynomial consumer. The consumer intervention rounds completed FP32 gate/up projections, not their internal accumulation. No throughput claim.\",\n\"token_ids\":[";
    for(size_t p=0;p<tokenized.size();++p){if(p)file<<',';file<<'[';for(size_t j=0;j<tokenized[p].size();++j){if(j)file<<',';file<<tokenized[p][j];}file<<']';}
    file<<"],\n\"configurations\":[\n";bool first=true;
    for(auto c:configs){
        auto observed=evaluate(c,counts);read_consumer_counts(consumers);
        if(!first)file<<",\n";first=false;
        file<<"{\"bits\":"<<c.bits<<",\"first_layers\":"<<c.layers<<",\"stochastic\":"<<c.stochastic<<",\"consumer\":"<<c.consumer<<",\"positions\":[";
        double kl=0,maxkl=0,nll=0,tv=0;int changed=0;
        for(size_t i=0;i<baseline.size();++i){
            auto m=compare(baseline[i],observed[i]);kl+=m.kl;nll+=m.nll_delta;tv+=m.tv;changed+=m.changed;maxkl=std::max(maxkl,m.kl);
            if(i)file<<',';
            file<<"{\"prompt\":"<<baseline[i].prompt<<",\"position\":"<<baseline[i].position
                <<",\"kl_ref_candidate\":"<<m.kl<<",\"total_variation\":"<<m.tv
                <<",\"target_nll_delta\":"<<m.nll_delta<<",\"top1_changed\":"<<(m.changed?"true":"false")
                <<",\"max_logit_error\":"<<m.max_logit<<",\"reference_entropy\":"<<m.entropy<<'}';
        }
        double n=double(baseline.size());
        file<<"],\"mean_kl\":"<<kl/n<<",\"max_kl\":"<<maxkl<<",\"mean_total_variation\":"<<tv/n
            <<",\"mean_target_nll_delta\":"<<nll/n<<",\"top1_changed_count\":"<<changed<<",\"scored_positions\":"<<baseline.size()<<",\"intervention_chunks_per_selected_layer\":"<<(c.layers?counts[0]:0)<<",\"consumer_chunks_per_selected_layer\":"<<(c.layers?consumers[0]:0)<<'}';file.flush();
        std::fprintf(stderr,"A%d first%d consumer%d %s KL %.6g max %.6g TV %.6g NLLdelta %.6g top1 %d/%zu\n",c.bits,c.layers,c.consumer,c.stochastic?"stochastic":"nearest",kl/n,maxkl,tv/n,nll/n,changed,baseline.size());
    }
    file<<"\n]}\n";
    return 0;
}catch(const std::exception&e){std::fprintf(stderr,"quality-probe: %s\n",e.what());return 1;}
