# mp_only_host

Small reference host for static Mp screens in separate native Android windows.
Opening Profile Center, Orders, or Wallet creates or resumes that mini-program's
own Activity/task while retaining the host. These entries deliberately render
the same bundled profile fixture with separate app IDs and independent state.
Ordinary builds use native windows directly; no presentation-mode flag is
required.

The current integration focuses on native windows. An SDK-provided scrollable
workspace inside the host and live transfer between presentations are deferred;
the [future one-window design](../../docs/android_in_app_workspace_future.md)
records their requirements.

## Confirmed Vivo limitation

On a Vivo S10 Pro with Android 13 / OriginOS 3 and launcher `13.5.1.280`, the
host and mini-program remain alive in separate native tasks, but the launcher
shows only one card per ordinary app package. Its filtering code explicitly
exempts WeChat mini-program Activities. Additional processes or task flags do
not bypass that package-based rule. Separate system cards cannot be guaranteed
on every Android phone through the host integration.

See [Android native windows compatibility](../../docs/android_native_windows_compatibility.md)
for the device evidence and diagnostic steps. The host does not try to infer
visible card support or automatically switch presentation modes.

## Build and test

From this directory:

```powershell
flutter pub get
flutter build apk --release --split-per-abi
```

Install `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` on a modern
ARM64 phone. Use `app-x86_64-release.apk` for the x86_64 emulator. ABI splitting
does not change the Activity/task integration.

Verify the release build by opening all three entries, navigating Profile Center
to its details screen, returning to the host with Back, opening another
mini-program, then reopening Profile Center from the catalog. Its details
screen and task ID should remain unchanged. Verify the host and other
mini-programs retain their own Activity/task identities and state. Check visible
Recent apps cards separately, accounting for the documented Vivo restriction.

## Native Android windows

Five manifest-declared Activity/task slots are assigned to app IDs as they
open. Each uses a distinct component and affinity. Reopening an app brings its
existing task forward; root Back and Return to host return to the host without
finishing the mini-program. A full pool reports a limit without evicting a live
app. Other hosts need their own native Activity/manifest integration; importing
the Dart SDK alone does not create Android Activities.

The toolbar Back arrow first navigates the mini-program's own screen/popup stack,
matching Android Back. Return to host switches directly to the main host.

When Android restores a task without launch extras, its owned data URI supplies
the mini-program app ID for slot reuse and a fresh load.

The system owns the Recent apps UI and process lifetime. Distinct task IDs alone
do not prove that an OEM launcher displays separate cards; verify both on each
target ROM. In-memory state lasts while the process/Activity remains alive.
Swiping away a task, force stop, or process death may discard it.

With USB or wireless ADB debugging connected, capture actual phone task records
from the repository root:

```powershell
.\tools\inspect_android_windows.ps1 -DeviceSerial <adb-device-serial>
```

This prints device/Android and launcher versions, installed build information,
task identities, affinities, and running activities. It does not rebuild or
reinstall the app.

Run native allocator tests from the Android directory:

```powershell
Push-Location android
.\gradlew.bat :app:testDebugUnitTest
Pop-Location
```

Flutter host checks are `flutter analyze` and `flutter test`.

## Personal phone AI test

From the repository root, build an APK containing the authorized test key from
the ignored `.env`:

```powershell
python tools/build_phone_ai_apk.py
```

This enables the reference host's AI test controls and includes ARM64/x64
libraries. Install `build/app/outputs/flutter-apk/app-release.apk` from this host
directory, tap the host's floating **AI assistant** circle, then **Start AI**.
The shared bot opens **AI Food Demo** from the host and continues preparing its
order review. Drag the circle to either edge. You can edit the goal, minimize the
panel without losing its draft, and stop a run from the visible **Stop** button
beside the circle. Host and mini-program tasks share one runner and goal draft.
Opening the panel while running pauses the assistant. The default
model is `openai/gpt-6-luna`; pass `--model provider/model-id` to the build helper
to choose another model. Voice input is deferred.

Open **AI Controls Demo** to test search, dropdown selection, a checkbox, calendar
selection, and a preference review. Its catalog screen also exercises scrolling.
The shared goal draft stays the same when switching tasks. Edit it to
`Enter Green tea in Search products, choose Pickup, enable Use a reusable cup,
set Pickup date to October 28, 2026, and open the preference review.` To test
scrolling, use `Open the details of catalog item 18.`
After manual input, backgrounding, or an interrupted request, **Continue AI**
reads the current screen and plans again. Completion, missing input, blocked
progress, and failed requests have separate statuses. The host enforces bounded
time, decisions, reported usage, and repeated actions without visible progress.
The collapsed bubble shows a short status and keeps Stop available for paused
tasks. Stop or the panel's Cancel task ends the goal; already applied changes and
the editable goal draft stay available for a fresh Start. Back to preferences
stays pinned above the catalog while its items scroll.

The phone calls OpenRouter directly and needs its own working Internet/VPN
connection. Keep this APK for personal testing because it contains the test
key. Ordinary Flutter builds omit the key and AI test controls. See
[foreground AI interaction](../../docs/foreground_ai_interaction.md) for details
and the validated food-order flow.

The bubble's logo, label, size, colors and initial position are host-configurable.
It overlays the current mini-program without resizing it and remains available
above SDK dialogs. See [host-owned AI bubble](../../docs/host_ai_bubble.md) for
customization and super-app integration. The reference host registers its catalog
actions; a super-app supplies its own Chat/Wallet/search actions separately from
the SDK. Voice remains deferred.
