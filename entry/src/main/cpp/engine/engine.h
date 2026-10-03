#pragma once
#include <cstddef>
#include <cstdint>
#include <vector>

#include "event_detector.h"
#include "frame_analyzer.h"
#include "types.h"

namespace sns {

// Streaming facade: feed PCM of any length, get the latest level and any finished events.
class Engine {
public:
    explicit Engine(int sampleRate);
    // `pcm` may be null when sampleCount is 0. Samples that do not fill a whole frame are kept for the
    // next call. Event times are seconds from the first sample ever passed in.
    EngineOutput Process(const int16_t* pcm, size_t sampleCount);

private:
    int sampleRate_;
    FrameAnalyzer analyzer_;
    EventDetector detector_;
    std::vector<int16_t> pending_;
    size_t frameIndex_ = 0;
    float levelDb_ = -100.0f;
};

}  // namespace sns
