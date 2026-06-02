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
