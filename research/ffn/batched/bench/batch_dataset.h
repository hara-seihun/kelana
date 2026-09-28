// Loader for a kelana-ffn-batch dataset: one layer's deployed weights plus real contextual token
// rows captured chunk by chunk from the deployed engine.
//
// A batch of N rows is chunks 0 .. N/rmax - 1 concatenated in document order, so row r of the batch
// is token r of the document at its own position with the real state of every preceding token. The
// FFN is row-independent once the incoming residual is fixed, which is what makes rows captured in
// separate passes a legitimate single batch.
#pragma once
#include "../api.hpp"
#include <cstdint>
#include <string>
#include <vector>

namespace kbatch {

struct Chunk {
    int index = 0, rows = 0, position0 = 0;
    std::vector<int> tokens;
    std::vector<float> x_in;    // [rows][D] residual entering the layer FFN
    std::vector<float> x_out;   // [rows][D] residual the engine leaves after the layer FFN
};

struct Dataset {
    std::string dir, format, model, bonsai_commit, built_at;
    std::string document, document_sha256, tokens_sha256, input_kind;
    bool bonsai_dirty = false;
    int D = 0, FF = 0, rmax = 0, layer = 0;
    std::vector<uint8_t> gate_host, up_host, down_host;
    std::vector<float> post_norm_host, post_norm_s_host, signs_d_host, signs_ff_host;
    uint8_t * gate_dev = nullptr, * up_dev = nullptr, * down_dev = nullptr;
    float * norm_dev = nullptr, * signs_dev = nullptr;
    std::vector<Chunk> chunks;

    int max_rows() const { return (int) chunks.size() * rmax; }
    // api.hpp Weights, with norm_* = the post-attention norm folded with the width-D sign vector
    // and signs_* = the width-FF Hadamard sign vector, which is what the deployed FFN consumes.
    kelana_batch::Weights weights() const;
    // Concatenates the first rows/rmax chunks. Throws when rows is not available.
    void batch(int rows, std::vector<float> & x_in, std::vector<float> & x_ref) const;
    std::vector<int> batch_tokens(int rows) const;
};

Dataset load(const std::string & dir);   // throws std::runtime_error

} // namespace kbatch
