// Characterisation test on a real recording: three plays of the same alarm sound captured by the microphone of the
// test phone (16 kHz mono, plain 44-byte WAV header), in a noisy room, including the phone's own vibration.
// Run from the repository root (scripts/host-tests.cmd does).
#include <algorithm>
#include <cstdio>
#include <cstring>

#include "../profile/types.h"
#include "../wrapper/sound_engine.h"
#include "test_util.h"

namespace {
bool LoadWav(const char* path, std::vector<int16_t>* pcm) {
    FILE* f = std::fopen(path, "rb");
    if (!f) return false;
    std::vector<unsigned char> bytes;
    unsigned char buf[8192];
    size_t n;
    while ((n = std::fread(buf, 1, sizeof buf, f)) > 0) bytes.insert(bytes.end(), buf, buf + n);
    std::fclose(f);
    if (bytes.size() <= 44 || std::memcmp(bytes.data(), "RIFF", 4) != 0) return false;
    pcm->resize((bytes.size() - 44) / 2);
    std::memcpy(pcm->data(), bytes.data() + 44, pcm->size() * 2);
    return true;
}
}  // namespace

TEST(real_phone_recording_learns_the_first_alarm_and_recognises_the_repeats) {
    std::vector<int16_t> pcm;
    const bool loaded = LoadWav("entry/src/main/cpp/tests/data/phone_alarm_3x.wav", &pcm);
    CHECK(loaded);
    if (!loaded) return;

    sns::SoundEngine engine(sns::kSampleRate);
    double learnAt = -1.0, firstAlarm = 0.0;
    bool learned = false;
    int alarms = 0, repeats = 0;
    for (size_t pos = 0; pos < pcm.size(); pos += 480) {
        const size_t len = std::min<size_t>(480, pcm.size() - pos);
        const double now = static_cast<double>(pos + len) / sns::kSampleRate;
        const auto out = engine.Process(pcm.data() + pos, len);
        for (const auto& e : out.events) {
            if (e.type == "alarm") {
                ++alarms;
                if (learnAt < 0 && !learned) {
                    firstAlarm = e.timeSec;
                    learnAt = now + 3.7;  // the app learns 3.7 s after the first alarm event
                }
            } else if (e.type == "custom" && e.label == "snd-1") {
                ++repeats;
            }
        }
        if (learnAt >= 0 && now >= learnAt) {
            CHECK(engine.LearnFromRing("snd-1", firstAlarm).ok);
            learned = true;
            learnAt = -1.0;
        }
    }
    CHECK(alarms >= 3);
    CHECK(learned);
    CHECK(repeats == 2);  // plays 2 and 3 of the recording
}
