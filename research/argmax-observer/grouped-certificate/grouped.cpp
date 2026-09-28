// Reuse the checked HALO decoder and capture reader from the actual-head replay.
#define main final_head_replay_entry
#include "../final-head/replay.cpp"
#undef main
#include <iomanip>
#include <numeric>

constexpr std::array<int,9> scan_cuts={20,24,26,28,30,32,34,36,39};
constexpr std::array<int,4> group_sizes={128,32,16,8};

// Rearrangement: among disjoint positive and negative trit positions, the
// maximum dot puts positives on the largest query values and negatives on
// the smallest. Both counts are stored, but no weight position is exposed.
struct SortedQuery {std::array<int,129> sums{};};
int group_cap(const int8_t* w,const SortedQuery& query,int size){
    int pos=0,neg=0;
    for(int j=0;j<size;j++){
        pos+=w[j]==1;neg+=w[j]==-1;
    }
    return query.sums[size]-query.sums[size-pos]-query.sums[neg];
}

uint64_t completed_lines(const std::vector<uint8_t>& finish,int tail,int line_bytes){
    uint64_t lines=0;
    for(int tile=0;tile<N/TILE;tile++){
        std::array<bool,STEP/32> touched{};
        for(int row=0;row<TILE;row++)if(finish[tile*TILE+row]){
            touched[row*16/line_bytes]=true;
            touched[(512+row*8)/line_bytes]=true;
            touched[(768+row*4)/line_bytes]=true;
        }
        for(bool used:touched)lines+=used;
    }
    return lines*tail*line_bytes;
}

