#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <limits>
#include <map>
#include <numeric>
#include <set>
#include <string>
#include <tuple>
#include <vector>
#include "ising.hpp"
using namespace std;
using Clock=chrono::steady_clock;
using Score=int64_t;
constexpr Score INF=numeric_limits<Score>::max()/8;
struct Factor {vector<int> vars; vector<Score> value;};
struct Choice {int variable;vector<int> rest,arg;};
struct Count {uint64_t entries=0,lookups=0,assignments=0,pruned=0,cuts=0,sign_solves=0,balanced=0;size_t peak_entries=0;int width=0,conditioned=0;};
struct Result {Score loss;array<int,8> q{};};
struct Structure {int square,k,a,b;};
struct Teacher {string name;array<int,8> f;};
struct Point {int bytes,work;Score loss;string witness;array<int,8> q{};};
vector<Point> frontier;
int step(int s,int op){if(op==0)return s;if(op==1)return(s+1)&7;if(op==2)return s^1;return((s<<1)|(s>>2))&7;}
int encode(int x,Structure s){return ((s.square?x*x:x)&7)^s.k;}
int power(int k,int n){int x=1;while(n--)x*=k;return x;}
int value(int bits,int code){return bits==1?(code?1:-1):code-2;}
int imagebytes(int bits){return(3+1+2+2+2+8*bits+7)/8;}
int work(Structure s){return 10+s.square+(s.k!=0)+(s.a!=0)+(s.b!=0);}
void insert(Point p){for(auto&q:frontier)if(q.bytes<=p.bytes&&q.work<=p.work&&q.loss<=p.loss)return;erase_if(frontier,[&](Point q){return p.bytes<=q.bytes&&p.work<=q.work&&p.loss<=q.loss;});frontier.push_back(move(p));}
Score budget(int b,int w){Score x=INF;for(auto&p:frontier)if(p.bytes<=b&&p.work<=w)x=min(x,p.loss);return x;}
vector<int> united(const vector<Factor>&fs){set<int>s;for(auto&f:fs)for(int x:f.vars)s.insert(x);return vector<int>(s.begin(),s.end());}
Score get(const Factor&f,const array<int,8>&q,int k,Count&count){int at=0,mul=1;for(int v:f.vars){at+=q[v]*mul;mul*=k;}count.lookups++;return f.value[at];}
void assignment(int id,const vector<int>&vars,int k,array<int,8>&q){for(int v:vars){q[v]=id%k;id/=k;}}
vector<Factor> factors(const Teacher&t,Structure s,int bits){
  int k=1<<bits;vector<Factor> fs;
  for(int j=0;j<8;j++)fs.push_back({{j},vector<Score>(k)});
  map<pair<int,int>,int> edges;
  auto unary=[&](int label,int y){for(int c=0;c<k;c++){Score d=4*value(bits,c)-y;fs[label].value[c]+=16*d*d;}};
  auto pairterm=[&](int i,int j,int target){
    if(i==j){for(int c=0;c<k;c++){Score q=value(bits,c),d=16*q*q-target;fs[i].value[c]+=d*d;}return;}
    if(i>j)swap(i,j);auto edge=make_pair(i,j);int at;
    if(!edges.contains(edge)){at=fs.size();edges[edge]=at;fs.push_back({{i,j},vector<Score>(k*k)});}else at=edges[edge];
    for(int b=0;b<k;b++)for(int a=0;a<k;a++){Score d=16*value(bits,a)*value(bits,b)-target;fs[at].value[a+k*b]+=d*d;}
  };
  for(int x=0;x<8;x++){
    int h=encode(x,s),i=step(h,s.a),j=step(h,s.b);
    int y=t.f[x],a=t.f[step(x,1)],b=t.f[step(x,3)];
    unary(h,y);unary(i,a);unary(j,b);pairterm(h,i,y*a);pairterm(i,j,a*b);
  }
  return fs;
}
vector<int> order(vector<Factor>fs){
  set<int>live;for(auto&f:fs)for(int v:f.vars)live.insert(v);
  vector<int> out;
  while(!live.empty()){
    tuple<int,int,int> best{100,100,100};int chosen=-1;
    for(int v:live){set<int>ns;set<pair<int,int>>edges;
      for(auto&f:fs){for(int a:f.vars)for(int b:f.vars)if(a<b)edges.insert({a,b});if(find(f.vars.begin(),f.vars.end(),v)!=f.vars.end())for(int a:f.vars)if(a!=v)ns.insert(a);}
      int fill=0;for(int a:ns)for(int b:ns)if(a<b&&!edges.contains({a,b}))fill++;
      auto key=make_tuple(fill,(int)ns.size(),v);if(key<best){best=key;chosen=v;}
    }
    vector<Factor>bucket;vector<Factor>rest;for(auto&f:fs)(find(f.vars.begin(),f.vars.end(),chosen)!=f.vars.end()?bucket:rest).push_back(f);
    auto vars=united(bucket);erase(vars,chosen);if(!vars.empty())rest.push_back({vars,{}});fs=move(rest);live.erase(chosen);out.push_back(chosen);
  }return out;
}
Factor eliminate_bucket(vector<Factor>bucket,int v,int k,Count&count,Choice*choice){
  auto scope=united(bucket);count.width=max(count.width,(int)scope.size()-1);erase(scope,v);
  Factor out{scope,vector<Score>(power(k,scope.size()),INF)};
  if(choice){choice->variable=v;choice->rest=scope;choice->arg.resize(out.value.size());}
  array<int,8>q{};
  for(int id=0;id<(int)out.value.size();id++){
    assignment(id,scope,k,q);
    for(int c=0;c<k;c++){
      q[v]=c;Score loss=0;for(auto&f:bucket)loss+=get(f,q,k,count);count.entries++;
      if(loss<out.value[id]){out.value[id]=loss;if(choice)choice->arg[id]=c;}
    }
  }return out;
}
Result solve(vector<Factor>fs,int k,Count&count,int limit=0){
  auto permutation=order(fs);vector<Choice>choices;Score constant=0;
  for(int v:permutation){
    size_t memory=0;for(auto&f:fs)memory+=f.value.size();count.peak_entries=max(count.peak_entries,memory);
    vector<Factor>bucket,rest;for(auto&f:fs)(find(f.vars.begin(),f.vars.end(),v)!=f.vars.end()?bucket:rest).push_back(move(f));
    vector<vector<Factor>>parts;
    if(!limit)parts.push_back(move(bucket));else{
      sort(bucket.begin(),bucket.end(),[](auto&a,auto&b){return a.vars.size()>b.vars.size();});
      for(auto&f:bucket){bool placed=false;for(auto&part:parts){auto trial=part;trial.push_back(f);if((int)united(trial).size()<=limit){part.push_back(move(f));placed=true;break;}}if(!placed)parts.push_back({move(f)});}
    }
    for(auto&part:parts){Choice choice;auto message=eliminate_bucket(move(part),v,k,count,limit?nullptr:&choice);if(!limit)choices.push_back(move(choice));if(message.vars.empty())constant+=message.value[0];else rest.push_back(move(message));}
    fs=move(rest);
  }
  Result out{constant,{}};
  if(!limit)for(auto it=choices.rbegin();it!=choices.rend();it++){int id=0,m=1;for(int v:it->rest){id+=out.q[v]*m;m*=k;}out.q[it->variable]=it->arg[id];}
  return out;
}
Result ising(const vector<Factor>&fs,Count&count){
  vector<array<int64_t,2>> unary(8);vector<coupled_ising::Edge>edges;
  for(auto&f:fs){
    if(f.vars.size()==1){for(int c=0;c<2;c++)unary[f.vars[0]][c]+=f.value[c];}
    else if(f.vars.size()==2 && f.value[0]==f.value[3] && f.value[1]==f.value[2])edges.push_back({f.vars[0],f.vars[1],f.value[0],f.value[1]});
    else{cerr<<"invalid Ising factor";exit(7);}
  }
  auto r=coupled_ising::solve(unary,edges);
  if(r.status!=coupled_ising::Status::exact){cerr<<"Ising solver did not complete";exit(8);}
  count.cuts+=r.cuts;count.sign_solves++;count.balanced+=r.conditioned_vertices==0;count.conditioned=max(count.conditioned,r.conditioned_vertices);
  Result out{r.loss,{}};copy(r.bits.begin(),r.bits.end(),out.q.begin());return out;
}
Score evaluate(const vector<Factor>&fs,const array<int,8>&q,int k,Count&count){Score loss=0;for(auto&f:fs)loss+=get(f,q,k,count);return loss;}
Score endpoint(const Teacher&t,const array<int,8>&codes,Structure s,int bits);
Result brute(const Teacher&t,Structure s,int bits,Count&count){
  int k=1<<bits;Result best{INF,{}};array<int,8>q{};vector<int>vars{0,1,2,3,4,5,6,7};
  for(int id=0;id<power(k,8);id++){assignment(id,vars,k,q);Score loss=endpoint(t,q,s,bits);count.assignments++;if(loss<best.loss)best={loss,q};}return best;
}
Score endpoint(const Teacher&t,const array<int,8>&codes,Structure s,int bits){
  Score loss=0;
  for(int x=0;x<8;x++){
    int z=encode(x,s),i=step(z,s.a),j=step(z,s.b),u=value(bits,codes[z]),v=value(bits,codes[i]),w=value(bits,codes[j]);
    int y=t.f[x],a=t.f[step(x,1)],b=t.f[step(x,3)];
    for(Score d:{4*u-y,4*v-a,4*w-b})loss+=16*d*d;
    for(Score d:{16*u*v-y*a,16*v*w-a*b})loss+=d*d;
  }return loss;
}
Score full_precision_endpoint(const Teacher&t,const array<int,8>&f){Score loss=0;for(int x=0;x<8;x++){int a=step(x,1),b=step(x,3);for(int j:{x,a,b}){Score d=f[j]-t.f[j];loss+=16*d*d;}Score d=f[x]*f[a]-t.f[x]*t.f[a];loss+=d*d;d=f[a]*f[b]-t.f[a]*t.f[b];loss+=d*d;}return loss;}
void controls(const Teacher&t){
  for(int q=-8;q<8;q++){array<int,8>f;f.fill(q);insert({1,6,full_precision_endpoint(t,f),"constant:"+to_string(q+8),f});}
  for(int a=-8;a<8;a++)for(int b=-8;b<8;b++){array<int,8>f;for(int x=0;x<8;x++)f[x]=a+b*x;insert({2,12,full_precision_endpoint(t,f),"scalar:"+to_string(a+8)+":"+to_string(b+8),f});}
  insert({5,12,0,"direct:4",t.f});
  for(int bits:{1,2}){Count c;auto r=solve(factors(t,{0,0,1,3},bits),1<<bits,c);insert({(3+8*bits+7)/8,12,r.loss,"direct:"+to_string(bits),r.q});}
}
string name(Structure s,int bits){return "machine:"+to_string(s.square)+":"+to_string(s.k)+":"+to_string(s.a)+":"+to_string(s.b)+":"+to_string(bits);}
Count search(const Teacher&t,int arm,ostream&details,bool diagnostics=false){
  frontier.clear();controls(t);Count count;int failed_independent=0;Score largest_gap=0;bool first=true;
  if(diagnostics)for(int bits:{1,2}){Count c;auto exact=brute(t,{0,0,1,3},bits,c);auto fitted=solve(factors(t,{0,0,1,3},bits),1<<bits,c);if(exact.loss!=fitted.loss){cerr<<"direct control optimum mismatch";exit(10);}}
  for(int e=0;e<2;e++)for(int k=0;k<4;k++)for(int a=0;a<4;a++)for(int b=0;b<4;b++)for(int bits:{1,2}){
    Structure s{e,k,a,b};auto fs=factors(t,s,bits);int alphabet=1<<bits;
    if(arm==2 || arm==3 || arm==5){Score floor=0;
      if(arm==2 || arm==5)for(auto&f:fs)floor+=*min_element(f.value.begin(),f.value.end());
      else floor=solve(fs,alphabet,count,2).loss;
      if(floor>budget(imagebytes(bits),work(s))){count.pruned++;continue;}
    }
    Result r=arm==0?brute(t,s,bits,count):(arm>=4 && bits==1?ising(fs,count):solve(fs,alphabet,count));
    if(endpoint(t,r.q,s,bits)!=r.loss){cerr<<"endpoint discrepancy";exit(4);}
    insert({imagebytes(bits),work(s),r.loss,name(s,bits),r.q});
    if(diagnostics){
      array<int,8>q{};for(int j=0;j<8;j++)q[j]=min_element(fs[j].value.begin(),fs[j].value.end())-fs[j].value.begin();
      Count c;Score independent=evaluate(fs,q,alphabet,c);if(independent>r.loss)failed_independent++;
      largest_gap=max(largest_gap,independent-r.loss);
      Count lc,ec,ic;Score lower=solve(fs,alphabet,lc,2).loss;if(lower>r.loss){cerr<<"invalid relaxed floor";exit(5);}
      auto exact=solve(fs,alphabet,ec);if(exact.loss!=r.loss)exit(6);
      if(bits==1 && ising(fs,ic).loss!=r.loss){cerr<<"Ising mismatch";exit(9);}
      if(!first)details<<",";first=false;
      details<<"{\"structure\":\""<<name(s,bits)<<"\",\"exact\":"<<r.loss<<",\"split_floor\":"<<lower<<",\"independent\":"<<independent<<",\"width\":"<<ec.width<<",\"gauge_conditioned\":"<<ic.conditioned<<",\"gauge_cuts\":"<<ic.cuts<<"}";
    }
  }
  if(diagnostics)cerr<<t.name<<" independent failures="<<failed_independent<<" max gap="<<largest_gap<<"\n";
  sort(frontier.begin(),frontier.end(),[](auto&a,auto&b){return tie(a.bytes,a.work,a.loss)<tie(b.bytes,b.work,b.loss);});return count;
}
void dumpfront(ostream&o){o<<"[";bool first=true;for(auto&p:frontier){if(!first)o<<",";first=false;o<<"{\"bytes\":"<<p.bytes<<",\"work\":"<<p.work<<",\"loss\":"<<p.loss<<",\"witness\":\""<<p.witness<<"\",\"values\":[";for(int j=0;j<8;j++){if(j)o<<",";o<<p.q[j];}o<<"]}";}o<<"]";}
vector<tuple<int,int,Score>>signature(){vector<tuple<int,int,Score>>s;for(auto&p:frontier)s.emplace_back(p.bytes,p.work,p.loss);return s;}
int main(int argc,char**argv){
  auto beginning=Clock::now();int single=argc>3?stoi(argv[3]):-1;
  vector<Teacher>teachers{{"nonlinear-a",{-7,-5,-2,2,5,6,3,-2}},{"nonlinear-b",{-5,-1,3,6,4,0,-2,-1}},{"linear",{-4,-3,-2,-1,0,1,2,3}},{"unstructured",{7,-5,1,-8,4,3,-1,6}}};
  ofstream out(argc>1?argv[1]:"results.json"),detail(argc>2?argv[2]:"structures.json");out<<"{\"teachers\":[";detail<<"[";bool first=true;
  for(auto&t:teachers){if(!first){out<<",";detail<<",";}first=false;out<<"{\"name\":\""<<t.name<<"\",\"target\":[";for(int j=0;j<8;j++){if(j)out<<",";out<<t.f[j];}out<<"],\"arms\":[";detail<<"{\"name\":\""<<t.name<<"\",\"structures\":[";
    vector<tuple<int,int,Score>>oracle;
    for(int arm=single<0?0:single;arm<(single<0?6:single+1);arm++){auto start=Clock::now();auto count=search(t,arm,detail);double ms=chrono::duration<double,milli>(Clock::now()-start).count();auto sig=signature();if(arm==0)oracle=sig;else if(single<0 && sig!=oracle){cerr<<"frontier mismatch";return 2;}if(single<0 && arm)out<<",";out<<"{\"arm\":"<<arm<<",\"ms\":"<<ms<<",\"assignments\":"<<count.assignments<<",\"factor_entries\":"<<count.entries<<",\"lookups\":"<<count.lookups<<",\"pruned\":"<<count.pruned<<",\"induced_width\":"<<count.width<<",\"peak_factor_entries\":"<<count.peak_entries<<",\"sign_solves\":"<<count.sign_solves<<",\"balanced\":"<<count.balanced<<",\"conditioned\":"<<count.conditioned<<",\"cuts\":"<<count.cuts<<",\"frontier\":";dumpfront(out);out<<"}";}
    if(single<0)search(t,1,detail,true);
    out<<"]}";detail<<"]}";
  }
  long peak=0;string line;ifstream status("/proc/self/status");while(getline(status,line))if(line.starts_with("VmHWM:"))peak=stol(line.substr(6));
  out<<"],\"peak_rss_kib\":"<<peak<<",\"elapsed_ms\":"<<chrono::duration<double,milli>(Clock::now()-beginning).count()<<"}\n";detail<<"]\n";
}
