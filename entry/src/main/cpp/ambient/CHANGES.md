# Safety hardening - change log

## Bug fixes
- speech.cpp: `fired_in_utt` is clamped to the current number of occurrences, so a keyword the
  recognizer revised away can no longer swallow a later real "help" (alert was silently lost).
- Built-in keyword rules ("help", "watch out", ...) now use a 1 s cooldown (was 2 s).
  Custom rules keep their own `cooldown_s`.

## Thread safety / lifetime
- Detector: every public method is serialised by a mutex (UI thread may add/remove custom
  sounds while the audio thread runs `process()`). Detector is no longer copyable.
- SpeechSession: exceptions from the app callback are swallowed; callbacks are ignored after
  destruction starts (`closed_`). `SpeechRecognizer::stop()` must join its callback thread.

## Silent-failure protection
- `Detector::stream_time_s()` - compare with wall-clock time in the app to detect a dead mic.

## Input validation
- `Config::validate()` rejects NaN, non-positive durations/dB values, bad `background_alpha`,
  absurd sample_rate / frame_size.
- `validate_sound()` rejects out-of-range refractory/min_level/frame/sample rate.
- Stored sounds: format v2 = v1 + CRC32. v1 data is still readable. Trailing bytes rejected.
- Trainer: after training, the template must recognise each of its own recordings.

## Detection
- A custom-sound match only hides built-in events that are at most 6 dB louder than the match.
  (Defensive: in tests the matcher already stops matching before this limit is reached.)

## Build / tests
- CMake: `AMBIENT_WERROR`, `AMBIENT_SANITIZE` options, stack protector, `_GLIBCXX_ASSERTIONS`.
  Removed the speech_test.cpp path fallback. CRLF -> LF in speech files and tests.
- New tests/test_safety.cpp: chunk invariance (1..50000 samples), config validation, stored-sound
  integrity (CRC, v1 compatibility, trailing bytes), noisy floor / mains hum / DC offset / loud fan /
  clipping, alarm frequency+duration boundaries, bang inside a custom window, stream clock,
  concurrent add/remove while processing.
- speech_test.cpp: regression test for the lost-"help" bug; cooldown expectations updated.

## Not done
- Repeated short chirps (low-battery beeps) are still not an alarm class.
- No HarmonyOS/N-API wrapper is included (wrap every entry point in try/catch there).
