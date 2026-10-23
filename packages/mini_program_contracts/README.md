# mini_program_contracts

Shared contracts for the portable Flutter mini-program platform.

This package holds the stable language shared by mini-program authoring,
static artifact delivery, Publisher API backends, host apps, and
runtime/tooling packages.

## What it exports

- manifest models and cache policy types
- value-based capability IDs
- screen format metadata for Mp JSON screens
- stable action names
- typed action payload models
- host action request/result envelopes
- mini-program screen navigation payloads
- SDK semver compatibility helpers
- stable error codes and feature flag keys
- provider-neutral file-transfer progress, capability, and error contracts
- strict civil-date, clock-time, and inclusive date-range value validation

## Who should depend on it

- runtime and tooling packages that need to read or validate mini-program
  manifests
- artifact services and Publisher API tooling that serve or validate contract data
- host apps that implement typed bridge payloads

Most application code should depend on a higher-level package such as the SDK
or tooling package. Depend on `mini_program_contracts` directly when you need
the shared wire-level types and constants.

## Screen formats

Mp JSON is the default screen format. Missing values decode as `mp` with
schema version `1`. Manifests may declare the format explicitly:

```json
{
  "screenFormat": "mp",
  "screenSchemaVersion": 1
}
```

Unknown non-empty screen format strings are preserved so SDKs can show a
controlled unsupported-format error.

## Capability IDs

New code should use `CapabilityId` strings and the constants in
`CapabilityIds`, for example `CapabilityIds.auth` or
`CapabilityIds.mediaVideo`. The old `Capability` enum remains available as a
deprecated compatibility API while the Mp engine branch migrates callers.

Gallery contracts include `MiniProgramGalleryImage`,
`MiniProgramGalleryResult`, `CapabilityIds.galleryImages`, and stable
`gallery.*` action names/errors. Selection metadata contains bounded image
properties and opaque media references; native paths, URIs, and bytes are
never part of the wire result.

Microphone contracts include `MiniProgramMicrophoneResult`,
`CapabilityIds.microphoneRecord`, recording actions, and stable errors. Voice
notes expose bounded AAC/M4A metadata and opaque references. See the
[Android microphone guide](https://github.com/mehedi8603651/flutter-mini-program-platform/blob/main/docs/android_microphone_recording.md).

Clipboard, haptic feedback and phone dialing use canonical action/capability IDs
and stable errors. `MiniProgramVibrationEffect` defines bounded system effects;
`normalizeMiniProgramPhoneNumber` rejects schemes, USSD and pause sequences.
See the [Android system capability guide](https://github.com/mehedi8603651/flutter-mini-program-platform/blob/main/docs/android_clipboard_vibration_phone.md).


## Shop location and directions

See the [Android shop location guide](https://github.com/mehedi8603651/flutter-mini-program-platform/blob/main/docs/android_shop_location_directions.md) for setup, host acceptance, coordinate systems and provider limits.

## Optional foreground NFC

Available with UI `0.3.3`, SDK `0.7.3`, contracts `0.3.20`, and tooling `0.7.21`.

Pure-Dart `Mp.nfc` actions read bounded standard NDEF Text and HTTPS URI records
through an optional native Android adapter. Hosts accept access and limits per
mini-program; task switches cancel reading while retaining UI state. Install with
`miniprogram host capability init nfc --platform android`. See the [NFC guide](https://github.com/mehedi8603651/flutter-mini-program-platform/blob/main/docs/android_nfc_ndef.md).
