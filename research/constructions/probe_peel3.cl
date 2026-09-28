__kernel void peel3(__global uint * remainder,
                    __global uint * digit,
                    __global const uint * packed) {
    uint i = __builtin_amdgcn_workitem_id_x();
    uint product = packed[i] * 3u;
    digit[i] = (product >> 8) & 0x00300c03u;
    remainder[i] = product & 0x0ff3fcffu;
}
