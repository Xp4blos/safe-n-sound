# AI Workflow

This project uses AI-assisted development. Keep this document current and public-safe. Do not include credentials, tokens, personal data, private endpoints, or confidential prompts.

## Tools used

| Model, agent, MCP server, or Agent Skill | Version or source | Role in the project |
| --- | --- | --- |
| Claude Sonnet 5.5 (`claude-sonnet-5-5`) in Claude Code | Anthropic | Design dialogue, specs and plans, C++ wrapper and profile code, NAPI bridge, ArkTS app, tests, debugging, documentation |
| Fresh-context reviewer subagent (most capable model tier available in Claude Code) | Anthropic | One whole-branch code review of the first version |
| Agent Skill `superpowers:brainstorming` | superpowers plugin | Scoping and design approval before code |
| Agent Skill `superpowers:writing-plans` | superpowers plugin | Written implementation plans from the approved specs |
| Agent Skill `superpowers:executing-plans` | superpowers plugin | Task-by-task execution with a progress ledger |
| Agent Skill `superpowers:test-driven-development` | superpowers plugin | Red-green discipline |
| Hackathon skills (`ohos-app-dev`, ArkTS knowledge base) | hackyeah2026-challenge repository | Build and validation guidance, ArkTS reference |
| AI assistance used by a teammate for the ambient C++ engine | see `entry/src/main/cpp/ambient/README.md` and the teammate's repository | Prior code, included in this project |

No MCP server was used for the product work.

## Prior code and open-source disclosure

