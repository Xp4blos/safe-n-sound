#pragma once
// Runs PCM through FrameAnalyzer + EventDetector the way Engine will, for detector/matcher tests.
#include <vector>

#include "../engine/event_detector.h"
#include "../engine/frame_analyzer.h"

inline std::vector<sns::Event> RunDetector(const std::vector<int16_t>& pcm, bool flush) {
    sns::FrameAnalyzer analyzer(sns::kSampleRate);
    sns::EventDetector detector(sns::kSampleRate);
    std::vector<sns::Event> events;
    const double frameSec = static_cast<double>(sns::kFrameSize) / sns::kSampleRate;
    size_t frameIndex = 0;
    for (size_t pos = 0; pos + sns::kFrameSize <= pcm.size(); pos += sns::kFrameSize, ++frameIndex) {
        detector.Push(analyzer.Analyze(pcm.data() + pos), frameIndex * frameSec, &events);
    }
    if (flush) detector.Flush(&events);
    return events;
}