int main(int argc,char** argv){
 try{
    if(argc!=4)throw std::runtime_error("grouped CACHE CASE_DIRECTORY OUT.json");
    Cache cache(argv[1]);
    std::string dir=argv[2];
    auto q=read<int8_t>(dir+"/query.i8",K);
    auto xs=read<float>(dir+"/scales.f32",B);
    auto sums=read<int32_t>(dir+"/sums.i32",B);
    auto logits=read<float>(dir+"/logits.f32",N);
    for(int b=0;b<B;b++){
        int sum=0;for(int j=0;j<128;j++)sum+=q[128*b+j];
        if(sum!=sums[b]||!std::isfinite(xs[b])||xs[b]<=0)throw std::runtime_error("invalid capture");
    }
    int winner=0,candidate=0;
    for(int i=0;i<N;i++){
        if(!std::isfinite(logits[i]))throw std::runtime_error("nonfinite logit");
        if(logits[i]>logits[winner])winner=i;
        if(i<4096&&logits[i]>logits[candidate])candidate=i;
    }
    constexpr int C=scan_cuts.size(), G=group_sizes.size();
    std::array<std::array<std::vector<SortedQuery>,B>,G> queries;
    std::array<int,B> query_abs{};
    for(int b=0;b<B;b++){
        for(int j=0;j<128;j++)query_abs[b]+=std::abs(int(q[128*b+j]));
        for(int g=0;g<G;g++){
            int width=group_sizes[g];
            for(int off=0;off<128;off+=width){
                std::array<int,128> values{};
                for(int j=0;j<width;j++)values[j]=q[128*b+off+j];
                std::sort(values.begin(),values.begin()+width);
                SortedQuery v;
                for(int j=0;j<width;j++)v.sums[j+1]=v.sums[j]+values[j];
                queries[g][b].push_back(v);
            }
        }
    }
    std::array<std::array<std::vector<uint8_t>,C>,G> keep;
    std::array<std::array<int,C>,G> survivors{}, failures{}, best{};
    for(int g=0;g<G;g++)for(int c=0;c<C;c++){
        keep[g][c].resize(N);best[g][c]=candidate;
    }
    int replay_differences=0;
    for(int tile=0;tile<N/TILE;tile++)for(int row=0;row<TILE;row++){
        int idx=tile*TILE+row;
        std::array<float,8> chain{};
        std::array<long double,B+1> prefix{},mass{},absolute_cap_suffix{};
        std::array<std::array<long double,B+1>,G> suffix{};
        for(int b=0;b<B;b++){
            int8_t w[128];float scale;int nz;
            decode(cache.bytes+cache.offset+(tile*B+b)*STEP,row,w,scale,nz);
            if(!std::isfinite(scale)||scale<0)throw std::runtime_error("invalid weight scale");
            int dot=0;for(int j=0;j<128;j++)dot+=int(w[j])*int(q[b*128+j]);
            chain[b/5]=std::fma(float(dot),scale*xs[b],chain[b/5]);
            long double term=(long double)dot*scale*xs[b];
            prefix[b+1]=prefix[b]+term;mass[b+1]=mass[b]+std::abs(term);
            absolute_cap_suffix[b]=(long double)query_abs[b]*scale*xs[b];
            for(int g=0;g<G;g++){
                int width=group_sizes[g],bound=0;
                for(int j=0;j<128;j+=width)bound+=group_cap(w+j,queries[g][b][j/width],width);
                suffix[g][b]=(long double)bound*scale*xs[b];
            }
        }
        float calculated=chain[0];for(int k=1;k<8;k++)calculated+=chain[k];
        replay_differences+=std::bit_cast<uint32_t>(calculated)!=std::bit_cast<uint32_t>(logits[idx]);
        absolute_cap_suffix[B]=0;
        for(int b=B-1;b>=0;b--)absolute_cap_suffix[b]+=absolute_cap_suffix[b+1];
        for(int g=0;g<G;g++){
            suffix[g][B]=0;
            for(int b=B-1;b>=0;b--)suffix[g][b]+=suffix[g][b+1];
            for(int c=0;c<C;c++){
                int cut=scan_cuts[c];
                // For rounding, an upper bound on the absolute omitted terms
                // is needed even if the signed rearrangement cap is negative.
                // Use the original per-block L1 cap here; this is intentionally
                // looser than the score bound but available from the same counts.
                // Avoid metadata for that cap by using query-only sum(abs(q)):
                // any ternary block has |dot| <= sum(abs(q)).
                long double total_mass=mass[cut]+absolute_cap_suffix[cut];
                if(total_mass>1000000)throw std::runtime_error("guard domain exceeded");
                long double upper=prefix[cut]+suffix[g][cut]+0.0001L*total_mass+1e-12L;
                failures[g][c]+=upper<(long double)logits[idx];
                bool selected=idx==candidate||(idx<candidate?upper>=(long double)logits[candidate]:upper>(long double)logits[candidate]);
                survivors[g][c]+=selected;
                keep[g][c][idx]=selected||idx<4096;
                if(selected&&(logits[idx]>logits[best[g][c]]||(logits[idx]==logits[best[g][c]]&&idx<best[g][c])))best[g][c]=idx;
            }
        }
    }
    if(replay_differences)throw std::runtime_error("not bit-identical to captured GPU logits");
    std::ofstream out(argv[3]);
    out<<"{\"winner\":"<<winner<<",\"candidate\":"<<candidate<<",\"replay_differences\":"<<replay_differences<<",\"results\":[\n";
    bool first=true;
    for(int g=0;g<G;g++)for(int c=0;c<C;c++){
        if(failures[g][c]||best[g][c]!=winner)throw std::runtime_error("invalid certificate");
        int cut=scan_cuts[c],width=group_sizes[g], bits=0;
        while((1<<bits)<=width)bits++;
        // 2 sign counts per group, each in ceil(log2(width+1)) bits.
        int metadata=(2*(128/width)*bits+7)/8+2;
        uint64_t base=uint64_t(N)*cut*28+uint64_t(N)*(B-cut)*metadata;
        uint64_t lines=completed_lines(keep[g][c],B-cut,64);
        if(!first)out<<",\n";first=false;
        out<<"{\"group\":"<<width<<",\"cut\":"<<cut<<",\"survivors\":"<<survivors[g][c]
           <<",\"metadata_bytes_per_block\":"<<metadata<<",\"prefix_and_metadata_bytes\":"<<base
           <<",\"completion_64b_bytes\":"<<lines<<",\"total_64b_bytes\":"<<base+lines
           <<",\"saving_64b_percent\":"<<std::setprecision(6)<<100.0*(1.0-double(base+lines)/278118400.0)
           <<",\"upper_failures\":"<<failures[g][c]<<",\"winner_from_survivors\":"<<best[g][c]<<"}";
    }
    out<<"\n]}\n";
    std::cout<<"winner "<<winner<<" candidate "<<candidate<<" replay differences "<<replay_differences<<"\n";
 }catch(const std::exception& e){std::cerr<<"grouped: "<<e.what()<<"\n";return 1;}
}
