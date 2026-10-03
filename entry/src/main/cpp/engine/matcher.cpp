#include "matcher.h"

#include <algorithm>
#include <cmath>

namespace sns {

namespace {
constexpr float kPeakExactRel = 0.01f;  // peaks within 1% are a full match
constexpr float kPeakZeroRel = 0.03f;   // beyond 3% they do not match at all
constexpr float kPeriodTolerance = 0.25f;
constexpr float kDutyTolerance = 0.30f;

float PeakCloseness(float a, float b) {
    const float rel = std::fabs(a - b) / std::max(a, b);
    if (rel <= kPeakExactRel) return 1.0f;
    if (rel >= kPeakZeroRel) return 0.0f;
    return 1.0f - (rel - kPeakExactRel) / (kPeakZeroRel - kPeakExactRel);
}

float BestCloseness(float peak, const Fingerprint& other) {
    float best = 0.0f;
    for (int j = 0; j < 3; ++j) {
        if (other[j] > 0.0f) best = std::max(best, PeakCloseness(peak, other[j]));
    }
    return best;
}

float PeaksScore(const Fingerprint& a, const Fingerprint& b) {
    int count = 0;
    float sum = 0.0f;
    for (int i = 0; i < 3; ++i) {
        if (a[i] > 0.0f) {
            ++count;
            sum += BestCloseness(a[i], b);
        }
        if (b[i] > 0.0f) {
            ++count;
            sum += BestCloseness(b[i], a);
        }
    }
    return count == 0 ? 0.0f : sum / static_cast<float>(count);
}

float SpectrumScore(const Fingerprint& a, const Fingerprint& b) {
    double dot = 0.0, na = 0.0, nb = 0.0;
    for (int i = 3; i < 19; ++i) {
        dot += static_cast<double>(a[i]) * b[i];
        na += static_cast<double>(a[i]) * a[i];
        nb += static_cast<double>(b[i]) * b[i];
    }
    if (na <= 0.0 || nb <= 0.0) return 0.0f;
    return static_cast<float>(dot / std::sqrt(na * nb));
}

float RhythmScore(const Fingerprint& a, const Fingerprint& b) {
    const bool pa = a[19] > 0.0f, pb = b[19] > 0.0f;
    if (!pa && !pb) return 1.0f;
    if (pa != pb) return 0.0f;
    const float rel = std::fabs(a[19] - b[19]) / std::max(a[19], b[19]);
    const float periodScore = std::max(0.0f, 1.0f - rel / kPeriodTolerance);
    const float dutyScore = std::max(0.0f, 1.0f - std::fabs(a[20] - b[20]) / kDutyTolerance);
    return 0.6f * periodScore + 0.4f * dutyScore;
}

float EnvelopeScore(const Fingerprint& a, const Fingerprint& b) {
    float diff = 0.0f;
    for (int i = 21; i < 29; ++i) diff += std::fabs(a[i] - b[i]);
    return std::max(0.0f, 1.0f - diff / 8.0f);
}
}  // namespace

float Similarity(const Fingerprint& a, const Fingerprint& b) {
    return 0.5f * PeaksScore(a, b) + 0.2f * SpectrumScore(a, b) + 0.2f * RhythmScore(a, b) +
           0.1f * EnvelopeScore(a, b);
}

MatchResult Match(const Fingerprint& fp, const std::vector<Fingerprint>& saved, float threshold) {
    MatchResult best{-1, 0.0f};
    int bestIndex = -1;
    for (size_t i = 0; i < saved.size(); ++i) {
        const float s = Similarity(fp, saved[i]);
        if (s > best.score) {
            best.score = s;
            bestIndex = static_cast<int>(i);
        }
    }
    if (best.score >= threshold) best.index = bestIndex;
    return best;
}

}  // namespace sns
