#include "../engine/matcher.h"
#include "detect_helper.h"
#include "synth.h"
#include "test_util.h"

namespace {
// Real detector output for a sound followed by silence so the event closes.
sns::Fingerprint FingerprintOf(const std::vector<int16_t>& sound) {
    const auto events = RunDetector(Concat({Silence(0.5), sound, Silence(1.5)}), false);
    CHECK(events.size() == 1);
    return events.empty() ? sns::Fingerprint{} : events[0].fp;
}
}  // namespace

// Tuned values: same sound with +0.5% pitch and half amplitude scores ~1.0; different pitch scores ~0.3;
// steady tone vs beep train at the same pitch scores ~0.75 (< kMatchThreshold 0.80).
TEST(matcher_same_sound_with_small_variation_matches) {
    const auto a = FingerprintOf(Tone(1000, 1.0, 0.3));
    const auto b = FingerprintOf(Tone(1005, 1.0, 0.15));
    CHECK(sns::Similarity(a, b) >= 0.90f);
    const auto m = sns::Match(b, {a});
    CHECK(m.index == 0);
}

TEST(matcher_different_pitch_beeps_do_not_match) {
    const auto a = FingerprintOf(BeepTrain(1000, 0.15, 0.15, 5, 0.3));
    const auto b = FingerprintOf(BeepTrain(2500, 0.15, 0.15, 5, 0.3));
    CHECK(sns::Similarity(a, b) < 0.50f);
}

TEST(matcher_steady_tone_differs_from_beep_train_same_pitch) {
    const auto steady = FingerprintOf(Tone(1000, 1.5, 0.3));
    const auto beeps = FingerprintOf(BeepTrain(1000, 0.15, 0.15, 5, 0.3));
    CHECK(sns::Similarity(steady, beeps) < 0.80f);
}

TEST(matcher_empty_saved_returns_no_match) {
    const auto a = FingerprintOf(Tone(1000, 1.0, 0.3));
    const auto m = sns::Match(a, {});
    CHECK(m.index == -1);
}

TEST(matcher_picks_correct_sound_among_three) {
    const auto doorbell = FingerprintOf(BeepTrain(800, 0.4, 0.2, 3, 0.3));
    const auto alarm = FingerprintOf(BeepTrain(3000, 0.15, 0.15, 6, 0.3));
    const auto tone = FingerprintOf(Tone(1500, 1.5, 0.3));
    const auto probe = FingerprintOf(BeepTrain(3010, 0.15, 0.15, 6, 0.1));
    const auto m = sns::Match(probe, {doorbell, alarm, tone});
    CHECK(m.index == 1);
    CHECK(m.score >= sns::kMatchThreshold);
}

TEST(matcher_similarity_with_itself_is_one) {
    const auto a = FingerprintOf(BeepTrain(2000, 0.15, 0.15, 5, 0.3));
    CHECK_NEAR(sns::Similarity(a, a), 1.0, 1e-4);
}
