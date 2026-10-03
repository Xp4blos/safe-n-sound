#include <algorithm>

#include "../engine/engine.h"
#include "synth.h"
#include "test_util.h"

namespace {
std::vector<sns::Event> RunChunked(const std::vector<int16_t>& pcm, size_t chunk) {
    sns::Engine engine(sns::kSampleRate);
    std::vector<sns::Event> events;
    for (size_t pos = 0; pos < pcm.size(); pos += chunk) {
        const size_t n = std::min(chunk, pcm.size() - pos);
        const auto out = engine.Process(pcm.data() + pos, n);
        events.insert(events.end(), out.events.begin(), out.events.end());
    }
    return events;
}

const std::vector<int16_t>& ToneThenSilence() {
    static const auto pcm = Concat({Silence(0.5), Tone(1000, 1.0, 0.3), Silence(2.0)});
    return pcm;
}
}  // namespace

TEST(engine_chunk_size_does_not_change_the_result) {
    const auto reference = RunChunked(ToneThenSilence(), ToneThenSilence().size());
    CHECK(reference.size() == 1);
    for (size_t chunk : {size_t{100}, size_t{1}, size_t{513}}) {
        const auto events = RunChunked(ToneThenSilence(), chunk);
        CHECK(events.size() == 1);
        if (events.size() == 1 && reference.size() == 1) {
            CHECK_NEAR(events[0].startSec, reference[0].startSec, 0.05);
            CHECK_NEAR(events[0].durationSec, reference[0].durationSec, 0.05);
        }
    }
}

TEST(engine_null_and_empty_input_is_ignored) {
    sns::Engine engine(sns::kSampleRate);
    const auto out = engine.Process(nullptr, 0);
    CHECK(out.events.empty());
    CHECK_NEAR(out.levelDb, -100.0, 1e-3);
    const int16_t one = 0;
    CHECK(engine.Process(&one, 0).events.empty());
}

TEST(engine_reports_level_of_latest_frame) {
    sns::Engine engine(sns::kSampleRate);
    const auto tone = Tone(1000, 0.5, 0.5);
    const auto out = engine.Process(tone.data(), tone.size());
    CHECK_NEAR(out.levelDb, -9.0, 1.5);
}

TEST(engine_level_persists_when_chunk_is_shorter_than_a_frame) {
    sns::Engine engine(sns::kSampleRate);
    const auto tone = Tone(1000, 0.5, 0.5);
    engine.Process(tone.data(), tone.size());
    const auto out = engine.Process(tone.data(), 10);  // no complete frame yet
    CHECK_NEAR(out.levelDb, -9.0, 1.5);
}
