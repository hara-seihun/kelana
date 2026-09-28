#include <stddef.h>
#include <stdint.h>

// Both entry points consume a contiguous model image and the same input/output layout.
__attribute__((noinline)) void scalar_reader(const uint8_t *image, const int16_t *x,
                                               int32_t *y, size_t tiles) {
    for (size_t t = 0; t < tiles; ++t) {
        const uint8_t *p = image + 5 * t;
        uint32_t code = (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
                        ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
        int32_t rows[4] = {0, 0, 0, 0};
        for (unsigned r = 0; r < 4; ++r) {
            for (unsigned c = 0; c < 4; ++c) {
                int32_t w = (int32_t)(code % 3) - 1;
                code /= 3;
                rows[r] += w * x[4 * t + c];
            }
            y[4 * t + r] = rows[r] * (int32_t)p[4];
        }
    }
}

__attribute__((noinline)) void program_reader(const uint8_t *image, const int16_t *x,
                                                int32_t *y, size_t tiles) {
    for (size_t t = 0; t < tiles; ++t) {
        const uint8_t *p = image + 3 * t;
        unsigned code = p[0];
        int32_t shape[4];
        for (unsigned c = 0; c < 4; ++c) {
            shape[c] = (int32_t)(code % 3) - 1;
            code /= 3;
        }
        for (unsigned r = 0; r < 4; ++r) {
            unsigned shift = (p[1] >> (2 * r)) & 3;
            int32_t acc = 0;
            for (unsigned c = 0; c < 4; ++c) {
                acc += shape[(c + shift) & 3] * x[4 * t + c];
            }
            y[4 * t + r] = acc * (int32_t)p[2];
        }
    }
}
