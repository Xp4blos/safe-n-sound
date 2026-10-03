#include "sound_engine.h"

#include <algorithm>
#include <cmath>
#include <exception>

#include "types.h"

namespace sns {

namespace {
constexpr float kBandFloorDb = -62.0f;  // quiet room noise stays dim ...
constexpr float kBandCeilDb = -12.0f;   // ... and a clear sound lights its band fully

ambient::Config MakeConfig(int sampleRate) {
    ambient::Config c;
    c.sample_rate = sampleRate;
    return c;
}

std::vector<ambient::Recording> AsRecordings(const std::vector<std::vector<int16_t>>& takes) {
    std::vector<ambient::Recording> out;
    for (const auto& t : takes) out.push_back({t.data(), t.size()});
    return out;
}
}  // namespace

SoundEngine::SoundEngine(int sampleRate)
    : sampleRate_(sampleRate),
      cfg_(MakeConfig(sampleRate)),
      detector_(cfg_),
      analyzer_(sampleRate) {}

void SoundEngine::AppendRing(const int16_t* pcm, size_t n) {
    ring_.insert(ring_.end(), pcm, pcm + n);
    total_ += n;
    const size_t cap = static_cast<size_t>(kRingSeconds * sampleRate_);
    if (ring_.size() > cap) {
        const size_t drop = ring_.size() - cap;
        ring_.erase(ring_.begin(), ring_.begin() + static_cast<std::ptrdiff_t>(drop));
        ringStart_ += drop;
    }
}

void SoundEngine::UpdateLiveBands(const int16_t* pcm, size_t n) {
    bandPending_.insert(bandPending_.end(), pcm, pcm + n);
    std::array<float, kLiveBands> peak{};
    bool any = false;
    size_t read = 0;
    while (bandPending_.size() - read >= static_cast<size_t>(kFrameSize)) {
        const FrameFeatures f = analyzer_.Analyze(bandPending_.data() + read);
        levelDb_ = f.levelDb;
        for (int i = 0; i < kLiveBands; ++i) {
            const float bandDb = f.levelDb + 10.0f * std::log10(f.bandEnergy[i] + 1e-6f);
            const float v = std::min(1.0f, std::max(0.0f, (bandDb - kBandFloorDb) / (kBandCeilDb - kBandFloorDb)));
            peak[i] = std::max(peak[i], v);
        }
        any = true;
        read += kFrameSize;
    }
    bandPending_.erase(bandPending_.begin(), bandPending_.begin() + static_cast<std::ptrdiff_t>(read));
    if (any) bands_ = peak;
}

ProcessResult SoundEngine::Process(const int16_t* pcm, size_t sampleCount) {
    ProcessResult out;
    out.levelDb = levelDb_;
    out.bands = bands_;
    if (pcm == nullptr || sampleCount == 0) return out;

    AppendRing(pcm, sampleCount);
    UpdateLiveBands(pcm, sampleCount);
    out.levelDb = levelDb_;
    out.bands = bands_;

    try {
        for (const auto& e : detector_.process(pcm, sampleCount)) {
            EngineEvent ev;
            if (e.type == ambient::EventType::Alarm) {
                ev.type = "alarm";
                ev.startSec = e.time_s;
            } else if (e.type == ambient::EventType::Custom) {
                ev.type = "custom";
                ev.startSec = e.start_s;
                ev.label = e.label;
            } else {
                continue;  // knocks and loud sounds are not surfaced (see the design spec)
            }
            ev.timeSec = e.time_s;
            ev.confidence = e.confidence;
            ev.freqHz = e.freq_hz;
            ev.levelDb = e.level_db;
            out.events.push_back(std::move(ev));
        }
    } catch (const std::exception&) {
        // A detector failure must not take the app down; the next chunk starts clean.
    }
    return out;
}

LearnResult SoundEngine::Train(const std::string& label, const std::vector<ambient::Recording>& recordings,
                               const SoundProfile& profile, bool registerSound) {
    LearnResult r;
    try {
        ambient::TrainResult tr = ambient::train_custom_sound(cfg_, label, recordings);
        if (registerSound) detector_.add_custom_sound(tr.sound);
        r.templateBytes = ambient::serialize(tr.sound);
        r.consistency = tr.consistency;
        r.profile = profile;
        r.ok = true;
    } catch (const std::exception& e) {
        r.message = e.what();
    }
    return r;
}

LearnResult SoundEngine::LearnFromRing(const std::string& label, double eventTimeSec) {
    const uint64_t want1 = static_cast<uint64_t>(std::max(0.0, (eventTimeSec + kLearnAfterSec) * sampleRate_));
    if (want1 > total_) {
        LearnResult r;
        r.message = "Not enough audio after the sound yet.";
        return r;
    }
    const uint64_t want0 = static_cast<uint64_t>(std::max(0.0, (eventTimeSec - kLearnBeforeSec) * sampleRate_));
    const uint64_t from = std::max(want0, ringStart_);
    if (from >= want1) {
        LearnResult r;
        r.message = "The sound is no longer in memory.";
        return r;
    }
    const std::vector<int16_t> window(ring_.begin() + static_cast<std::ptrdiff_t>(from - ringStart_),
                                      ring_.begin() + static_cast<std::ptrdiff_t>(want1 - ringStart_));
    const SoundProfile profile = DescribeSound(window.data(), window.size(), sampleRate_);
    return Train(label, {{window.data(), window.size()}}, profile, true);
}

LearnResult SoundEngine::TrainFromTakes(const std::string& label, const std::vector<std::vector<int16_t>>& takes) {
    if (takes.empty()) {
        LearnResult r;
        r.message = "Record at least one take.";
        return r;
    }
    const SoundProfile profile = DescribeSound(takes[0].data(), takes[0].size(), sampleRate_);
    return Train(label, AsRecordings(takes), profile, true);
}

LearnResult SoundEngine::CheckTake(const std::vector<int16_t>& take) {
    const SoundProfile profile = DescribeSound(take.data(), take.size(), sampleRate_);
    return Train("take-check", {{take.data(), take.size()}}, profile, false);
}

bool SoundEngine::AddSound(const std::vector<uint8_t>& bytes, std::string* error) {
    try {
        const ambient::CustomSound s = ambient::deserialize_sound(bytes.data(), bytes.size());
        detector_.add_custom_sound(s);
        return true;
    } catch (const std::exception& e) {
        if (error != nullptr) *error = e.what();
        return false;
    }
}

bool SoundEngine::RemoveSound(const std::string& label) {
    return detector_.remove_custom_sound(label);
}

}  // namespace sns
