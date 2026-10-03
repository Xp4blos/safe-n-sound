#include "fingerprint.h"

#include <algorithm>
#include <cmath>

namespace sns {

namespace {
constexpr float kPeakNormHz = 8000.0f;
constexpr double kPeakClusterRatio = 1.03;

struct Segment {
    int start;
    int length;
};

std::vector<Segment> FindSegments(const std::vector<bool>& mask) {
    std::vector<Segment> segs;
    int inactiveRun = kMinSegmentGapFrames;
    for (int i = 0; i < static_cast<int>(mask.size()); ++i) {
        if (mask[i]) {
            if (inactiveRun >= kMinSegmentGapFrames) segs.push_back({i, 0});
            segs.back().length = i + 1 - segs.back().start;
            inactiveRun = 0;
        } else {
            ++inactiveRun;
        }
    }
    return segs;
}

void FillPeaks(const std::vector<FrameFeatures>& frames, const std::vector<bool>& mask, Fingerprint* fp) {
    std::vector<float> all;
    for (size_t i = 0; i < frames.size(); ++i) {
        if (!mask[i]) continue;
        for (int p = 0; p < frames[i].peakCount; ++p) all.push_back(frames[i].peakHz[p]);
    }
    std::sort(all.begin(), all.end());
    struct Cluster {
        double sum;
        int n;
    };
    std::vector<Cluster> clusters;
    for (float hz : all) {
        if (!clusters.empty() && hz <= (clusters.back().sum / clusters.back().n) * kPeakClusterRatio) {
            clusters.back().sum += hz;
            ++clusters.back().n;
        } else {
            clusters.push_back({hz, 1});
        }
    }
    std::stable_sort(clusters.begin(), clusters.end(), [](const Cluster& a, const Cluster& b) { return a.n > b.n; });
    std::vector<float> top;
    for (size_t i = 0; i < clusters.size() && i < 3; ++i) {
        top.push_back(static_cast<float>(clusters[i].sum / clusters[i].n) / kPeakNormHz);
    }
    std::sort(top.begin(), top.end());
    for (size_t i = 0; i < top.size(); ++i) (*fp)[i] = top[i];
}

void FillBands(const std::vector<FrameFeatures>& frames, const std::vector<bool>& mask, Fingerprint* fp) {
    std::array<double, 16> sum{};
    int n = 0;
    for (size_t i = 0; i < frames.size(); ++i) {
        if (!mask[i]) continue;
        for (int b = 0; b < 16; ++b) sum[b] += frames[i].bandEnergy[b];
        ++n;
    }
    double total = 0.0;
    for (double v : sum) total += v;
    if (n == 0 || total <= 0.0) return;
    for (int b = 0; b < 16; ++b) (*fp)[3 + b] = static_cast<float>(sum[b] / total);
}

void FillRhythm(const std::vector<bool>& mask, double frameSec, Fingerprint* fp) {
    const auto segs = FindSegments(mask);
    if (segs.size() < 3) return;
    double periodFrames = 0.0, onFrames = 0.0;
    for (size_t i = 1; i < segs.size(); ++i) periodFrames += segs[i].start - segs[i - 1].start;
    periodFrames /= static_cast<double>(segs.size() - 1);
    for (const auto& s : segs) onFrames += s.length;
    onFrames /= static_cast<double>(segs.size());
    const double periodSec = periodFrames * frameSec;
    (*fp)[19] = static_cast<float>(std::min(1.0, periodSec / 2.0));
    (*fp)[20] = static_cast<float>(std::min(1.0, onFrames / periodFrames));
}

void FillEnvelope(const std::vector<FrameFeatures>& frames, Fingerprint* fp) {
    const int n = static_cast<int>(frames.size());
    if (n == 0) return;
    std::array<double, 8> env{};
    double maxV = 0.0;
    for (int j = 0; j < 8; ++j) {
        const int lo = j * n / 8;
        const int hi = std::max(lo + 1, (j + 1) * n / 8);
        double acc = 0.0;
        int cnt = 0;
        for (int i = lo; i < hi && i < n; ++i, ++cnt) acc += std::pow(10.0, frames[i].levelDb / 20.0);
        env[j] = cnt ? acc / cnt : 0.0;
        maxV = std::max(maxV, env[j]);
    }
    if (maxV <= 0.0) return;
    for (int j = 0; j < 8; ++j) (*fp)[21 + j] = static_cast<float>(env[j] / maxV);
}
}  // namespace

Fingerprint BuildFingerprint(const std::vector<FrameFeatures>& frames, const std::vector<bool>& activeMask,
                             double frameSec) {
    Fingerprint fp{};
    FillPeaks(frames, activeMask, &fp);
    FillBands(frames, activeMask, &fp);
    FillRhythm(activeMask, frameSec, &fp);
    FillEnvelope(frames, &fp);
    return fp;
}

}  // namespace sns
