# Hackathon Brief

The user owns the decisions recorded here. Unresolved fields may remain blank; do not ask the user to complete them until the current work depends on them.

## Pitch

**User problem:** People who are hard of hearing miss the signals that matter most in daily life: a doorbell or knock, a smoke alarm, a siren, a crying baby, someone calling their name. Missing them is a safety risk and a source of exclusion. Existing solutions are single-purpose hardware that handle one sound each.

**Desired demonstration:** [Not decided yet]

**Lead challenge theme:** [Intelligent Experiences / Spatial Experiences / Human-Centric Technology - not chosen yet]

**Distinctive platform capability:** Microphone capture, vibration and notifications on a Huawei phone, with sound analysis done on the device by a native C++ engine (no cloud, no stored audio).

## Target

- Platform: HarmonyOS
- API level: compatible SDK 20 (6.0.0(20)), target SDK 24 (6.1.1(24))
- Device type: phone
- Validation target: physical Huawei phone PLR-AL00 (API 26)

## Intended user flow

1. Open the app and tap Start listening (the microphone permission and notification permission are requested).
2. The Listen tab shows a pulsing microphone and an 8-second level chart; any detected beep, alarm, signal or door ring vibrates the phone and appears as the last detected sound.
3. In the History tab, tap a heard sound and give it a name, such as "Doorbell".
4. When that named sound is heard again, the phone vibrates and shows a notification with its name.

## Acceptance checks

- [ ] A beep or alarm played near the phone is detected and the phone vibrates
- [ ] The same sound heard again is recognised as the same entry in History (times heard increases)
- [ ] A named sound produces a notification with its name when heard again, at most once per 10 seconds
- [ ] History and names survive restarting the app
- [ ] Denying the microphone permission shows a clear message and nothing crashes
- [ ] Sending the app to the background releases the microphone

None of these has been confirmed by the user yet.

## Scope boundaries

- In scope: detecting beeps, alarms, signals and door rings from amplitude, frequency and dynamics; remembering sounds by fingerprint; sound history; naming sounds; vibration and notification alerts; foreground listening; Listen and History tabs.
- Out of scope: speech recognition, knock and loud-sound categories, background listening, cloud services, audio storage (all deferred by the user for later).
- Mocked or simulated behavior: None in the product. Unit tests and the native smoke check use synthetic audio.

## First-minute narrative

[Not planned yet]
