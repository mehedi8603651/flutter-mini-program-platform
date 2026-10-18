# Android microphone recording

Requires contracts **0.3.15**, UI **0.2.11**, SDK **0.6.13**, and tooling
**0.7.12** or later in their compatible release lines.

This optional capability records foreground voice notes using Android's
`MediaRecorder`. A recording produces an app-owned temporary reference and
bounded metadata. It requires an explicit user gesture, accepted host policy,
and Android microphone permission. Installation alone grants no app permission.

## Host setup

Update existing host dependencies to SDK `^0.6.13` and contracts `^0.3.15`.
From the Flutter host directory:

```powershell
dart pub global activate mini_program_tooling 0.7.12
miniprogram embed init --project-root .
miniprogram host capability init microphone --platform android --project-root .
flutter pub get
```

Existing embedded hosts can run the capability command directly. Optional
`embed init --android-separate-tasks` works before or after capability setup.
Each task engine initializes its own provider. Only one recorder can capture
at a time across the host process.

The installer creates a host-owned Dart adapter, a Kotlin recorder, a private
FileProvider/cache path, and shared native registrations. It adds only
`RECORD_AUDIO` permission and marks microphone hardware as optional when no
host hardware declaration exists. It preserves the host's Android toolchain
and existing provider customizations. Recorder setup, capture control, and
file finalization run on a dedicated native worker so a slow device does not
block Android UI or permission handling. Kotlin `FlutterActivity` and
`FlutterFragmentActivity` hosts are supported.

The microphone FileProvider has a distinct component class so it can coexist
with gallery and camera providers. It reports `audio/mp4` for generated M4A
notes consistently across Android MIME tables, including strict uploads.

Review the mini-program's accepted `permissions.microphone` in
`lib/mini_program/mini_program_policies.json`, then regenerate endpoint
configuration through the normal endpoint-import workflow:

```json
{
  "enabled": true,
  "maxDurationSeconds": 60,
  "maxBytes": 20971520
}
```

Manual composition uses `MiniProgramConfig.microphoneProvider`,
`CapabilityIds.microphoneRecord`, and per-endpoint policy:

```dart
MiniProgramEndpoint.public(
  apiBaseUri: Uri.parse('https://static.example.com/'),
  microphonePolicy: const MiniProgramMicrophonePolicy(
    enabled: true,
    maxDurationSeconds: 60,
    maxBytes: 20 * 1024 * 1024,
  ),
)
```

Microphone provides media-release support when no explicit media or gallery
provider is installed. A custom media provider must resolve the same app-owned
references. The generated Android file/gallery adapters already share this
native registry.

## Record, stop, and cancel

```dart
Mp.primaryButton(
  label: 'Record voice note',
  action: Mp.microphone.record(
    maxDurationSeconds: 60,
    targetState: 'voice.note',
    statusState: 'voice.status',
    errorState: 'voice.error',
  ),
)
Mp.primaryButton(label: 'Stop', action: Mp.microphone.stop())
Mp.primaryButton(label: 'Cancel', action: Mp.microphone.cancel())
```

The Record action remains pending until capture ends. A separate Stop button
finalizes it and writes the result to the original `targetState`. Cancel
discards partial audio and preserves the previous target. Avoid putting Stop
after Record in one action sequence: that sequence waits for Record to finish.

`statusState` progresses through `starting`, `recording`, and either `success`,
`cancelled`, or `error`. Use `Mp.stateBuilder` to display reactive status and
recording metadata.

The result contains `recordingId`, `mediaRef`, `fileName`, `mimeType`, `bytes`
(a byte count), `durationMs`, `codec`, `sampleRate`, `channels`, `stopReason`,
and `recordedAtUtc`. The fixed format is AAC in M4A (`audio/mp4`), mono,
16 kHz, 64 kbps. Stop reasons are `user`, `durationLimit`, `sizeLimit`, and
`background`. Native paths, content URIs, and raw audio never enter state.

## Playback, upload, sharing, and release

Playback separately requires the `audio` adapter and accepted audio policy.
For an existing Android Media3 installation, rerun its capability command to
refresh tooling-managed native support; the host-owned Dart adapter is kept:

