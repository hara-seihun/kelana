#include "engine.h"
#include "tokenizer.h"
#include <hip/hip_runtime.h>
#include <array>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

using namespace halo;
namespace fs=std::filesystem;

template<class T> void capture(const fs::path& path,const T* device,size_t count) {
    std::vector<T> h(count);
    HIP_CHECK_H(hipMemcpy(h.data(),device,count*sizeof(T),hipMemcpyDeviceToHost));
    std::ofstream f(path,std::ios::binary);
    if(!f.write(reinterpret_cast<const char*>(h.data()),count*sizeof(T)))
        throw std::runtime_error("cannot write "+path.string());
}
int main(int argc,char** argv) {
 try {
    if(argc!=4)throw std::runtime_error("capture MODEL PROMPTS.txt OUTPUT_DIRECTORY");
    const fs::path dir=argv[3];fs::create_directories(dir);
    Engine e;e.load(argv[1],8,1,256);
    Tokenizer tokenizer;tokenizer.load(argv[1]);
    std::ifstream prompts(argv[2]);if(!prompts)throw std::runtime_error("prompts unreadable");
    std::string prompt;int case_index=0;
    while(std::getline(prompts,prompt)) {
        if(prompt.empty()||prompt[0]=='#')continue;
        auto tokens=tokenizer.encode(Tokenizer::chat_prompt(prompt,false),true);
        if(tokens.empty()||tokens.size()>128)throw std::runtime_error("prompt length outside 1..128");
        e.reset();
        for(size_t i=0;i+1<tokens.size();i++)e.step(tokens[i],false);
        int winner=e.step(tokens.back(),true);
        const fs::path base=dir/("case"+std::to_string(case_index));
        fs::create_directories(base);
        capture(base/"query.i8",e.xq,D);
        capture(base/"scales.f32",e.xs,NB_D);
        capture(base/"sums.i32",e.xsum,NB_D);
        capture(base/"logits.f32",e.logits,VOCAB);
        std::ofstream meta(base/"input.txt");
        meta<<"prompt="<<prompt<<"\ntokens=";
        for(size_t i=0;i<tokens.size();i++)meta<<(i?",":"")<<tokens[i];
        meta<<"\nargmax="<<winner<<"\n";
        std::cout<<"case "<<case_index<<" tokens "<<tokens.size()<<" argmax "<<winner<<"\n";
        case_index++;
    }
    if(case_index<2)throw std::runtime_error("need at least two distinct prompts");
 } catch(const std::exception& e) {std::cerr<<"capture: "<<e.what()<<"\n";return 1;}
}
