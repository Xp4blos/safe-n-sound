#include "event_detector.h"

#include <algorithm>

namespace sns {

namespace {
constexpr float kFloorRiseDbPerSec = 1.0f;
constexpr float kFloorFallRate = 0.2f;  // fraction of the gap closed per frame when level is below the floor
}  // namespace

EventDetector::EventDetector(int sampleRate) : frameSec_(static_cast<double>(kFrameSize) / sampleRate) {}

void EventDetector::Push(const FrameFeatures& f, double frameStartSec, std::vector<Event>* out) {
    const double frameEndSec = frameStartSec + frameSec_;
    const bool active = f.levelDb > floorDb_ + kActiveMarginDb && f.tonality >= kTonalityMin;

    if (!active) {
        // Track background level: fall quickly, rise slowly, never below the absolute minimum.
        if (f.levelDb < floorDb_) {
            floorDb_ += (f.levelDb - floorDb_) * kFloorFallRate;
        } else {
            floorDb_ += std::min(f.levelDb - floorDb_, kFloorRiseDbPerSec * static_cast<float>(frameSec_));
        }
        floorDb_ = std::max(floorDb_, kFloorMinDb);
    }

    if (active) {
        if (!inEvent_) {
            inEvent_ = true;
            startSec_ = frameStartSec;
            segments_ = 0;
            inactiveRun_ = kMinSegmentGapFrames;  // first active frame opens segment 1
            frames_.clear();
            mask_.clear();
        }
        if (inactiveRun_ >= kMinSegmentGapFrames) ++segments_;
        inactiveRun_ = 0;
        lastActiveEndSec_ = frameEndSec;
        frames_.push_back(f);
        mask_.push_back(true);
    } else if (inEvent_) {
        ++inactiveRun_;
        frames_.push_back(f);
        mask_.push_back(false);
        if (frameEndSec - lastActiveEndSec_ >= kCloseSilenceSec) Close(out);
    }

    if (inEvent_ && frameEndSec - startSec_ >= kMaxEventSec) Close(out);
}

void EventDetector::Flush(std::vector<Event>* out) {
    if (inEvent_) Close(out);
}

void EventDetector::Close(std::vector<Event>* out) {
    const double duration = lastActiveEndSec_ - startSec_;
    if (duration >= kMinEventSec) {
        Event e{};
        e.startSec = startSec_;
        e.durationSec = duration;
        e.kind = segments_ >= 3 ? EventKind::Pulsed : EventKind::Tonal;
        while (!mask_.empty() && !mask_.back()) {  // drop the trailing silence that closed the event
            mask_.pop_back();
            frames_.pop_back();
        }
        e.fp = BuildFingerprint(frames_, mask_, frameSec_);
        out->push_back(e);
    }
    inEvent_ = false;
    segments_ = 0;
    inactiveRun_ = 0;
}

}  // namespace sns
