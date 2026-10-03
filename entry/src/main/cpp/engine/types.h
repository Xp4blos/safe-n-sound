#pragma once
#include <array>
#include <vector>

namespace sns {

constexpr int kSampleRate = 16000;
constexpr int kFrameSize = 512;  // 32 ms at 16 kHz
constexpr int kFingerprintSize = 29;

using Fingerprint = std::array<float, kFingerprintSize>;

enum class EventKind { Tonal = 0, Pulsed = 1 };

struct Event {
    double startSec;
    double durationSec;
    EventKind kind;
    Fingerprint fp;
};

struct EngineOutput {
    float levelDb;
    std::vector<Event> events;
};

}  // namespace sns
