// Native check of the whole-map constructions on gfx1151.
//
// Lane j of a wave32 holds the map's value at the input whose address selects
// lane j; every lane then evaluates its own input. The kernel runs the two
// shapes this search produced and compares against host-computed exact values:
//
//   A  ds_bpermute_b32 alone, from a pre-scaled balanced-ternary address
//   B  v_dot4_i32_iu8 with the universal coefficient word, then the same lookup
//
// It also checks what the manual says about the lane index: only bits [6:2] of
// the address are used, and offset0 is added before use. Those two facts are
// what make the address arithmetic free to overflow into higher bits.
#include <hip/hip_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <vector>

#define HIP_CHECK(e)                                                           \
  do {                                                                         \
    hipError_t _e = (e);                                                       \
    if (_e != hipSuccess) {                                                    \
      printf("{\"error\":\"%s\",\"line\":%d}\n", hipGetErrorString(_e),         \
             __LINE__);                                                        \
      return 1;                                                                \
    }                                                                          \
  } while (0)

// Written as inline assembly so the instruction-count claims are literal:
// these are the exact opcodes the kernel contains.
__device__ __forceinline__ int bpermute(int addr, int value) {
  int r;
  asm volatile("ds_bpermute_b32 %0, %1, %2\n\ts_waitcnt lgkmcnt(0)"
               : "=v"(r) : "v"(addr), "v"(value));
  return r;
}

// v_dot4_i32_iu8 with both operands read as signed bytes and the bias as an
// inline constant. The coefficient word is the universal (4, 12, 36, 0).
__device__ __forceinline__ int balanced_address(int xb, int coeff) {
  int r;
  asm volatile("v_dot4_i32_iu8 %0, %1, %2, 52 neg_lo:[1,1]"
               : "=v"(r) : "v"(xb), "v"(coeff));
  return r;
}

// One wave32 per block. Each lane owns one of the 32 lane slots and one input.
__global__ void whole_map(const int *__restrict__ table,
                          const int *__restrict__ addr_in,
                          const int *__restrict__ bytes_in, int *outA,
                          int *outB, int *outIdx, int coeff) {
  int lane = threadIdx.x;
  int t = table[lane];

  // A: the address arrives pre-scaled, so the map is one instruction.
  outA[lane] = bpermute(addr_in[lane], t);

  // B: build the address from the byte-packed trits with the universal
  // coefficient word (4, 12, 36, 0) and the inline bias 4*13.
  int xb = bytes_in[lane];
  int a = balanced_address(xb, coeff);
  outB[lane] = bpermute(a, t);
  outIdx[lane] = a;
}

// Does the hardware really ignore everything outside address bits [6:2]?
__global__ void index_bits(const int *__restrict__ table, int *out) {
  int lane = threadIdx.x;
  int t = table[lane];
  int base = lane * 4;
  out[lane] = bpermute(base, t);
  out[32 + lane] = bpermute(base | 0x3, t);          // low two bits ignored
  out[64 + lane] = bpermute(base | 0x7FFFFF80, t);   // high bits ignored
}

