# Safe'n'Sound

A HarmonyOS phone app that listens through the microphone and turns important everyday sounds
(beeps, alarms, signals, door rings) into something you can see and feel: a vibration, an on-screen
indicator and, for sounds you have named, a notification. Everything runs on the device. No cloud, no
stored audio; only compact sound fingerprints are saved.

## What it does

- **Listen tab:** start/stop listening, a pulsing microphone that follows the live sound level, an
  equaliser-style chart of the last 8 seconds, and the last detected sound.
- **History tab:** every distinct sound heard so far. Tap one to name it and turn alerts on or off.
  When a named sound is heard again the phone vibrates and shows a notification with its name.
- Every detection vibrates; only named sounds with alerts on notify (at most once per 10 s per sound).
- Listening works in the foreground only and stops when the app leaves the screen.
- The phone's own vibration is picked up by its microphone, so events that start while it vibrates (plus a
  short tail) are ignored; a hum that is already present when listening starts is treated as background.

Not included yet: speech recognition, knock and loud-sound categories, background listening.

## Architecture

```
AudioCapturer (ArkTS) --PCM--> NAPI (libsafensound.so) --> C++ engine
                                                          level, events + 29-float fingerprints
ArkTS: SoundPipeline -> SoundCatalog (match, name, cooldown) -> SoundStore (Preferences JSON)
       AlertService (vibrator, notifications)    UI: Listen / History tabs
```

- `entry/src/main/cpp/engine` - dependency-free C++ DSP: FFT frame analysis, adaptive-noise-floor event
  detector (tonal and pulsed sounds), fingerprint and similarity matcher (`kMatchThreshold = 0.80`).
- `entry/src/main/cpp/napi` - thin NAPI bridge (`createEngine`, `destroyEngine`, `process`,
  `matchFingerprint`); typings in `entry/src/main/cpp/types/libsafensound`.
- `entry/src/main/ets` - `model/` (pure logic), `services/` (audio, alerts, storage), `components/`, `pages/`.
- Design and plan: `docs/superpowers/specs/` and `docs/superpowers/plans/`.

Target: HarmonyOS phone, compatible SDK API 20, target SDK API 24.

## Setup from a clean checkout

1. Install DevEco Studio 6.1.x with the HarmonyOS SDK and put its tools on `PATH` (`hvigorw`, `ohpm`,
   `hdc`, DevEco's `node`). For the host C++ tests also install Visual Studio 2022 Build Tools (MSVC).
2. Copy `build-profile.example.json5` to `build-profile.json5` and set up signing (see the comments in
   that file). `build-profile.json5` holds personal signing secrets and is git-ignored on purpose.
3. `ohpm install --all`

## Build, test, install

```bash
# C++ engine tests on the PC (MSVC + the SDK's cmake/ninja; set DEVECO_NATIVE if the SDK is elsewhere)
scripts\host-tests.cmd

# ArkTS unit tests (hvigor + hypium)
bash scripts/arkts-tests.sh

# Build the .hap -> entry/build/default/outputs/default/entry-default-signed.hap
hvigorw assembleHap --mode module -p product=default -p module=entry@default --no-daemon

# Install and launch on a connected device or emulator
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc shell aa start -a EntryAbility -b com.example.safe_n_sound
```

`devecocli build` is the project's preferred build command, but `devecocli` needs Node 22 or newer and the
DevEco-bundled Node is 18, so `hvigorw` is called directly here. Switch to `devecocli build` once Node 22+ is
available.

Engine check on a WAV file (16-bit mono 16 kHz): `build-host\tests\wav_cli.exe file.wav` after running the
host tests. To tune detection on real audio set `LOG_EVENT_FINGERPRINTS` to `true` in
`entry/src/main/ets/services/AudioService.ets`, collect the `EVT` log lines and run
`build-host\tests\fp_cli.exe lines.txt` to see each event's key fields and the pairwise similarity matrix.

## Logs

App and native logs use hilog domain `0x3201` (domain `0x0000` is hidden on some devices):
`hdc shell "hilog -x" | grep -a 3201`.