```powershell
miniprogram host capability init audio --platform android --project-root .
```

```dart
Mp.audio.play(
  audioId: 'voice-preview',
  source: MpAudioSource.hostMedia('{{state.voice.note.mediaRef}}'),
  statusState: 'voice.playbackStatus',
)

Mp.file.upload(
  endpoint: 'voice/upload',
  mimeTypes: const ['audio/mp4'],
  mediaRefs: const ['{{state.voice.note.mediaRef}}'],
  progressState: 'upload.progress',
  targetState: 'upload.result',
)

Mp.share.open(mediaRefs: const ['{{state.voice.note.mediaRef}}'])
Mp.media.release(mediaRef: '{{state.voice.note.mediaRef}}')
```

Uploads separately require the file adapter, accepted upload policy, and an
accepted artifact-declared Publisher API. Sharing requires the share adapter
and accepted sharing policy. Recording grants neither permission. Local audio
playback revalidates app ownership, permits audio only, and uses direct
playback without making another temporary playback-cache copy. Custom playback
providers receive a trusted `miniprogram-media:<opaqueRef>` candidate and must
resolve it through their own media ownership implementation.

Publishers may request microphone access in partner handoff:

```json
{
  "requestedPermissions": {
    "microphone": {
      "enabled": true,
      "reason": "Record a booking voice note.",
      "recommendedMaxDurationSeconds": 60,
      "recommendedMaxBytes": 20971520
    }
  }
}
```

The host reviews this request. Apps that require capture can declare
`microphone.record` as a required manifest capability.

## Lifecycle and limits

- Policy defaults to disabled, 60 seconds, and 20 MiB. Accepted duration is
  1-600 seconds and the byte cap is between 1 byte and 100 MiB. Requested
  duration is clamped to the accepted maximum. Encoder finalization permits
  at most one extra second;
  output exceeding the accepted byte limit is rejected and cleaned.
- Android prompts for runtime permission on first use. Denial and permanent
  denial return stable errors. A host may provide its own explanation or
  settings UI; recording never opens settings automatically.
- Permission-dialog inactivity does not stop capture. When the mini-program
  becomes hidden, its activity stops, or the host backgrounds, recording
  finalizes with `stopReason: background`. It does not restart automatically.
  No foreground service or background-recording permission is installed.
- Disposal, provider replacement, app changes, and cancellation discard a
  pending recording. Late results, invalid results, and state quota failures
  release newly created audio. Completed notes survive retained task switches.
- Very short recordings may contain no encodable samples and fail cleanly.
  Device microphone availability, system privacy controls, other capture apps,
  and hardware determine whether Android can record.
- References are temporary, scoped to their mini-program, and invalid after
  release, process death, or cache removal. Replacing a note does not release
  older references: release them when finished or persist the publisher's file
  identifier after upload. A new recording cleans prior-process orphan files.
- This release targets Android. Other platforms can install a trusted custom
  provider; no iOS recorder adapter is supplied.

## Release verification

The coordinated release passed contracts, authoring, SDK, and tooling tests,
analysis, and the repository engine release check. Installer coverage includes
idempotence, host-owned Dart changes, rejected manifest/permission conflicts,
accepted policy, and microphone/gallery/audio installation in either order.

A release APK was exercised on an Android 16 / API 36 x86_64 emulator:

- Denying microphone permission returns a stable error without a recording.
  Retrying and approving permission records successfully.
- Manual Stop saves a note; Cancel preserves the previous note; a requested
  three-second limit finalizes automatically.
- Owned audio plays through Media3, streams to the accepted Publisher API,
  opens Android's share chooser, and becomes unusable after explicit release.
  The received upload was checked as MPEG-4 AAC, mono, 16 kHz, `audio/mp4`.
- Returning to the host finalizes recording with `stopReason: background`.
  A host Chat draft, two mini-program booking fields, and separate completed
  notes survived switching between three live Android activities. Separate
  task IDs and Recent apps cards were verified.
- The worker-thread recorder completed these flows without a new app freeze
  or ANR.

Emulator input validates encoding and integration. Physical microphone quality
and device-specific capture behavior still need testing on physical devices.