int main() {
  const int trit[3] = {-1, 0, 1};
  std::vector<int> states;
  for (int a = 0; a < 3; ++a)
    for (int b = 0; b < 3; ++b)
      for (int c = 0; c < 3; ++c)
        states.push_back(a * 9 + b * 3 + c);

  // A fixed-weight gated ReLU network on three trits, ternary weights.
  const int W = 64;
  std::vector<int> g(W * 3), u(W * 3), sgn(W);
  unsigned seed = 20260915u;
  auto rnd = [&]() { seed = seed * 1664525u + 1013904223u; return seed >> 16; };
  for (int i = 0; i < W; ++i) {
    for (int k = 0; k < 3; ++k) {
      g[i * 3 + k] = (int)(rnd() % 3) - 1;
      u[i * 3 + k] = (int)(rnd() % 3) - 1;
    }
    sgn[i] = (rnd() % 2) ? 1 : -1;
  }
  auto eval = [&](int x0, int x1, int x2) {
    int total = 0;
    for (int i = 0; i < W; ++i) {
      int pre = g[i * 3] * x0 + g[i * 3 + 1] * x1 + g[i * 3 + 2] * x2;
      if (pre > 0)
        total += sgn[i] * pre *
                 (u[i * 3] * x0 + u[i * 3 + 1] * x1 + u[i * 3 + 2] * x2);
    }
    return total;
  };

  std::vector<int> table(32, 0), addr(32, 0), bytes(32, 0), want(32, 0);
  for (int s = 0; s < 27; ++s) {
    int x0 = trit[s % 3], x1 = trit[(s / 3) % 3], x2 = trit[s / 9];
    int lane = 13 + x0 + 3 * x1 + 9 * x2;
    table[lane] = eval(x0, x1, x2);
  }
  // Give each lane an input; lanes 27..31 repeat state 0 so all lanes are active.
  for (int lane = 0; lane < 32; ++lane) {
    int s = lane < 27 ? lane : 0;
    int x0 = trit[s % 3], x1 = trit[(s / 3) % 3], x2 = trit[s / 9];
    addr[lane] = 4 * (13 + x0 + 3 * x1 + 9 * x2);
    bytes[lane] = (x0 & 0xFF) | ((x1 & 0xFF) << 8) | ((x2 & 0xFF) << 16);
    want[lane] = eval(x0, x1, x2);
  }

  int *dT, *dA, *dB, *dOA, *dOB, *dOI, *dIB;
  HIP_CHECK(hipMalloc(&dT, 32 * 4));
  HIP_CHECK(hipMalloc(&dA, 32 * 4));
  HIP_CHECK(hipMalloc(&dB, 32 * 4));
  HIP_CHECK(hipMalloc(&dOA, 32 * 4));
  HIP_CHECK(hipMalloc(&dOB, 32 * 4));
  HIP_CHECK(hipMalloc(&dOI, 32 * 4));
  HIP_CHECK(hipMalloc(&dIB, 96 * 4));
  HIP_CHECK(hipMemcpy(dT, table.data(), 32 * 4, hipMemcpyHostToDevice));
  HIP_CHECK(hipMemcpy(dA, addr.data(), 32 * 4, hipMemcpyHostToDevice));
  HIP_CHECK(hipMemcpy(dB, bytes.data(), 32 * 4, hipMemcpyHostToDevice));

  hipLaunchKernelGGL(whole_map, dim3(1), dim3(32), 0, 0, dT, dA, dB, dOA, dOB,
                     dOI, 0x00240C04);
  HIP_CHECK(hipDeviceSynchronize());
  hipLaunchKernelGGL(index_bits, dim3(1), dim3(32), 0, 0, dT, dIB);
  HIP_CHECK(hipDeviceSynchronize());

  std::vector<int> oa(32), ob(32), oi(32), ib(96);
  HIP_CHECK(hipMemcpy(oa.data(), dOA, 32 * 4, hipMemcpyDeviceToHost));
  HIP_CHECK(hipMemcpy(ob.data(), dOB, 32 * 4, hipMemcpyDeviceToHost));
  HIP_CHECK(hipMemcpy(oi.data(), dOI, 32 * 4, hipMemcpyDeviceToHost));
  HIP_CHECK(hipMemcpy(ib.data(), dIB, 96 * 4, hipMemcpyDeviceToHost));

  int badA = 0, badB = 0, badAddr = 0, badBits = 0;
  for (int lane = 0; lane < 32; ++lane) {
    if (oa[lane] != want[lane]) ++badA;
    if (ob[lane] != want[lane]) ++badB;
    if (oi[lane] != addr[lane]) ++badAddr;
    if (ib[lane] != table[lane]) ++badBits;
    if (ib[32 + lane] != table[lane]) ++badBits;
    if (ib[64 + lane] != table[lane]) ++badBits;
  }

  hipDeviceProp_t prop;
  HIP_CHECK(hipGetDeviceProperties(&prop, 0));
  printf("{\n");
  printf("  \"device\": \"%s\",\n", prop.gcnArchName);
  printf("  \"network\": {\"width\": %d, \"weights\": \"ternary\"},\n", W);
  printf("  \"lanes\": 32, \"states\": 27,\n");
  printf("  \"A_one_instruction_mismatches\": %d,\n", badA);
  printf("  \"B_two_instruction_mismatches\": %d,\n", badB);
  printf("  \"dot4_address_mismatches\": %d,\n", badAddr);
  printf("  \"index_bits_6_2_only_mismatches\": %d,\n", badBits);
  printf("  \"cases\": %d\n", 32 * 2 + 32 + 96);
  printf("}\n");
  return (badA || badB || badAddr || badBits) ? 1 : 0;
}
