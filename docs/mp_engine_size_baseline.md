# Mp Engine Size Baseline

Date: 2026-06-03

## Baseline

- Worktree: `D:\flutter-mini-program-platform-mp-engine`
- Branch: `feature/mp-json-engine`
- Commit: `b1e7c4043ce90eb33bf08e998319ff27d364b8fa`
- Host app: `hosts/super_app_host`
- Flutter: `3.38.9`
- Dart: `3.10.8`

## Command

```powershell
cd D:\flutter-mini-program-platform-mp-engine\hosts\super_app_host
flutter build apk --release --analyze-size --target-platform android-arm64
```

The initial `flutter build apk --release --analyze-size` command was rejected
because Android size analysis requires a single ABI. The `android-arm64`
variant was used for this baseline.

## Result

- Build result: PASS
- APK: `hosts\super_app_host\build\app\outputs\flutter-apk\app-release.apk`
- APK size: `22,393,560` bytes (`21.4MB` reported by Flutter)
- Size analysis file:
  `C:\Users\mehed\.flutter-devtools\apk-code-size-analysis_01.json`
- Size analysis JSON size: `10,299,916` bytes

Selected AOT symbol groups from the current Stac-based runtime:

- `package:stac`: `994 KB`
- `package:stac_core`: `440 KB`
- `package:mini_program_sdk`: `138 KB`
- `package:dio`: `58 KB`

## Notes

The release APK was produced successfully. Gradle printed a Kotlin daemon cache
stack trace after the successful build output, but the command exited with code
`0`.

Flutter also warned that expected Material and Cupertino icon fonts were not
fully present in the font tree-shaking input. This does not block the baseline;
record any release-size improvement from the future Mp JSON engine against this
measured APK.

## Milestone 8 Interim Mp Branch Size

Date: 2026-06-04

- Worktree: `D:\flutter-mini-program-platform-mp-engine`
- Branch: `feature/mp-json-engine`
- Commit before Milestone 8 working-tree edits:
  `95d2cb2c3dcc00242c664341e485a2debdb35056`
- Host app: `hosts/super_app_host`
- Flutter: `3.38.9`
- Dart: `3.10.8`
- Scope: interim Mp fixtures are bundled and rendered by the base SDK before
  the old runtime path was removed.

Command:

```powershell
cd D:\flutter-mini-program-platform-mp-engine\hosts\super_app_host
flutter build apk --release --analyze-size --target-platform android-arm64
```

Result:

- Build result: PASS
- APK: `hosts\super_app_host\build\app\outputs\flutter-apk\app-release.apk`
- APK size: `22,462,797` bytes (`21.4MB` reported by Flutter)
- Size analysis file:
  `C:\Users\mehed\.flutter-devtools\apk-code-size-analysis_02.json`
- Size analysis JSON size: `10,372,568` bytes

Selected AOT symbol groups from this interim branch:

- `package:stac`: `994 KB`
- `package:stac_core`: `440 KB`
- `package:mini_program_sdk`: `206 KB`
- `package:dio`: `58 KB`

This was not the final reduction measurement because the old runtime path was
still present at that point.

## Milestone 9 Mp-Only Runtime Cleanup

Date: 2026-06-04

- Worktree: `D:\flutter-mini-program-platform-mp-engine`
- Branch: `feature/mp-json-engine`
- Commit before Milestone 9 working-tree edits:
  `6f87ca50b2b8caafa7b34aa348377c2b2f386548`
- Flutter: `3.38.9`
- Dart: `3.10.8`
- Base SDK dependency check: PASS
- Mp-only web release build: PASS
- Mp-only Windows release build: PASS

The base `mini_program_sdk` dependency graph contains none of:

- `stac`
- `stac_core`
- `dio`
- `cached_network_image`
- `flutter_svg`
- `shared_preferences`
- `sqflite`

### Mp-Only Host

```powershell
cd D:\flutter-mini-program-platform-mp-engine\hosts\mp_only_host
flutter build apk --release --analyze-size --target-platform android-arm64
```

- Build result: PASS
- APK: `hosts\mp_only_host\build\app\outputs\flutter-apk\app-release.apk`
- APK size: `16,503,270` bytes (`15.7MB` reported by Flutter)
- Size analysis file:
  `C:\Users\mehed\.flutter-devtools\apk-code-size-analysis_03.json`
- Size analysis JSON size: `5,441,466` bytes
- `package:mini_program_sdk`: `133 KB`
- Stac, Stac core, and Dio groups: absent

### Super App Host

```powershell
cd D:\flutter-mini-program-platform-mp-engine\hosts\super_app_host
flutter build apk --release --analyze-size --target-platform android-arm64
```

- Build result: PASS
- APK: `hosts\super_app_host\build\app\outputs\flutter-apk\app-release.apk`
- APK size: `22,462,797` bytes (`21.4MB` reported by Flutter)
- Size analysis file:
  `C:\Users\mehed\.flutter-devtools\apk-code-size-analysis_04.json`
- Size analysis JSON size: `10,372,656` bytes
- `package:stac`: `994 KB`
- `package:stac_core`: `441 KB`
- `package:mini_program_sdk`: `168 KB`
- `package:dio`: `58 KB`

### Comparison

- Mp-only host versus stable Stac baseline: `5,890,290` bytes smaller (`26.3%`)
- Mp-only host versus the pre-cleanup super app host: `5,959,527` bytes smaller
  (`26.53%`)

The dependency-cleanliness and release-size gates pass. Protected Firebase and
AWS host flows plus interactive Chrome, Android, and Windows runtime checks
remain release gates.
