#include <algorithm>
#include <array>
#include <bit>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <map>
#include <numeric>
#include <string>
#include <tuple>
#include <vector>
#include <sys/resource.h>
using namespace std;
using Clock = chrono::steady_clock;
using Table = array<int,32>;
constexpr long long DEN = 144403552893600LL; // lcm(1,...,32)
int lane(int s,int p) { return (s>>(2*p))&3; }
int swaplanes(int s) { return (s>>2)|((s&3)<<2); }
int op(int s,int a,int k) {
  if(a==6) return s;
  int p=a&1, u=lane(s,p), v=lane(s,1-p), r;
  if(a/2==0) r=(u+1+k)&3;
  else if(a/2==1) r=(u+v)&3;
  else r=u^v;
  return (s&~(3<<(2*p)))|(r<<(2*p));
}
struct Prefix { array<int,16> state; int id,k,n,e0,e1; vector<int> word; };
struct Node { array<int,16> edge; int witness=-1; Node(){edge.fill(-1);} };
struct Group { int k,n; vector<Prefix> prefixes; vector<Node> trie; };
struct Point { int bytes,work,loss; string witness; };
struct Metrics { uint64_t scored=0,bounds=0,pruned=0,visits=0; };
vector<Point> frontier;
int incumbent(int b,int w) {
  int out=1000000000;
  for(auto &p:frontier) if(p.bytes<=b && p.work<=w) out=min(out,p.loss);
  return out;
}
void insertpoint(Point p) {
  for(auto &q:frontier) if(q.bytes<=p.bytes && q.work<=p.work && q.loss<=p.loss) return;
  erase_if(frontier,[&](Point q){return p.bytes<=q.bytes && p.work<=q.work && p.loss<=q.loss;});
  frontier.push_back(p);
}
vector<array<int,4>> codes(int bits) {
  int n=1<<bits, count=1<<(bits*4); vector<array<int,4>> out;
  for(int i=0;i<count;i++) { array<int,4> q; int t=i;
    for(auto &v:q) { int u=t&(n-1); t>>=bits; v=bits==1?(u?4:-4):4*(u-2); }
    out.push_back(q);
  }
  return out;
}
vector<Group> groups(bool indexed) {
  vector<Group> gs; int id=0;
  for(int k=0;k<2;k++) for(int n=0;n<=2;n++) {
    Group g; g.k=k;g.n=n;
    int nw=1; for(int j=0;j<n;j++) nw*=6;
    for(int e0=0;e0<3;e0++) for(int e1=0;e1<3;e1++) for(int wi=0;wi<nw;wi++) {
      Prefix p; p.id=id++;p.k=k;p.n=n;p.e0=e0;p.e1=e1;
      int ww=wi;for(int j=0;j<n;j++){p.word.push_back(ww%6);ww/=6;}
      for(int x=0;x<16;x++) {
        int f[3]={0,x&3,x>>2};
        int s=((f[e0]+k)&3)|(((f[e1]+k)&3)<<2);
        for(int a:p.word)s=op(s,a,k); p.state[x]=s;
      }
      g.prefixes.push_back(p);
    }
    if(indexed) g.trie.emplace_back();
    for(int i=0;indexed && i<(int)g.prefixes.size();i++) {
      int at=0; for(int s:g.prefixes[i].state) {
        int next=g.trie[at].edge[s];
        if(next<0){next=g.trie.size();g.trie[at].edge[s]=next;g.trie.emplace_back();}
        at=next;
      }
      if(g.trie[at].witness<0)g.trie[at].witness=i;
    }
    gs.push_back(move(g));
  }
  return gs;
}
int bytes(int n,int bits) { return (3+4+1+2+3*n+3+1+4*bits+7)/8; }
int work(int n,int cont) { return 6+n+(cont!=6); }
string witness(const Prefix &p,int cont,int port,int bits,int qi) {
  return "machine:"+to_string(p.id)+":"+to_string(cont)+":"+to_string(port)+":"+to_string(bits)+":"+to_string(qi);
}
array<int,32> labels(const Prefix&p,int cont,int port) {
  array<int,32> l;
  for(int x=0;x<16;x++){l[2*x]=lane(p.state[x],port);l[2*x+1]=lane(op(p.state[x],cont,p.k),port);}return l;
}
struct Sums {
  array<int,4> count{},sum{}; int sq=0;
  void add(int label,int target){count[label]++;sum[label]+=target;sq+=target*target;}
  int projection() const {
    __int128 num=(__int128)sq*DEN;
    for(int j=0;j<4;j++)if(count[j])num-=(__int128)sum[j]*sum[j]*(DEN/count[j]);
    return (int)((num+DEN-1)/DEN);
  }
  pair<int,array<int,4>> optimum(int bits) const {
    int loss=sq;array<int,4> q;
    for(int j=0;j<4;j++) {
      int best=1000000000,value=0;
      for(int c=0;c<(1<<bits);c++) {
        int v=bits==1?(c?4:-4):4*(c-2);
        int z=count[j]*v*v-2*sum[j]*v;
        if(z<best){best=z;value=v;}
      }
      loss+=best;q[j]=value;
    }
    return {loss,q};
  }
};
void controls(const Table&t) {
  for(int q=-8;q<8;q++) {
    int loss=0;for(int y:t)loss+=(q-y)*(q-y);
    insertpoint({1,2,loss,"constant:"+to_string(q+8)});
  }
  for(int bits:{2,4}) {
    int m=1<<bits, best=1000000000,bid=0;
    for(int id=0;id<m*m*m;id++) {
      int z=id;array<int,3>q;
      for(auto&v:q){v=(z%m-m/2)*(bits==2?4:1);z/=m;}
      int loss=0;
      for(int x=0;x<16;x++) {int u=x&3,v=x>>2;
        int a=q[0]+q[1]*u+q[2]*v, b=q[0]+q[1]*((u+v)&3)+q[2]*u;
        loss+=(a-t[2*x])*(a-t[2*x])+(b-t[2*x+1])*(b-t[2*x+1]);
      }
      if(loss<best){best=loss;bid=id;}
    }
    insertpoint({(3+3*bits+7)/8,7,best,"scalar:"+to_string(bits)+":"+to_string(bid)});
  }
  for(int bits:{1,2,4}) {
    int loss=0;
    for(int x=0;x<16;x++) {
      int best=1000000000;
      for(int c=0;c<(1<<bits);c++) {
        int q=bits==1?(c?4:-4):bits==2?4*(c-2):c-8, z=0;
        for(int i=0;i<16;i++)for(int j=0;j<2;j++) {
          int u=i&3,v=i>>2, at=j?((u+v)&3)|(u<<2):i;
          if(at==x)z+=(q-t[2*i+j])*(q-t[2*i+j]);
        }
        best=min(best,z);
      }
      loss+=best;
    }
    insertpoint({(3+16*bits+7)/8,7,loss,"table:"+to_string(bits)});
  }
}
void walk(const Group&g,int at,int depth,int cont,int port,const array<int,4>&q,
          int qi,int bits,const Table&t,int loss,Metrics&m) {
  m.visits++;
  int b=bytes(g.n,bits),w=work(g.n,cont);
  if(loss>incumbent(b,w)){m.pruned++;return;}
  if(depth==16) {
    m.scored++;auto&p=g.prefixes[g.trie[at].witness];
    insertpoint({b,w,loss,witness(p,cont,port,bits,qi)});return;
  }
  for(int s=0;s<16;s++)if(g.trie[at].edge[s]>=0) {
    int a=q[lane(s,port)]-t[2*depth],bb=q[lane(op(s,cont,g.k),port)]-t[2*depth+1];
    walk(g,g.trie[at].edge[s],depth+1,cont,port,q,qi,bits,t,loss+a*a+bb*bb,m);
  }
}
void prebound(const Group&g,int at,int depth,int cont,int port,int bits,const Table&t,
              Sums sums,vector<char>&alive,Metrics&m) {
  m.bounds++;
  if(sums.projection()>incumbent(bytes(g.n,bits),work(g.n,cont))){m.pruned++;return;}
  alive[at]=1;
  if(depth==16)return;
  for(int s=0;s<16;s++)if(g.trie[at].edge[s]>=0) {
    auto next=sums;next.add(lane(s,port),t[2*depth]);next.add(lane(op(s,cont,g.k),port),t[2*depth+1]);
    prebound(g,g.trie[at].edge[s],depth+1,cont,port,bits,t,next,alive,m);
  }
}
void walkbounded(const Group&g,int at,int depth,int cont,int port,const array<int,4>&q,
          int qi,int bits,const Table&t,int loss,const vector<char>&alive,Metrics&m) {
  m.visits++;
  if(!alive[at] || loss>incumbent(bytes(g.n,bits),work(g.n,cont))){m.pruned++;return;}
  if(depth==16){m.scored++;auto&p=g.prefixes[g.trie[at].witness];
    insertpoint({bytes(g.n,bits),work(g.n,cont),loss,witness(p,cont,port,bits,qi)});return;}
  for(int s=0;s<16;s++)if(g.trie[at].edge[s]>=0) {
    int a=q[lane(s,port)]-t[2*depth],b=q[lane(op(s,cont,g.k),port)]-t[2*depth+1];
    walkbounded(g,g.trie[at].edge[s],depth+1,cont,port,q,qi,bits,t,loss+a*a+b*b,alive,m);
  }
}
Metrics search(const vector<Group>&gs,const Table&t,int flags,bool eliminate=false) {
  Metrics m;bool projection=flags&1,indexed=flags&2,symmetry=flags&4;
  frontier.clear();controls(t);
  for(auto&g:gs)for(int cont=0;cont<7;cont++)for(int port=0;port<(symmetry?1:2);port++)for(int bits:{1,2}) {
    auto qs=codes(bits);
    if(indexed && !eliminate) {
      if(projection) {
        vector<char>alive(g.trie.size());prebound(g,0,0,cont,port,bits,t,{},alive,m);
        for(int i=0;i<(int)qs.size();i++)walkbounded(g,0,0,cont,port,qs[i],i,bits,t,0,alive,m);
      } else for(int i=0;i<(int)qs.size();i++)walk(g,0,0,cont,port,qs[i],i,bits,t,0,m);
    } else for(auto&p:g.prefixes) {
      auto l=labels(p,cont,port);Sums sums;
      if(projection||eliminate) {
        for(int j=0;j<32;j++)sums.add(l[j],t[j]);m.bounds++;
        if(sums.projection()>incumbent(bytes(g.n,bits),work(g.n,cont))){m.pruned++;continue;}
      }
      if(eliminate) {
        auto [loss,q]=sums.optimum(bits); int qi=0;
        for(int j=3;j>=0;j--)qi=(qi<<bits)+(bits==1?(q[j]==4):q[j]/4+2);
        m.scored++;insertpoint({bytes(g.n,bits),work(g.n,cont),loss,witness(p,cont,port,bits,qi)});
      } else for(int i=0;i<(int)qs.size();i++) {
        int loss=0;for(int j=0;j<32;j++){int d=qs[i][l[j]]-t[j];loss+=d*d;}
        m.scored++;insertpoint({bytes(g.n,bits),work(g.n,cont),loss,witness(p,cont,port,bits,i)});
      }
    }
  }
  sort(frontier.begin(),frontier.end(),[](Point a,Point b){return tie(a.bytes,a.work,a.loss)<tie(b.bytes,b.work,b.loss);});
  return m;
}
vector<tuple<int,int,int>> signature(){vector<tuple<int,int,int>>out;for(auto&p:frontier)out.push_back({p.bytes,p.work,p.loss});return out;}
uint32_t seed=73129;
int rnd(){seed^=seed<<13;seed^=seed>>17;seed^=seed<<5;return seed%5-2;}
vector<pair<string,Table>> teachers() {
  vector<pair<string,Table>> ts;
  for(int r=0;r<12;r++) {
    array<int,16> f; array<int,8>a;for(auto&v:a)v=rnd();
    for(int x=0;x<16;x++) {
      double u=(x&3)-1.5,v=(x>>2)-1.5;
      double z=a[0]+a[1]*u+a[2]*v+a[3]*u*v+a[4]*u*u+a[5]*v*v+a[6]*u*u*v+a[7]*u*v*v;
      if(r<8)f[x]=clamp((int)lround(7*tanh(z/8)),-8,7);
      else if(r<10)f[x]=clamp((int)lround(a[0]+a[1]*u+a[2]*v),-8,7);
      else f[x]=clamp(rnd()*3+rnd(),-8,7);
    }
    Table t;for(int x=0;x<16;x++){int u=x&3,v=x>>2;t[2*x]=f[x];t[2*x+1]=f[((u+v)&3)|(u<<2)];}
    ts.push_back({r<8?"nonlinear-"+to_string(r):r<10?"linear-"+to_string(r-8):"unstructured-"+to_string(r-10),t});
  }return ts;
}
void outputfrontier(ostream&o){o<<"[";bool first=true;for(auto&p:frontier){if(!first)o<<",";first=false;o<<"{\"bytes\":"<<p.bytes<<",\"work\":"<<p.work<<",\"sse_units\":"<<p.loss<<",\"witness\":\""<<p.witness<<"\"}";}o<<"]";}
int main(int argc,char**argv) {
  int single=argc>2?stoi(argv[2]):-1;
  auto start=Clock::now();auto gs=groups(single<0 || (single<8 && (single&2)));auto build=Clock::now();
  size_t prefixes=0,nodes=0,unique=0;
  for(auto&g:gs){prefixes+=g.prefixes.size();nodes+=g.trie.size();for(auto&n:g.trie)unique+=n.witness>=0;}
  for(int s=0;s<16;s++)for(int k=0;k<2;k++)for(int a=0;a<6;a++)
    if(op(swaplanes(s),a^1,k)!=swaplanes(op(s,a,k)))return 3;
  ostream*out=&cout;ofstream file;if(argc>1){file.open(argv[1]);out=&file;}auto&o=*out;
  o<<"{\"prefixes\":"<<prefixes<<",\"unique_tagged_states\":"<<unique<<",\"index_nodes\":"<<nodes<<",\"index_storage_bytes\":"<<nodes*sizeof(Node)<<",\"index_build_ms\":"<<chrono::duration<double,milli>(build-start).count()<<",\"teachers\":[";
  bool first=true;
  for(auto&[name,t]:teachers()) {
    if(!first)o<<",";first=false;
    o<<"{\"name\":\""<<name<<"\",\"target\":[";
    for(int j=0;j<32;j++){if(j)o<<",";o<<t[j];}o<<"],\"arms\":[";
    vector<tuple<int,int,int>> oracle;
    for(int arm=single<0?0:single;arm<(single<0?9:single+1);arm++) {
      auto a=Clock::now();auto m=search(gs,t,arm==8?5:arm,arm==8);auto z=Clock::now();
      auto sig=signature();if(arm==0)oracle=sig;else if(single<0 && sig!=oracle){cerr<<"frontier mismatch "<<name<<" "<<arm<<"\n";return 2;}
      if(single<0 && arm)o<<",";
      o<<"{\"flags\":"<<arm<<",\"ms\":"<<chrono::duration<double,milli>(z-a).count()<<",\"scored\":"<<m.scored<<",\"bounds\":"<<m.bounds<<",\"pruned\":"<<m.pruned<<",\"index_visits\":"<<m.visits<<",\"frontier\":";outputfrontier(o);o<<"}";
    }
    o<<"]}";
  }
  long peak=0;string line;ifstream status("/proc/self/status");
  while(getline(status,line))if(line.starts_with("VmHWM:"))peak=stol(line.substr(6));
  o<<"],\"peak_rss_kib\":"<<peak<<",\"elapsed_ms\":"<<chrono::duration<double,milli>(Clock::now()-start).count()<<"}\n";
}
