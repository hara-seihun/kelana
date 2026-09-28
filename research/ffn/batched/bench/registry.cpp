// The one definition of the shared registry from api.hpp. Every candidate translation unit, in
// bench/candidates or in a sibling worker's candidates directory, registers itself into this vector
// at static construction time through KELANA_BATCH_REGISTER, so adding a candidate never touches a
// shared file.
#include "../api.hpp"

namespace kelana_batch {
std::vector<Candidate> & registry() {
    static std::vector<Candidate> r;
    return r;
}
} // namespace kelana_batch
