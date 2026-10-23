# Android foreground NFC NDEF reading

NFC is an optional host-installed capability. Mini-programs use pure-Dart
`Mp.nfc` actions; a generated Kotlin adapter uses Android's built-in
`NfcAdapter.enableReaderMode` and `Ndef` APIs. Installation adds no NFC Flutter
plugin, Gradle library, background service, or tag-launch intent filters.

Requires UI `0.3.3`, SDK `0.7.3`, contracts `0.3.20`, and tooling `0.7.21`
or newer compatible versions. Access remains optional and host-controlled.

## Host setup

After standard embedding, install the adapter once in the Flutter host:

```powershell
miniprogram host capability init nfc --platform android --project-root .
```

Install or update the published CLI before running the installer:

```powershell
dart pub global activate mini_program_tooling 0.7.21
```

The installer generates a host-owned `app_android_nfc_provider.dart` and managed
`MiniProgramNfcChannel.kt`, registers the native adapter with Flutter engines,
and adds `android.permission.NFC` and an optional `android.hardware.nfc` feature.
Existing host hardware requirements are preserved. Restrictive permission or
manifest merge declarations must be reconciled by the host before installation.
Planning failures leave the installation unchanged.

Repeated installation preserves host Dart customizations. Both standard
embedding and `--android-separate-tasks` work in either installation order;
`embed init --force` retains the installed NFC provider.

NFC uses an Android manifest permission rather than a runtime permission dialog.
The phone must have NFC hardware and the user must enable it in device settings.
Phones without NFC can still install and use the host.

## Host-accepted policy

Installation grants no mini-program access. Review the imported app's
`accepted.permissions.nfc` in `lib/mini_program/mini_program_policies.json`:

```json
{
  "enabled": true,
  "allowedRecordTypes": ["text", "uri"],
  "maxReadMs": 15000,
  "maxRecords": 8,
  "maxMessageBytes": 4096
}
```

Regenerate endpoint/policy resolution through the normal host import workflow.
Runtime reads accepted policy only. The default policy denies NFC access.
Hosts can restrict records to `text` or `uri`; the array must be nonempty.

A publisher may request NFC through handoff configuration:

```json
{
  "requestedPermissions": {
    "nfc": {
      "enabled": true,
      "reason": "Read the product code from the shop tag.",
      "recordTypes": ["text"],
      "recommendedMaxReadMs": 15000,
      "recommendedMaxRecords": 4,
      "recommendedMaxMessageBytes": 1024
    }
  }
}
```

Recommendations never authorize access. Reimport preserves host acceptance and
custom fields unless the host explicitly requests replacement.

Manually assembled hosts can supply `MiniProgramConfig.nfcProvider` and
`MiniProgramEndpoint.nfcPolicy` (or a `MiniProgramNfcPolicyProvider` source).
Register `CapabilityIds.nfcRead` only when a provider is installed.

## Mini-program authoring

```dart
import 'package:mini_program_ui/mini_program_ui.dart';

// Availability needs accepted policy and a foreground mini-program.
Mp.nfc.getState(targetState: 'nfc.availability');

// Invoke from an explicit user action such as a button tap.
Mp.nfc.read(
  timeoutMs: 15000,
  targetState: 'product.tag',
  statusState: 'product.tagStatus',
  errorState: 'product.tagError',
);

// Cancels only this mini-program's pending operation.
Mp.nfc.cancel();
```

Availability is `{"supported":true,"enabled":true}`. A read returns:

```json
{
  "records": [
    {"type": "text", "text": "product-42", "language": "en"},
    {"type": "uri", "uri": "https://shop.example/products/42"}
  ]
}
```

Use the normal `Mp.stateBuilder` subscription when displaying results/status.
Text uses strict UTF-8 or UTF-16 decoding. URI records must resolve to absolute
HTTPS URLs without credentials or control characters. Results contain supported
normalized fields only. Tag IDs, native objects, raw payload bytes, platform
Intents, and native errors never enter mini-program state.

Tag content remains inert data. A URI record does not open a browser, fetch a
URL, or execute an action. Publisher API actions continue to use only the
accepted artifact-declared Publisher API; reading a tag cannot change that
authority. Product lookup and other business rules belong to the mini-program
and its publisher's server.

## Limits and lifecycle

- Read duration is 1000–30000 ms, defaulting to 15000 ms. The host can shorten it.
- At most 16 records and 8192 encoded message bytes are allowed; host defaults
  are 8 records and 4096 bytes. The same byte limit also bounds normalized text
  and URI data. Each text record is limited to 4096 UTF-8 bytes and each URI to
  2048 UTF-8 bytes. NFC text-language codes are at most 63 ASCII characters.
- Each read consumes one tag and ends on success or failure. A message with an
  unsupported, disallowed, malformed, or oversized record fails as a whole.
  This includes messages containing additional MIME or Android Application Records.
- One pending read owns native NFC across all Flutter engines/separate Android
  tasks in the host process. Concurrent owners receive `nfc_in_use`; another
  app/session cannot cancel the owner. Duplicate requests in one manager receive
  `nfc_request_in_progress`.
- Blocking NFC I/O runs off the UI thread. Native work and callback delivery are
  bounded. Cancellation disables reader mode, closes pending tag I/O, and rejects
  late results. SDK and native timeouts independently release a stalled request.
- Hiding, Activity pauses, backgrounding, configuration changes, disposal, and
  engine detachment end a read. Returning requires a new explicit read; the
  mini-program's existing screen, form and state remain retained by the host.
- Failed, cancelled, stale or quota-rejected results preserve prior target data.
  Successful data/status/error updates use the existing atomic state boundary.

`statusState` is `loading`, `success`, `cancelled`, or `error`. Result/status/error
paths must not overlap. Stable errors cover unavailable/disabled NFC, missing
host acceptance, gesture/foreground requirements, conflicts, timeout,
cancellation, unsupported tags/records, malformed data, lost tags and limits.

The initial capability reads standard NDEF Text/URI records. Tag writing,
formatting, locking, raw commands, card emulation, payment/transit integrations,
and background tag dispatch require separate future designs.

## Validation

Tests cover shared wire limits and sanitization, deterministic pure-Dart actions,
strict runtime schemas, accepted/requested policy, atomic state writes,
unavailable/failed providers, stale completions, cancellation, timeout and retained
UI state. Tooling tests cover transactional installation, host edits, repeated
installation and separate-task regeneration. Generated Kotlin is compiled
against Android API 36 and Flutter embedding with Kotlin 2.2.20 / Java 17.

Physical tag reading is not verified by these checks. An NFC-capable Android
phone and real NDEF tags are needed to validate discovery, UTF-8/UTF-16 and URI
tags, disabled NFC, tag removal, timeouts, and separate-task switching. Emulator
availability checks cannot prove radio interoperability.

Android references:
[reader mode](https://developer.android.com/reference/android/nfc/NfcAdapter#enableReaderMode(android.app.Activity,android.nfc.NfcAdapter.ReaderCallback,int,android.os.Bundle)),
[NDEF I/O](https://developer.android.com/reference/android/nfc/tech/Ndef),
and [NFC overview](https://developer.android.com/develop/connectivity/nfc).
