#include "labels.hpp"
#include <array>
#include <fstream>
#include <iostream>
#include <iterator>
#include <vector>
int main(int argc,char**argv) {
  if(argc!=3)return 2;
  std::ifstream in(argv[1],std::ios::binary);
  std::vector<unsigned char> image{std::istreambuf_iterator<char>(in),{}};
  if(image.size()!=49327)return 3;
  std::array<uint32_t,256> table{};
  for(unsigned c=0;c<256;c++)table[c]=packed_magnitude(c,image.data()+49298);
  std::ofstream out(argv[2],std::ios::binary);
  out.write(reinterpret_cast<const char*>(table.data()),sizeof(table));
  if(!out)return 4;
  std::cout<<"prepared_bytes="<<sizeof(table)<<" exception_bytes=29\n";
}
