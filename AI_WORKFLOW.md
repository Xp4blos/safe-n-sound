# AI Workflow

This project uses AI-assisted development. Keep this document current and public-safe. Do not include credentials, tokens, personal data, private endpoints, or confidential prompts.

## Tools used

| Model, agent, MCP server, or Agent Skill | Version or source | Role in the project |
| --- | --- | --- |
| Claude Sonnet 5.5 (`claude-sonnet-5-5`) in Claude Code | Anthropic | Design dialogue, spec and plan writing, C++ engine, NAPI bridge, ArkTS app, tests, debugging, documentation |
| Agent Skill `superpowers:brainstorming` | superpowers plugin | Scoping and design approval before any code |
| Agent Skill `superpowers:writing-plans` | superpowers plugin | Written implementation plan from the approved spec |
| Agent Skill `superpowers:executing-plans` | superpowers plugin | Inline task-by-task execution with a progress ledger |
| Agent Skill `superpowers:test-driven-development` | superpowers plugin | Red-green discipline for every task |
| Hackathon skills (`ohos-app-dev`, ArkTS knowledge base) | hackyeah2026-challenge repository | Build/validation guidance and ArkTS reference |

No MCP server was used for the product work.

## Important prompts and instructions

- `AGENTS.md` - repository-wide hackathon constraints and working agreement (the user directs product, UI and scope decisions; ask before deciding them).
- Project brief given by the user: an app for people who are hard of hearing that detects beeps, alarms, signals and door rings by sound amplitude, frequency and dynamics, remembers specific sounds, keeps a history, and lets the user name a sound to be notified when it is heard again. Core logic in C++, UI in ArkTS, using microphone, vibration and notifications.
- Decisions the user confirmed during design: C++ engine written from scratch, fingerprint-based memory, foreground-only listening, two tabs (Listen, History), vibrate on any detection and notify only for named sounds, calm blue palette, pulsing microphone with an 8-second equaliser-style level chart.

## AI-assisted work log

| Date | Tool/model | Request or task | Generated or changed | Human review and validation |
| --- | --- | --- | --- | --- |
| 2026-10-03 | Claude Sonnet 5.5 | Brainstorm scope and approve a design | `docs/superpowers/specs/2026-10-03-sound-detection-history-design.md` | User answered the scoping questions and approved the spec |
| 2026-10-03 | Claude Sonnet 5.5 | Write implementation plan | `docs/superpowers/plans/2026-10-03-sound-detection-history.md` | User reviewed the plan and chose inline execution |
| 2026-10-03 | Claude Sonnet 5.5 | C++ engine (FFT analysis, event detector, fingerprint, matcher, facade, `wav_cli`) | `entry/src/main/cpp/engine`, `tools`, `tests` | 25 host unit tests on synthetic audio, written failing first; `wav_cli` run on a generated tone |
| 2026-10-03 | Claude Sonnet 5.5 | NAPI bridge and native build wiring | `entry/src/main/cpp/napi`, `CMakeLists.txt`, `types/` | `.hap` built with `libsafensound.so`; synthetic-tone smoke run on a physical phone returned one tonal event |
| 2026-10-03 | Claude Sonnet 5.5 | ArkTS model, services, UI | `entry/src/main/ets`, resources, manifest | 26 ArkTS unit tests; `.hap` builds; Listen and History tabs screenshotted on the phone |
| 2026-10-03 | Fresh-context reviewer subagent (most capable model tier) | Whole-branch review | Review findings; fixes in the following commit | Reviewer read the full diff; each Critical/Important finding fixed test-first where testable |
| 2026-10-03 | Claude Sonnet 5.5 | On-phone test and fixes | Detector warm-up and floor raise, vibration-feedback guard, `AudioService` stop/cancel/permission fixes, chart key fix, `fp_cli` | 28 C++ and 29 ArkTS tests; start, stop, Home button and beep-detection paths exercised on the phone |

## Workflow

### Ideation and architecture

The user supplied the product brief. The model asked scoping questions one at a time (engine origin, how sounds are remembered, listening mode, UI layout, alert rules) and proposed an approach: capture audio in ArkTS and analyse it in a dependency-free C++ engine behind a thin NAPI bridge, so the DSP is testable on a PC. The user approved the design, then the written spec, then the plan.

### Implementation

Work followed the plan task by task on the `feature/sound-detection` branch, each task test-first with small commits. Platform APIs (Preferences, vibrator, notifications, AudioCapturer, permissions) were checked against the SDK's own `.d.ts` declarations rather than written from memory.

### Testing and debugging

- C++: `scripts\host-tests.cmd` (MSVC + SDK cmake/ninja), 28 tests.
- ArkTS: `scripts/arkts-tests.sh` (hvigor + hypium), 29 tests.
- Build: `hvigorw assembleHap` succeeds.
- Device: installed on a physical Huawei phone (PLR-AL00, API 26). A synthetic 1 kHz tone passed through the native library produced one tonal event; Listen and History screens were captured by screenshot.

## Unsuccessful approaches

- The SDK's `clang++` cannot build host tests (no Windows C++ standard library); MSVC Build Tools are used instead.
- `devecocli` requires Node 22+ and only Node 18 is installed, so `devecocli build`, `docs search` and `check lint` could not run; `hvigorw` was used directly with the user's approval, and the bundled ArkTS linter also failed under Node 18.
- hilog domain `0x0000` produced no output on the test phone; domain `0x3201` is used.
- First device run: after tapping Stop the Listen tab showed an error because the capturer's own `STOPPED` event was treated as a failure; fixed by ignoring events from a capturer that was already released.
- First device run: a fixed -60 dB noise floor made room hum one endless event, and the phone's own vibration was heard by its microphone and re-detected as new sounds; fixed with a warm-up calibration, a floor raise after a 10 s event and a vibration-feedback guard.
- Audio played from the PC (`[console]::Beep` and a WAV through the PC speakers) never produced a 2 kHz peak on the phone, so beep detection and same-sound matching were not demonstrated on real beeps.

## Known limitations

- Exercised on the phone by the agent: both permission dialogs, start, live chart and pulsing mic, stop, Home button, History list. Not exercised: naming dialog, notification for a named sound, matching of a repeated real beep or doorbell, the denied-permission retry path, and cancelling a start by backgrounding mid-dialog.
- Detection thresholds (`kTonalityMin`, `kActiveMarginDb`, `kMatchThreshold`) were tuned on synthetic audio only; real doorbells, smoke alarms and noisy rooms are untested.
- Lint was not run (tool unavailable).
- Foreground listening only; no speech, knock or loud-sound classes.
- English UI only.

## Lessons learned

- Keep the engine free of OS dependencies: it made the DSP fully testable on the PC before any device work.
- Check the toolchain (Node version, host compiler) at the start; two tools in the project instructions could not run here.

## AI feature disclosure

Not applicable. The app uses classical signal processing (FFT, thresholds, fingerprint similarity) on the device; it contains no machine-learning model or AI service.
