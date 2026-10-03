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

1. Open the app and tap the microphone or Start listening (microphone and notification permissions are requested).
2. The Listen tab shows an 8-second live spectrum; a detected signal sound appears in History as "Unknown sound".
3. When it is heard again the app asks "I've heard this sound before. Do you want to name it?"; the user names it.
4. When the named sound is heard again the phone vibrates, shows a notification "<Name> detected" and a card.
5. "Teach a sound" records 2-3 takes of a sound on purpose and saves it under a name.
6. History shows every sound with details in plain words; My sounds lists the named sounds with alert switches.

## Acceptance checks

- [ ] The live view moves with room sound (verified on the phone)
- [x] A real beep or doorbell appears in History as "Unknown sound" (verified on the phone, see demo video)
- [x] Playing it again shows the naming prompt; naming it works (verified)
- [ ] A third time vibrates, notifies "<Name> detected" and counts on the same entry
- [ ] A taught sound alerts under its own name and is not confused with the first
- [ ] Room hum, speech and the phone's own vibration create no entries
- [ ] Named sounds are still there after restarting the app

Verified on the phone: the live view, the "Unknown sound" entry, the naming prompt and naming, and the alert card with the count of 3 on the same entry. Not visually confirmed: vibration and the system notification. Not yet checked: a second taught sound, hum/speech/vibration creating no entries over a long time, restart persistence.

## Scope boundaries

- In scope: detecting signal sounds (beeps, buzzers, alarms, chimes); remembering them by fingerprint; history; naming; teaching sounds; vibration and notification alerts; foreground listening; Listen, History and My sounds tabs; live spectrum.
- Out of scope: keyword detection in several languages, knock and loud-sound categories, background listening, cloud services, audio storage (all deferred by the user for later).
- Mocked or simulated behavior: None in the product. Unit tests and the native smoke check use synthetic audio.

## First-minute narrative

[Not planned yet]
