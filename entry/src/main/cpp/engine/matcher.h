#pragma once
#include <vector>

#include "types.h"

namespace sns {

constexpr float kMatchThreshold = 0.80f;

struct MatchResult {
    int index;    // index into `saved`, or -1 when nothing reaches the threshold
    float score;  // best similarity found (0 when `saved` is empty)
};

// Weighted similarity in [0,1]: peaks 0.5, spectral cosine 0.2, rhythm 0.2, envelope 0.1.
float Similarity(const Fingerprint& a, const Fingerprint& b);

MatchResult Match(const Fingerprint& fp, const std::vector<Fingerprint>& saved, float threshold = kMatchThreshold);

}  // namespace sns
