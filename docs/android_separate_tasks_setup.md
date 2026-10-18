# Optional separate Android tasks

Standard SDK embedding opens a Flutter page inside the host. A host developer
can opt into separate Android tasks without changing mini-program artifacts
or the SDK's default navigation.

Separate-task generation requires tooling `0.7.10` or later and SDK `0.6.11`
or later. Install the CLI:

```powershell
dart pub global activate mini_program_tooling 0.7.10
```

When testing a development checkout, activate the local CLI from the
repository root instead:

```powershell
dart pub global activate --source path ./packages/mini_program_tooling
```

Alternatively, run `dart run bin/miniprogram.dart` in
`packages/mini_program_tooling` in place of `miniprogram`.

```powershell
# Standard setup: mini-programs open inside the host.
miniprogram embed init --project-root .

# Optional setup: generate separate Android tasks.
miniprogram embed init --project-root . --android-separate-tasks
```

For an existing integration, add `--force` to the optional command. Setup
requires `lib/main.dart`, an Android manifest, and one Kotlin `MainActivity.kt`
extending `FlutterActivity` or `FlutterFragmentActivity`. Unsupported custom
declarations and conflicting files produce an error before any files change.
It does not change AGP, Gradle, Kotlin, or accepted mini-program permissions.

## Connect the generated navigation

Use the generated public import and add the navigation delegate:

```dart
import 'package:flutter/material.dart';
import 'mini_program/mini_program.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await buildHostMiniProgramConfig();
  runApp(
    MiniProgramScope(
      config: config,
      navigationDelegate: openMiniProgramInAndroidTask,
      child: const MyApp(),
    ),
  );
}
```

Existing buttons and generated launcher widgets continue to use the same API:

```dart
await MiniProgramScope.of(context).openMiniProgram<void>(
  appId: 'booking',
  title: 'Booking',
);
```

On Android this opens or resumes a task. On other platforms the generated
delegate pushes a normal Flutter route. Omitting the delegate uses standard
SDK navigation on every platform. There is no tab strip, floating overlay, or
automatic fallback to a workspace.

Setup preserves the host's `main()` and adds two small managed blocks to
`lib/main.dart`: an import and a `@pragma('vm:entry-point')` wrapper named
`miniProgramTaskMain`. Keep those blocks when editing that file. If your
application builds with another `--target`, copy both blocks into that root
library and adjust the relative import. The normal `lib/main.dart` target
needs no extra build flags:

```powershell
flutter pub get
flutter build apk --release --split-per-abi
```

## Generated files and host ownership

| Path | Ownership and purpose |
| --- | --- |
| `lib/mini_program/mini_program_android_tasks.dart` | Generated delegate and task root widget; exported by the public integration barrel. |
| `lib/mini_program/app_android_task_setup.dart` | Host-owned initialization for each task engine; created once. |
| `lib/main.dart` | Host-owned; receives the managed entrypoint import and wrapper. |
| Kotlin package's `mini_program/generated/tasks/` | Generated channel, Activity classes, and slot allocator. |
| Kotlin package's `mini_program/generated/MiniProgramNativeSetup.kt` | Shared native registration, used by the host and all task engines. |
| `android/app/src/main/AndroidManifest.xml` | Host launch mode/affinity plus five non-exported task slot declarations in one managed block. |

`MainActivity` uses `singleTask` to return to the existing host. Setup preserves
an existing non-empty host task affinity, host Activity metadata, custom native
handlers, runtime composition, bridge, endpoint imports, and accepted policies.
An empty host affinity becomes `${applicationId}.host`. Slot affinities use
`${applicationId}.mini_program_task_0` through `_4`; the actual Kotlin package
name is discovered from `MainActivity.kt`.

`embed init --force` refreshes generated files and preserves host-owned files.
Once task setup has been installed, a scaffold refresh retains it even when
the optional flag is omitted. Remove the scope delegate to select ordinary
in-host navigation; the command does not implicitly disable a previous setup.

## Independent Flutter engines

Every task has its own Flutter engine and runtime. The created-once
`app_android_task_setup.dart` calls `buildHostMiniProgramConfig()` separately
and runs `AndroidMiniProgramTaskApp`. Customize that host-owned file for task
theme and initialization. Put configuration needed by every engine in the
shared host setup rather than only in the host's `main()`.

Native capability installers register each installed adapter in every engine,
including camera support through `FlutterFragmentActivity`. They can run before
or after task setup. Per-mini-program authorization still comes from the
host's accepted policy and imported endpoint map.

Dart objects are not shared between engines. Host providers, in-memory auth
sessions, and cache managers need independent initialization. Restore a login
session from host-owned storage when necessary, and use storage that supports
concurrent engines for persistent data. Keep authentication secrets out of
mini-program state and launch parameters.

## Runtime behavior

- Up to five different mini-program tasks can remain open alongside the host.
  Reopening an appId resumes its existing task and current screen without
  rebuilding the engine or resetting its data.
- Android Back and the task app-bar arrow foreground the host while retaining
  the mini-program. Removing a task from Recent apps releases its slot.
- Opening a sixth different app returns a `PlatformException` with code
  `mini_program_task_limit`. It does not evict an existing app. Host UI should
  handle launch errors and explain how to free a slot.
- The launch Future completes with `null` when a task opens or resumes. It
  does not wait for a Flutter route result.
- `appId`, title, app-bar visibility, and background color are supported.
  Per-launch `initialData`, `source`, `version`, and custom `routeBuilder`
  values are rejected with `UnsupportedError`. Configure sources and version
  selection through the host's configuration and artifact endpoints. Flutter
  navigator options do not control Android task presentation.
- Process death, force stop, or task removal can discard in-memory state.
  Persist important drafts under an explicit host-accepted policy.

Some ROM launchers show only one Recent apps card per package even when
several tasks are alive. Task setup cannot reliably detect or override that
filter. See [verified native-task compatibility findings](android_native_windows_compatibility.md).

## Verify an integration

Open two different mini-programs, enter data or navigate deeper in each, return
to the host with Back, and reopen both. Verify that each retains its screen and
data. Check task IDs and visible Recent apps cards separately:

```powershell
adb shell dumpsys activity activities
adb shell dumpsys activity recents
```

The host and `MiniProgramTaskActivity0` / `MiniProgramTaskActivity1` should have
different task IDs and affinities. Reopening the same app should reuse its
task. Test a release build as well as debug so Dart entrypoint retention is
verified.