- `entry/src/main/cpp/ambient/` is prior code written by a member of the team (https://github.com/Xp4blos/hack-yeah-2026, commit `512e41d`), vendored unchanged except that `speech.*` was left out. It is the team's own work; the repository deliberately has no license file.
- The first version of this project's own C++ detector and matcher (written with Claude in this session) was replaced by that engine; only its FFT frame analyzer is kept (`entry/src/main/cpp/profile`).
- Third-party libraries: `@ohos/hypium` and `@ohos/hamock` (test tools, installed by `ohpm`), the HarmonyOS SDK and DevEco toolchain. No other open-source code is bundled.

## Important prompts and instructions

- `AGENTS.md` - repository-wide hackathon constraints and working agreement (the user directs product, UI and scope decisions).
- Project brief given by the user: an app for deaf and hard-of-hearing people that detects beeps, alarms, signals and door rings, remembers specific sounds, keeps a history, lets the user name a sound to be notified when it is heard again; core logic in C++, UI in ArkTS, using microphone, vibration and notifications.
- Functional specification F1-F9 given by the user (listening, live view, detection and fingerprint description, memory, "I know this sound" prompt, teach flow, alerts, history, my sounds) and the instruction to switch to the teammate's engine, make the microphone icon a button and add a "Teach a sound" button.
- Decisions the user confirmed: foreground-only listening, calm blue palette, pulsing mic with an 8-second live view, vibrate on detection and notify for named sounds, build with `hvigorw` while `devecocli` needed Node 22.

## AI-assisted work log

| Date | Tool/model | Request or task | Generated or changed | Human review and validation |
| --- | --- | --- | --- | --- |
| 2026-10-03 | Claude Sonnet 5.5 | Brainstorm scope, spec, plan (first engine) | specs and plans under `docs/superpowers/` | User answered scoping questions and approved the spec and plan |
| 2026-10-03 | Claude Sonnet 5.5 | First C++ engine, NAPI bridge, ArkTS app and UI | engine, bridge, services, tabs | Host and ArkTS unit tests, `.hap` build, screenshots on a phone |
| 2026-10-03 | Fresh-context reviewer subagent | Whole-branch review | findings; fixes in the following commit | Critical/Important findings fixed test-first where testable |
| 2026-10-03 | Claude Sonnet 5.5 | Phone test and fixes | stop/error race, noise floor, vibration feedback, chart redraw | Found by running on a PLR-AL00 phone; verified on the phone |
| 2026-10-03 | Claude Sonnet 5.5 | Check the teammate's engine, then integrate it | vendored engine, `SoundEngine` wrapper, `SoundProfile`, new NAPI API | Built with warnings as errors; the engine's 7 test targets plus 12 wrapper and 6 profile tests pass; compared on hum, motor and beep files |
| 2026-10-03 | Claude Sonnet 5.5 | Functional spec F1-F9 in the app | catalog, pipeline, services, Listen/History/My sounds, teach, prompt and detail dialogs | 36 ArkTS unit tests; `.hap` builds; lint 0 errors; start, spectrum, teach recording and stop exercised on the phone |

| 2026-10-03 | Claude Sonnet 5.5 | Modern UI, signed .hap, GitHub repo and release, demo video | restyled components, `scripts/make-signed-hap.sh`, release v1.0.0, `dist/safe-n-sound-demo.mp4` | Video recorded by driving the phone with `hdc`/`uitest` while a real alarm was played from a PC speaker; fixes found while recording |

## Workflow

### Ideation and architecture

The user supplied the product brief and later a functional specification. The model asked scoping questions, proposed an architecture (capture in ArkTS, analysis in dependency-free C++ behind a thin NAPI bridge so the DSP is testable on a PC), and wrote a spec and a plan for the user to approve. After phone testing showed that the first engine was fragile on real audio, the user supplied a teammate's engine; the model compared both on generated hum, motor, beep and long-tone files, vendored the teammate's engine, and wrapped it.

### Implementation

Work followed written plans, task by task and test first, with small commits on feature branches. Platform APIs were checked against the SDK's own `.d.ts` declarations rather than written from memory. Pure logic (catalog, pipeline, spectrum history) is separated from the platform behind small ports so it is unit tested with fakes.

### Testing and debugging

- C++: `scripts\host-tests.cmd` (MSVC + SDK cmake/ninja): our tests plus the teammate's tests and `wav_cli` end-to-end checks.
- ArkTS: `scripts/arkts-tests.sh` (hvigor + hypium), 36 tests.
- Build: `hvigorw assembleHap`; lint: `devecocli check lint` (Node 22), 0 errors, 5 style warnings.
- Device: physical Huawei phone (PLR-AL00, API 26): permissions, start/stop, Home button, live spectrum, teach recording and its on-screen result.

## Bugs found during phone testing

- After tapping Stop the Listen tab showed an error: the capturer's own `STOPPED` event was treated as a failure. Fixed by ignoring events from an already released capturer.
- A fixed -60 dB noise floor made room hum one endless event; the phone's own vibration was heard by its microphone and re-detected as new sounds. The first engine was replaced by the teammate's engine, which restricts alarms to 800-4500 Hz and ignores steady background.
- The level chart did not redraw because the list keys ignored the values.
- hilog domain `0x0000` produced no output on the test phone; domain `0x3201` is used.
- Recording the demo showed that the dialog buttons (Cancel, Save, Name it) did not close their dialogs: the framework does not set the `controller` of a custom dialog built inside a method (it was `undefined`). Fixed by passing an explicit `onClose` callback to each dialog.
- While the demo was recorded with a fast screenshot loop on the phone, repeats of the alarm were no longer recognised, although the same sound was recognised without that load; the audio stream is disturbed by heavy load on the phone. The same recording replayed on the PC gave the same result as the phone, which is how this was separated from a threshold problem. The capture was made lighter (half-size screenshots, no UI polling while a sound is analysed).
- The engine's default similarity threshold (0.8) missed quieter repeats on real audio; it is 0.6 for learned sounds, checked on a real recording and on host tests that a different pitch is still not matched.
- The "Doorbell detected" card was below the fold of the Listen tab, so it was moved to the top.
- Teach a sound on the phone: two takes of the same sound were rejected as "recordings do not match each other" (similarity 0.08). The recorded takes showed why: the trainer cuts a sound out of a recording by loudness alone, and in a noisy room random noise crosses its threshold, so both cuts were almost the whole 6 s. Takes are now reduced to their clearest tonal stretch (600-6000 Hz, tonality 25+) before training; the two real takes are a fixture with a unit test. The sound description threshold is also relative to the loudest frame.
- The "Doorbell detected" card, once at the top of the page, pushed the Stop and Teach buttons off screen for a minute; it is now an overlay that does not move anything and disappears when tapped.
- The alert card did not redraw when a second alert arrived: three screenshots in a row showed the same "Doorbell detected 23:17:59" card while the log recorded alerts for another sound. A `@Builder` with a parameter does not update; the card is now its own component, and the test also checks that the time on the card is fresh (an earlier green result was a false match on the stale card).
- The multi-take trainer sets its own recognition threshold of 0.7-0.9; it is capped at 0.6 like single recordings, because it missed a repeat that was only a few dB quieter.
- The PC-speaker test rig is not stable: the level of the same sound at the phone varied between -18 and -28 dB from run to run (and even fell when the PC volume was raised), and when the sound is less than about 12 dB above the room noise the engine rightly rejects takes and misses beeps. The best full run (both sounds taught from two real takes each, each recognised under its own name with a fresh card, My sounds listing both) failed only the first immediate Doorbell check; the later runs at weaker levels failed more steps for that reason.

## Unsuccessful approaches

- The SDK's `clang++` cannot build host tests (no Windows C++ standard library); MSVC Build Tools are used.
- `devecocli` needed Node 22+ and only Node 18 was installed at first; `hvigorw` was used directly, then Node 22 was added for `devecocli`.
- Audio from the PC never reached the phone's microphone while headphones were plugged in, so beep detection with a real sound was verified only on generated audio (see limitations).

## Known limitations

- Verified on the phone with a real alarm sound (PC speaker): detection, the "Unknown sound" entry, recognition of the repeat, the "I've heard this sound before" prompt, naming, the "Doorbell detected" card and the count of 3 in History (see the demo video and the logs). Not confirmed visually: the vibration pattern (cannot be filmed) and the system notification (published without errors, but not seen). Not exercised: a clean single run in which every Teach step passes (the best run missed one step, see above), restart persistence of named sounds (data survived reinstalls in testing but was not checked after a plain restart), the denied-permission Settings path, and a second, different sound that must not be confused with the first (covered only by a host test with generated audio).
- Detection thresholds come from the teammate's engine and were checked on generated and few real sounds; sounds shorter than 0.4 s or outside 800-4500 Hz are not detected automatically (Teach covers them).
- Foreground listening only; keyword detection and knock/loud-sound classes are not in the app.
- English UI only.

## Lessons learned

- Run the real audio path on the phone early: synthetic tests passed while real rooms exposed the noise-floor and vibration problems.
- Keep the engine free of OS dependencies: it made the DSP testable on the PC before any device work.
- Check the toolchain (Node version, host compiler) at the start.

## AI feature disclosure

Not applicable as a model: the app uses classical signal processing (FFT, thresholds, spectrogram templates, similarity) on the device and contains no machine-learning model or AI service.

### Complex signals (several notes, pitches, spacings and dynamics)
- Asked by the user to try more complex signals. Added `tests/complex_sounds.h` and `tools/complex_eval.cpp` (five synthetic signals mixed into real phone room noise) and WAV export for playback.
- Result in simulation: all five signals are detected, taught, recognised (3/3 at 10-25 dB) and not confused. Result on the phone with a PC speaker (audio captured with `DEBUG_CAPTURE_AUDIO`, then replayed on the PC): only the tremolo tone could be taught; chime 1 was not even reported as an alarm, and the trainer rejected the pairs of takes of chime, siren, arpeggio and the irregular pattern (similarity -0.00, 0.08, 0.58, 0.60 against 0.6).
- Tried a lower gate tonality threshold (18, 14, 10): no improvement, so the value stays 25. The cause is in how the team's trainer compares takes of multi-note, reverberated sounds, not in level (the plays were 15-28 dB above the room noise). Not fixed; recorded as a limitation.
- Lesson: a synthetic test with recorded noise is not a substitute for a real speaker-and-room test; both are kept.
