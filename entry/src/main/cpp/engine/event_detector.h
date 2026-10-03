#pragma once
#include <vector>

#include "fingerprint.h"
#include "frame_analyzer.h"
#include "types.h"

namespace sns {

constexpr float kActiveMarginDb = 12.0f;  // frame level must exceed the noise floor by this much
constexpr float kTonalityMin = 20.0f;     // and be at least this tonal
constexpr double kCloseSilenceSec = 0.8;  // an event closes after this much inactivity
constexpr double kMaxEventSec = 10.0;     // events are force-closed at this length
constexpr double kMinEventSec = 0.15;     // shorter events are dropped
constexpr float kFloorMinDb = -70.0f;     // the noise floor never drops below this
constexpr int kWarmupFrames = 8;          // ~0.26 s of ambient sound calibrates the floor; no events meanwhile

class EventDetector {
public:
    explicit EventDetector(int sampleRate);
    // Feed one frame's features; finished events are appended to `out`.
    void Push(const FrameFeatures& f, double frameStartSec, std::vector<Event>* out);
    // Emit the event in progress (if any), e.g. when listening stops.
    void Flush(std::vector<Event>* out);

private:
    void Close(std::vector<Event>* out);

    double frameSec_;
    float floorDb_ = -60.0f;
    bool inEvent_ = false;
    double startSec_ = 0.0;
    double lastActiveEndSec_ = 0.0;
    int segments_ = 0;
    int inactiveRun_ = 0;
    int warmupSeen_ = 0;
    double warmupSumDb_ = 0.0;
    double eventLevelSumDb_ = 0.0;  // sum of levels of the active frames of the event in progress
    int eventLevelCount_ = 0;
    std::vector<FrameFeatures> frames_;  // frames of the event in progress, from its first frame on
    std::vector<bool> mask_;             // true where the matching frame was active
};

}  // namespace sns
