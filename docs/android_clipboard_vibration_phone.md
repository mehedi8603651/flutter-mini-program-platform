# Android clipboard, vibration and phone dialer

These optional capabilities work with ordinary embedded mini-programs and with
separate Android tasks. Hosts install only the providers they need and accept
each mini-program's policy independently. Installation never grants policy.

Requires `mini_program_contracts >=0.3.16`, `mini_program_ui >=0.2.12`,
`mini_program_sdk >=0.6.14`, and `mini_program_tooling >=0.7.13`.

## Host installation

```powershell
# New hosts: choose standard embedding or add --android-separate-tasks.
miniprogram embed init --project-root .

miniprogram host capability init clipboard --platform android --project-root .
miniprogram host capability init vibration --platform android --project-root .
miniprogram host capability init phone --platform android --project-root .
flutter pub get
```

Existing hosts must upgrade the SDK dependency first. Use `embed init --force`
when refreshing an older generated runtime scaffold. Host-owned providers and
accepted policies are preserved. Separate-task registration works in either
installation order and survives scaffold regeneration.

No additional Android permission or Gradle dependency is needed. Generated
Kotlin is kept in `mini_program/generated/{clipboard,vibration,phone}/` and
registered through `MiniProgramNativeSetup`. Host-owned Dart adapters are
created once under `lib/mini_program/app_android_*_provider.dart`; rerunning
the installer preserves edits. Conflicting files fail before any write.
Automatic installation expects one Kotlin `MainActivity` extending
`FlutterActivity` or `FlutterFragmentActivity`.

Installed providers advertise `clipboard.read`, `clipboard.write`, `vibration`,
and `phone.dialer` capabilities. Mini-program manifests may declare the ones
they require. Capability availability and accepted app policy are separate:
declaring a capability never grants clipboard access or other permission.

## Accepted host policy

In `lib/mini_program/mini_program_policies.json`, review the app's
`accepted.permissions`, then regenerate endpoints and the policy resolver
using the host endpoint import workflow. A policy example is:

```json
{
  "clipboard": {
    "enabled": true,
    "allowRead": false,
    "allowWrite": true,
    "maxTextLength": 4096
  },
  "vibration": { "enabled": true },
  "phone": { "enabled": true }
}
```

Clipboard reads require separate opt-in with `allowRead: true`. A publisher
may request `clipboard` with `enabled`, `reason`, `read`, `write`, and
`recommendedMaxTextLength`. Reads default to false, writes to true, and the
recommended limit to 32768. `vibration` and `phone` requests contain only
`enabled` and a bounded `reason`. Normal import defaults new permissions to
denied and preserves host decisions. Explicit `--accept-requested-policy`
accepts requested operations; force import resets these permissions to denied.
Unknown host-owned accepted fields are preserved.

For a manually integrated host, pass `clipboardProvider`, `vibrationProvider`,
and `phoneProvider` to `MiniProgramConfig`, and set `clipboardPolicy`,
`vibrationPolicy`, and `phonePolicy` on each `MiniProgramEndpoint`. Custom
sources can implement the corresponding `MiniProgram*PolicyProvider`
interfaces. Without a policy provider these operations remain denied.

## Authoring

```dart
Mp.primaryButton(
  label: 'Copy booking code',
  action: Mp.clipboard.writeText(text: '{{state.booking.code}}'),
);

Mp.primaryButton(
  label: 'Paste booking information',
  action: Mp.clipboard.readText(
    targetState: 'booking.paste',
    statusState: 'clipboard.status',
    errorState: 'clipboard.error',
  ),
);
// Success: {hasText: true, text: "..."}, or {hasText: false, text: null}.

Mp.primaryButton(
  label: 'Confirm selection',
  action: Mp.vibration.trigger(effect: MpVibrationEffect.success),
);

Mp.primaryButton(
  label: 'Phone ticket office',
  action: Mp.phone.openDialer(number: '+880 (171) 234-5678'),
);
```

All actions require an explicit user gesture and an active foreground
mini-program. They cannot run from initialization, timers, or background
mini-programs. Actions support optional `targetState`, `statusState`,
`errorState`, and `requestId`; `readText` requires a target. Status moves from
`loading` to `success` or `error`. Failure preserves the previous target.
Bindings are checked again after resolution. Late clipboard reads cannot
write data into a disposed, replaced, hidden, or background mini-program.

### Clipboard

Only bounded plain text is supported. Whitespace and empty strings are
preserved. Images, content URIs, Intents, clipboard listeners, and clipboard
history are unavailable. The native provider checks the text length before
returning it through the channel; the SDK also checks custom provider results.
The maximum is 32768 UTF-16 code units, and the host may lower it.

Writes default to `sensitive: true`, asking supporting Android versions to hide
the clipboard preview. This does not disable system clipboard history or
provide secret storage. A user-approved read intentionally puts text into
mini-program state; the host should approve reads only for trusted workflows.
Android can display its own clipboard notification or automatically clear
clipboard content. No clipboard data is read implicitly.

### Vibration

`light`, `medium`, `heavy`, `selection`, `success`, `warning`, and `error` are
short system haptic feedback effects. Android chooses their physical strength
and duration. The provider uses `View.performHapticFeedback` and respects
system and view preferences. It does not request `VIBRATE`, bypass settings,
or create repeating effects that could continue in the background.

Success data is `{performed: bool, effect: "..."}`. `performed: false` is a
valid result when haptics are disabled or unavailable. Emulator results verify
dispatch and Android acceptance; physical sensation needs a real device.

### Phone dialer

Android receives `ACTION_DIAL` with an encoded `tel` URI. The user chooses
whether to call. The SDK never directly calls a number or requests
`CALL_PHONE`. A successful `{dialerOpened: true}` result describes opening UI
and does not claim a call was placed or completed.

Numbers may contain an optional leading `+`, 1–32 digits, and ordinary spaces,
parentheses, dots, or hyphens (up to 64 input characters). Formatting is
removed before dialing. URI schemes, USSD/MMI codes, pauses, extensions,
control characters, and arbitrary URLs are rejected by authoring, runtime,
and native validation. Tablets and devices without a dialer return
`phone_unavailable`. Back returns to the existing mini-program task and state.

## Errors and platform scope

Each feature has stable `*_not_accepted`, `*_unavailable`,
`*_user_gesture_required`, `*_foreground_required`, `*_invalid_request`,
`*_operation_failed`, and `*_request_cancelled` error codes. Missing native
providers fail without falling back to an unrestricted host action.

Bundled installers currently target Android. Other platforms can install
trusted providers implementing the same public interfaces. This release does
not change the standard in-host presentation or separate-task opt-in.
