# Safe'n'Sound

A HarmonyOS phone app for deaf and hard-of-hearing people. The phone listens to its surroundings, detects
signal sounds (beeps, buzzers, alarms, chimes), remembers them, lets you name them, and alerts you with
vibration and a notification when a named sound is heard again. Everything runs on the device: no cloud,
no stored audio. Only compact sound fingerprints (feature numbers) are saved.

Core loop: **detect -> remember -> recognise repeat -> offer to name -> alert on named sound.**
The app never relies on audio feedback: every state is visible on screen and every alert vibrates.

## Features

- **Listen tab:** tap the microphone (or the Start/Stop button) to listen. An 8-second live spectrum
  (frequency bars over time) moves with the room sound and highlights the moments the phone reacted to.
  A card shows the last detected sound; a large card appears when a named sound is heard.
- **Remembering sounds:** a new tonal signal becomes an "Unknown sound" in History; the phone learns its
  fingerprint from the audio around it (held in memory only). Hearing it again counts it on the same entry.
- **"I've heard this sound before":** on the 2nd occurrence of an unnamed sound you are asked to name it
  (Name it / Not now / Don't ask again), at most once per 10 minutes per sound.
- **Teach a sound:** record 2-3 takes of a sound on purpose, see on screen whether each take was captured,
  name it. If the takes differ too much you are told to repeat them.
- **Alerts:** a named sound vibrates (3 long pulses), posts the notification "<Name> detected" with the
  time and shows a card; 15 s cooldown per sound; each sound has an alert switch. Unknown sounds give one
  short vibration.
- **History / My sounds:** every sound with count, last time and a small pattern chart; details in plain
  words (for example "High-pitched, 3 beeps per second, about 2.1 s long"), rename, alert switch, delete.
- Data survives restarts. Room hum and the phone's own vibration are not detected as sounds.

## Platform features used

Audio capture (`AudioCapturer`, 16 kHz mono) with a runtime microphone permission and privacy text,
vibrator, notifications (`notificationManager`), local storage (`Preferences`), NAPI (ArkTS <-> C++),
`@kit.AbilityKit` lifecycle (listening stops when the app leaves the foreground).

## Architecture

```
AudioCapturer (ArkTS) --PCM--> NAPI (libsafensound.so) --> SoundEngine (C++)
                                  ambient::Detector (alarm + learned/taught sounds), ring buffer,
                                  16-band live spectrum, SoundProfile, learn/train
ArkTS: SoundPipeline -> SoundCatalog (occurrences, naming, cooldown, prompt rules) -> SoundStore (Preferences)
       AlertService (vibrator, notifications)        UI: Listen / History / My sounds, dialogs
```

- `entry/src/main/cpp/ambient` - the team's sound engine (prior code, see below): FFT, alarm detector,
  custom-sound spectrogram templates, trainer.
- `entry/src/main/cpp/wrapper` - `SoundEngine`: ring buffer (last 10 s, memory only), live spectrum, learning
  from a detected sound, teaching from takes, restoring stored sounds.
- `entry/src/main/cpp/profile` - FFT frame analysis and `SoundProfile` (pitch, duration, repetition, modulation,
  envelope) used for the plain-words description.
- `entry/src/main/cpp/napi` - thin NAPI bridge; typings in `entry/src/main/cpp/types/libsafensound`.
- `entry/src/main/ets` - `model/` (pure logic), `services/` (audio, pipeline, alerts, storage), `components/`, `pages/`.
- Data flow: an `alarm` event is held for 3.7 s; if a stored sound explains it (a `custom` event) it is counted,
  otherwise a new unknown sound is created and its template learned from the ring buffer. Only templates and
  profile numbers are stored (as base64 in Preferences JSON); raw audio never leaves memory.
- Design and plans: `docs/superpowers/specs/` and `docs/superpowers/plans/`.

## Required tools

| Tool | Version used | Needed for |
| --- | --- | --- |
| DevEco Studio | 6.1.1.280 | HarmonyOS SDK, `hvigorw`, `ohpm`, `hdc`, emulator |
| HarmonyOS SDK | target 6.1.1(24), compatible 6.0.0(20) (API 20 minimum) | building the app |
| Node.js | 22 or newer | `devecocli` (build, lint); DevEco's bundled Node 18 runs `hvigorw` |
| Visual Studio 2022 Build Tools (MSVC) | 17.x | C++ tests on the PC (optional) |

## Setup from a clean checkout

1. Install the tools above and put DevEco's `tools\hvigor\bin`, `tools\ohpm\bin` and the SDK's
   `openharmony\toolchains` (`hdc`) on `PATH`.
2. `git clone https://github.com/Xp4blos/safe-n-sound.git && cd safe-n-sound && ohpm install --all`
3. Signing: `build-profile.json5` is committed with an empty `signingConfigs`, so a fresh clone builds an
   **unsigned** `.hap` (`entry-default-unsigned.hap`). To run on a device or emulator you need a **signed**
   build: open the project in DevEco Studio, choose File > Project Structure > Signing Configs >
   "Automatically generate signature" (device or emulator connected, Huawei ID signed in), then build again.
   DevEco writes your personal signing data into `build-profile.json5`. Keep it out of commits with
   `git update-index --skip-worktree build-profile.json5`.

## Build, test, install, run

```bash
# C++ tests on the PC (MSVC + the SDK's cmake/ninja; set DEVECO_NATIVE if the SDK is elsewhere)
scripts\host-tests.cmd

# ArkTS unit tests (hvigor + hypium)
bash scripts/arkts-tests.sh

# Build the .hap -> entry/build/default/outputs/default/entry-default-signed.hap
hvigorw assembleHap --mode module -p product=default -p module=entry@default --no-daemon
# (equivalent with Node 22+: devecocli build)

# Lint (Node 22+)
devecocli check lint .

# Install and launch on a connected device or emulator
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc shell aa start -a EntryAbility -b com.example.safe_n_sound
```

On first start the app asks for notification permission and the microphone permission (with a privacy
explanation). If you deny the microphone, the Listen tab explains why it is needed and the next try opens the
system Settings page.

## Engine checks on real audio

`build-host\tests\wav_cli.exe file.wav` (built by `scripts\host-tests.cmd`) runs the team's detector on a WAV file, and
`build-host\tests\replay_cli.exe recording.wav [threshold]` replays a recording through the same `SoundEngine` the app
uses: it learns the first alarm and prints every alarm and every recognition. To record audio on the phone, set
`DEBUG_CAPTURE_AUDIO` to `true` in `entry/src/main/ets/services/AudioService.ets`; the app then writes
`debug_capture.pcm` (16 kHz mono 16-bit) into its files folder, which can be pulled with `hdc file recv`.
`entry/src/main/cpp/tests/data/phone_alarm_3x.wav` is such a recording (three plays of an alarm in a noisy room) and a
unit test checks that the first play is learned and the other two are recognised.

### Complex signals

`build-host\tests\complex_eval.exe` (run from the repository root) mixes five synthetic multi-note signals (a decaying two-note
chime, a rising arpeggio that gets louder, a two-tone siren, an irregular pattern of notes with uneven gaps, and a
tremolo tone) into real room noise from the phone recording at 25/20/15/10 dB above the noise. In that setup every
signal is detected, taught from two takes, recognised 3 of 3 times at every level, and never mistaken for another one.
`complex_eval.exe --export <dir>` writes the signals as WAV files for playback tests, and
`complex_eval.exe --takes <phone.wav> <start s>...` cuts 6 s takes from a phone recording and runs the Teach checks.
Played through a PC speaker and recorded by the phone in a real room the picture is worse: of five signals only the
tremolo tone could be taught from two takes (the takes of the chime, siren, arpeggio and irregular pattern were judged
too different from each other, similarity -0.00 to 0.60 against a 0.6 limit). See the limitations below.

## Signed .hap

A signed package is what a device or emulator accepts. It is produced like this (the signing data stays on the
machine, it is never committed):

1. Open the project in DevEco Studio, connect the phone (or start the emulator) and sign in with a Huawei ID.
2. File > Project Structure > Signing Configs > tick "Automatically generate signature" > Apply. DevEco creates a
   debug certificate (alias `debugKey`) and a debug profile in `%USERPROFILE%\.ohos\config` and writes them into
   `build-profile.json5` (keep that change out of git: `git update-index --skip-worktree build-profile.json5`).
3. Build and verify both variants with one command:

   ```bash
   bash scripts/make-signed-hap.sh
   ```

   This runs `hvigorw assembleHap` for `debug` and `release` (`-p buildMode=release`), copies the results to
   `dist/safe-n-sound-debug-signed.hap` and `dist/safe-n-sound-release-signed.hap`, and checks each signature with
   the SDK's `hap-sign-tool.jar verify-app` (expected: `Verify success`).
4. Install: `hdc install -r dist/safe-n-sound-release-signed.hap`.

What this signature is, honestly: the certificate and profile are the auto-generated **debug** ones. The profile is
bound to the bundle `com.example.safe_n_sound` and to the devices that were registered when it was generated, and it
is valid for about two weeks (the profile of the submitted build: 2026-10-03 to 2026-10-17, one registered device).
So the package installs on that phone only; to install it on another phone or an emulator, repeat step 2 with that
device connected and rebuild. Publishing to other users would need a release certificate and profile from AppGallery
Connect, which this project does not have. The `.hap` files are not committed to the repository; the signed release
build is attached to the GitHub release [v1.0.0](https://github.com/Xp4blos/safe-n-sound/releases/tag/v1.0.0) (note that
the profile inside it contains the registered device's ID). `dist/` is git-ignored.

## How to trigger a detection for a demo

The detector reacts to **tonal signals of 0.4 s or longer between 800 and 4500 Hz** (smoke-alarm and appliance
beeps, door chimes, buzzers). Use a second device or a speaker (not headphones) and hold it 10-30 cm from the
phone's microphone in a quiet room; search the web for "smoke detector beep", "microwave beep" or a 2 kHz tone.

1. Tap the microphone, allow the permissions, stay quiet for 2 seconds.
2. Play the sound for 3-5 seconds: after about 4 seconds it appears in History as "Unknown sound".
3. Play it again: the "I've heard this sound before" dialog appears; tap Name it and call it "Doorbell".
4. Play it a third time: the phone vibrates, shows the "Doorbell detected" notification and card, and
   History shows the same entry with count 3.
5. For a sound shorter than 0.4 s, use **Teach a sound** on the Listen tab instead.

## Demo video

A 95-second demo recorded on the test phone (screen frames captured with `hdc`, a real alarm sound played from a PC
speaker next to the phone): start listening with the microphone permission, a sound is detected and appears in
History as "Unknown sound", the same sound again triggers "I've heard this sound before", it is named "Doorbell",
and the third time the "Doorbell detected" card appears. The phone's vibration cannot be filmed. The video is attached
to the GitHub release: https://github.com/Xp4blos/safe-n-sound/releases/tag/v1.0.0 (`safe-n-sound-demo.mp4`).

## Known limitations

- Listening stops when the app goes to the background or the screen locks (foreground only).
- Detection thresholds come from the team's engine; the similarity needed to recognise a learned sound again is 0.6
  (the engine default 0.8 missed quieter real repeats), tuned on recordings of one alarm sound in one noisy room; sounds shorter than 0.4 s,
  very quiet sounds, and sounds outside 800-4500 Hz are not detected automatically (Teach covers them).
- Complex multi-note sounds (decaying chimes, two-tone sirens, irregular note patterns) are detected, but teaching them
  from two takes often fails on real speaker-and-room audio because the takes are judged too different; simple tones and
  tremolo tones work. Teaching from three takes or a quieter room may help (untested).
- Knocks and loud sounds are not reported (the phone's own vibration would be classed as one).
- Keyword detection ("Help!", "Watch out!", "Ratunku!") is roadmap only; the engine contains keyword logic
  but no speech recogniser is bundled.
- English UI only. Lint reports 5 style warnings (prefer `@Builder` over small components).

## License

There is deliberately no license file: this is the team's own work, all rights reserved by the authors.

## Prior code and AI use

- `entry/src/main/cpp/ambient` is the sound engine written by a member of the team for this hackathon
  (https://github.com/Xp4blos/hack-yeah-2026, commit `512e41d`), included without `speech.*`. See
  `entry/src/main/cpp/ambient/README.md`.
- No third-party open-source code is bundled besides the HarmonyOS SDK, hypium/hamock test libraries (installed
  by `ohpm`) and the DevEco toolchain.
- AI assistants were used throughout; see `AI_WORKFLOW.md` for tools, prompts, validation and the bugs found
  during phone testing.
