#include "engine.h"

namespace sns {

Engine::Engine(int sampleRate) : sampleRate_(sampleRate), analyzer_(sampleRate), detector_(sampleRate) {}

EngineOutput Engine::Process(const int16_t* pcm, size_t sampleCount) {
    EngineOutput out{levelDb_, {}};
    if (pcm == nullptr || sampleCount == 0) return out;

    pending_.insert(pending_.end(), pcm, pcm + sampleCount);
    const double frameSec = static_cast<double>(kFrameSize) / sampleRate_;
    size_t consumed = 0;
    while (pending_.size() - consumed >= static_cast<size_t>(kFrameSize)) {
        const FrameFeatures f = analyzer_.Analyze(pending_.data() + consumed);
        levelDb_ = f.levelDb;
        detector_.Push(f, static_cast<double>(frameIndex_) * frameSec, &out.events);
        consumed += kFrameSize;
        ++frameIndex_;
    }
    pending_.erase(pending_.begin(), pending_.begin() + static_cast<std::ptrdiff_t>(consumed));
    out.levelDb = levelDb_;
    return out;
}

}  // namespace sns
