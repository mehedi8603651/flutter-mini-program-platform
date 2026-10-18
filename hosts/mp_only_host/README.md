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
existing task forward; Back and the toolbar buttons return to the host without
finishing the mini-program. A full pool reports a limit without evicting a live
app. Other hosts need their own native Activity/manifest integration; importing
the Dart SDK alone does not create Android Activities.

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
