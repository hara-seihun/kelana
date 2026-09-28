// Complete-image cold code-page boundary, without Python in the timed loop.
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <numeric>
#include <random>
#include <stdexcept>
#include <string>
#include <vector>
#include <zlib.h>

using Bytes = std::vector<unsigned char>;
struct Page {
    const unsigned char * raw;
    const unsigned char * stored;
    size_t raw_size, stored_size;
};
static Bytes load(const std::string & name) {
    std::ifstream file(name, std::ios::binary | std::ios::ate);
    if (!file) throw std::runtime_error("cannot open " + name);
    auto size = file.tellg();
    Bytes bytes(static_cast<size_t>(size));
    file.seekg(0);
    if (!file.read(reinterpret_cast<char *>(bytes.data()), size)) throw std::runtime_error("read " + name);
    return bytes;
}
static uint32_t u32(const Bytes & b, size_t pos) {
    if (pos + 4 > b.size()) throw std::runtime_error("directory out of bounds");
    return uint32_t(b[pos]) | uint32_t(b[pos+1]) << 8 | uint32_t(b[pos+2]) << 16 | uint32_t(b[pos+3]) << 24;
}
static void unpack(const Page & p, Bytes & scratch) {
    if (p.stored_size == 0 || p.stored[0] != 1) throw std::runtime_error("expected compressed page");
    uLongf size = scratch.size();
    if (uncompress(scratch.data(), &size, p.stored + 1, p.stored_size - 1) != Z_OK || size != p.raw_size)
        throw std::runtime_error("invalid zlib page");
}
int main(int argc, char ** argv) {
    if (argc != 5) throw std::runtime_error("usage: native_consumer manifest.tsv raw-dir paged-dir repeats");
    const int repeats = std::stoi(argv[4]);
    if (repeats < 2 || repeats > 100) throw std::runtime_error("invalid repeats");
    std::ifstream manifest(argv[1]);
    if (!manifest) throw std::runtime_error("manifest not found");
    std::vector<Bytes> raw_images, paged_images;
    raw_images.reserve(197);
    paged_images.reserve(197);
    std::vector<Page> pages;
    std::string name;
    size_t code_bytes, count, width;
    while (manifest >> name >> code_bytes >> count >> width) {
        raw_images.push_back(load(std::string(argv[2]) + "/" + name));
        paged_images.push_back(load(std::string(argv[3]) + "/" + name));
        const auto & raw = raw_images.back();
        const auto & stored = paged_images.back();
        const size_t body = 12 + 4 * (count + 1);
        if (raw.size() < 12 + code_bytes || stored.size() < body || u32(stored, 12) != 0)
            throw std::runtime_error("invalid code image");
        for (size_t i = 0; i < count; ++i) {
            size_t start = u32(stored, 12 + 4*i), end = u32(stored, 12 + 4*(i+1));
            size_t n = std::min(width, code_bytes - i*width);
            if (n == 0 || body + end > stored.size() || end <= start)
                throw std::runtime_error("invalid page offset");
            pages.push_back({raw.data() + 12 + i*width, stored.data() + body + start, n, end - start});
        }
        if (u32(stored, 12 + 4*count) != stored.size() - body - (raw.size() - 12 - code_bytes))
            throw std::runtime_error("end offset or suffix mismatch");
    }
    if (pages.size() != 7360 || raw_images.size() != 197) throw std::runtime_error("not complete image");
    Bytes scratch(width);
    for (auto & p : pages) {
        unpack(p, scratch);
        if (!std::equal(scratch.begin(), scratch.begin() + p.raw_size, p.raw))
            throw std::runtime_error("decoded code mismatch");
    }
    std::vector<size_t> ordered(pages.size()), shuffled(pages.size());
    std::iota(ordered.begin(), ordered.end(), 0);
    shuffled = ordered;
    std::mt19937 rng(20260924);
    std::shuffle(shuffled.begin(), shuffled.end(), rng);
    std::cerr << "verified " << pages.size() << " compressed pages across " << raw_images.size() << " matrices\n";
    std::cout << "panel,repetition,arm,milliseconds,crc32\n";
    for (int random = 0; random < 2; ++random) {
        const auto & order = random ? shuffled : ordered;
        for (int repetition = 0; repetition < repeats; ++repetition) {
            for (int k = 0; k < 2; ++k) {
                bool compressed = ((repetition + k) & 1) != 0;
                uLong crc = crc32(0, Z_NULL, 0);
                auto begin = std::chrono::steady_clock::now();
                for (size_t i : order) {
                    const auto & p = pages[i];
                    if (compressed) unpack(p, scratch);
                    const unsigned char * data = compressed ? scratch.data() : p.raw;
                    crc = crc32(crc, data, random ? 1 : p.raw_size);
                }
                auto end = std::chrono::steady_clock::now();
                auto ms = std::chrono::duration<double, std::milli>(end - begin).count();
                std::cout << (random ? "shuffled-first" : "complete-stream") << ',' << repetition << ','
                          << (compressed ? "paged" : "raw") << ',' << ms << ',' << crc << '\n';
            }
        }
    }
}
