// Spanning candidates: one arithmetic, several representations of the region between the gate/up
// projection and the down projection.
//
// Every candidate here reproduces the deployed engine's floating accumulation order for each
// (output, token) and is registered as exact_reference. They differ only in
//
//   panel        how many tokens one work unit carries, which decides how often the weight image
//                is re-read, and
//   group_chunks how much of the FP32 hidden image exists between its producer and its consumer.
//
// The panel/schedule sweep is the measurement; see ../README.md.
#include "../../api.hpp"
#include "../region.hpp"

namespace {

using kelana_span::State;

State * prep_common(const kelana_batch::Weights & w, int max_batch, int panel, int group_chunks, int tile_major, int packed, int gu_t) {
    if (w.width != halo::D || w.hidden != halo::FF) {
        fprintf(stderr, "spanning: geometry %dx%d is not the deployed %dx%d\n", w.width, w.hidden, halo::D, halo::FF);
        abort();
    }
    return kelana_span::make_state(w.gate_device, w.up_device, w.down_device,
                                   w.norm_device, w.signs_device, max_batch, panel, group_chunks, tile_major, packed, gu_t);
}

void release(void * s) { kelana_span::free_state((State *) s); }
size_t resident_bytes(void * s) { return ((State *) s)->resident; }
void run(void * s, int rows, const float * in, float * out, hipStream_t st) {
    kelana_span::launch((State *) s, rows, in, out, st);
}

#define SPAN_CANDIDATE(fn, cname, panel, groups, tm, pk, gt, desc)                                  \
    void * prepare_##fn(const kelana_batch::Weights & w, int mb) {                          \
        return prep_common(w, mb, panel, groups, tm, pk, gt);                                       \
    }                                                                                       \
    kelana_batch::Candidate fn() {                                                          \
        kelana_batch::Candidate c{};                                                        \
        c.name = cname;                                                                     \
        c.claim = kelana_batch::Claim::exact_reference;                                     \
        c.description = desc;                                                               \
        c.prepare = prepare_##fn; c.run = run; c.release = release;                          \
        c.resident_bytes = resident_bytes;                                                  \
        return c;                                                                           \
    }

// Token panel sweep, deployed phase structure (the whole hidden image between the producer and the
// consumer). 16 is the deployed unit width; 256 reads each weight tile once for the whole batch.
SPAN_CANDIDATE(span_p16, "span-p16", 16, 17, 0, 0, 0, "panel 16 tokens, whole-image hidden, deployed K split")
SPAN_CANDIDATE(span_p32, "span-p32", 32, 17, 0, 0, 0, "panel 32 tokens, whole-image hidden, deployed K split")
SPAN_CANDIDATE(span_p128, "span-p128", 128, 17, 0, 0, 0, "panel 128 tokens, whole-image hidden, wave-per-token-group split")
SPAN_CANDIDATE(span_p256, "span-p256", 256, 17, 0, 0, 0, "panel 256 tokens, whole-image hidden, wave-per-token-group split")

// Same arithmetic, hidden image blocked into chunk groups so the quantiser consumes each 1024-wide
// chunk while the projection's output is still hot.
SPAN_CANDIDATE(span_p256_c8, "span-p256-chunk8", 256, 8, 0, 0, 0, "panel 256, hidden consumed 8 chunks at a time")
SPAN_CANDIDATE(span_p256_c4, "span-p256-chunk4", 256, 4, 0, 0, 0, "panel 256, hidden consumed 4 chunks at a time")
SPAN_CANDIDATE(span_p256_c2, "span-p256-chunk2", 256, 2, 0, 0, 0, "panel 256, hidden consumed 2 chunks at a time")
SPAN_CANDIDATE(span_p256_c1, "span-p256-chunk1", 256, 1, 0, 0, 0, "panel 256, hidden consumed one 1024 chunk at a time")

// Tile-major unit order: the panels of one weight tile are consecutive, so a batch that needs more
// than one panel re-reads that tile out of cache rather than out of DRAM.
SPAN_CANDIDATE(span_p32_tm, "span-p32-tilemajor", 32, 17, 1, 0, 0, "panel 32, tile-major unit order")

// The quantiser emits the panel layout its consumer's WMMA B fragments want, so a fragment load is
// 256 contiguous bytes instead of sixteen 16-byte pieces one row stride apart. Identical bytes,
// identical arithmetic, different addresses.
SPAN_CANDIDATE(span_pk256, "span-panel256", 256, 17, 0, 1, 0, "panel 256, quantiser emits the WMMA panel layout")
SPAN_CANDIDATE(span_pk128, "span-panel128", 128, 17, 0, 1, 0, "panel 128, quantiser emits the WMMA panel layout")
SPAN_CANDIDATE(span_pk32, "span-panel32", 32, 17, 0, 1, 0, "panel 32, quantiser emits the WMMA panel layout")
SPAN_CANDIDATE(span_pk16, "span-panel16", 16, 17, 0, 1, 0, "panel 16, quantiser emits the WMMA panel layout")
SPAN_CANDIDATE(span_pk256_c4, "span-panel256-chunk4", 256, 4, 0, 1, 0, "panel 256 layout, hidden consumed 4 chunks at a time")
SPAN_CANDIDATE(span_pk256_c1, "span-panel256-chunk1", 256, 1, 0, 1, 0, "panel 256 layout, hidden consumed one chunk at a time")
SPAN_CANDIDATE(span_pk256_c8, "span-panel256-chunk8", 256, 8, 0, 1, 0, "panel 256 layout, hidden consumed 8 chunks at a time")

// The projection also emits its own output where its consumer wants it. A WMMA C fragment holds
// sixteen tokens across the lanes and its rows in the register index, so a row-major [token][hidden]
// store scatters sixteen separate four-byte writes per instruction. Storing the hidden image as
// [hidden][token] makes that one contiguous write per instruction; the nonlinearity then reads a
// token's chunk with a stride.
SPAN_CANDIDATE(span_gt256, "span-hidden-t256", 256, 17, 0, 1, 1, "panel 256, hidden held as [hidden][token]")
SPAN_CANDIDATE(span_gt32,  "span-hidden-t32",   32, 17, 0, 1, 1, "panel 32, hidden held as [hidden][token]")

} // namespace

KELANA_BATCH_REGISTER(span_p16)
KELANA_BATCH_REGISTER(span_p32)
KELANA_BATCH_REGISTER(span_p128)
KELANA_BATCH_REGISTER(span_p256)
KELANA_BATCH_REGISTER(span_p256_c8)
KELANA_BATCH_REGISTER(span_p256_c4)
KELANA_BATCH_REGISTER(span_p256_c2)
KELANA_BATCH_REGISTER(span_p256_c1)
KELANA_BATCH_REGISTER(span_p32_tm)
KELANA_BATCH_REGISTER(span_pk256)
KELANA_BATCH_REGISTER(span_gt256)
KELANA_BATCH_REGISTER(span_gt32)
KELANA_BATCH_REGISTER(span_pk128)
KELANA_BATCH_REGISTER(span_pk32)
KELANA_BATCH_REGISTER(span_pk16)
KELANA_BATCH_REGISTER(span_pk256_c4)
KELANA_BATCH_REGISTER(span_pk256_c1)
KELANA_BATCH_REGISTER(span_pk256_c8)
