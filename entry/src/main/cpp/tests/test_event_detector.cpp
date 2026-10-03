#include "detect_helper.h"
#include "synth.h"
#include "test_util.h"

TEST(detector_single_tone_is_one_tonal_event) {
    const auto pcm = Concat({Noise(1.0, 0.005, 3), Tone(1000, 1.0, 0.3), Silence(1.5)});
    const auto events = RunDetector(pcm, false);
    CHECK(events.size() == 1);
    if (events.size() == 1) {
        CHECK(events[0].kind == sns::EventKind::Tonal);
        CHECK_NEAR(events[0].startSec, 1.0, 0.1);
        CHECK_NEAR(events[0].durationSec, 1.0, 0.15);
    }
}

TEST(detector_beep_train_is_one_pulsed_event) {
    const auto pcm = Concat({Silence(0.5), BeepTrain(2000, 0.15, 0.15, 5, 0.3), Silence(1.5)});
    const auto events = RunDetector(pcm, false);
    CHECK(events.size() == 1);
    if (events.size() == 1) CHECK(events[0].kind == sns::EventKind::Pulsed);
}

TEST(detector_ignores_broadband_noise) {
    CHECK(RunDetector(Concat({Noise(5.0, 0.3, 11), Silence(1.0)}), true).empty());
}

TEST(detector_ignores_impulses_knocks) {
    CHECK(RunDetector(Concat({Impulses(0.5, 3.0, 0.9), Silence(1.0)}), true).empty());
}

TEST(detector_quiet_room_makes_no_events) {
    CHECK(RunDetector(Concat({Silence(10.0), Noise(10.0, 0.005, 5)}), true).empty());
}

TEST(detector_full_scale_tone_is_detected) {
    const auto events = RunDetector(Concat({Silence(0.5), Tone(1500, 1.0, 1.0), Silence(1.5)}), false);
    CHECK(events.size() == 1);
}

TEST(detector_separated_tones_are_two_events) {
    const auto pcm = Concat({Tone(1000, 0.6, 0.3), Silence(2.0), Tone(1000, 0.6, 0.3), Silence(1.5)});
    CHECK(RunDetector(pcm, false).size() == 2);
}

TEST(detector_flush_emits_unclosed_event) {
    const auto pcm = Concat({Silence(0.3), Tone(1000, 1.0, 0.3)});
    CHECK(RunDetector(pcm, false).empty());
    CHECK(RunDetector(pcm, true).size() == 1);
}
