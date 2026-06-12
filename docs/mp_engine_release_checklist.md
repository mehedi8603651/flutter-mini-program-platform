# Mp Engine Release Checklist

Use this checklist before merging `feature/mp-json-engine` or publishing stable
Mp engine packages.

No release gate should run cloud destroy, data deletion, destructive cleanup,
or unreviewed production writes.

## Current Evidence

Recorded on 2026-06-05:

| Gate | Status | Evidence |
| --- | --- | --- |
| Base SDK excludes Stac and targeted transitives | Passed | `tools/verify_mp_engine_release.ps1` dependency check |
| Mp-only Android arm64 size | Passed | `16,503,270` bytes, 26.3% below stable Stac baseline |
| Firebase Hosting static delivery in Chrome | Needs current run | Static delivery only |
| Firebase Hosting static delivery in Windows | Needs current run | Static delivery only |
| AWS protected delivery in Chrome | Needs current run | Protected delivery and Publisher API contract |
| AWS protected delivery in Windows | Needs current run | Protected delivery and Publisher API contract |
| AWS protected Mp host on physical Android | Passed, user verified | Same imported protected handoff |
| Publisher API contract smoke | Needs current run | Provider-neutral middle-server contract |
| Firebase Hosting on physical Android | Needs final recorded run | Static delivery only |
| iOS | Not claimed | Must be verified before claiming iOS support |

## 1. Clean Branch

- [ ] Work only in `D:\flutter-mini-program-platform-mp-engine`.
- [ ] Branch is `feature/mp-json-engine`.
- [ ] `git status --short` is clean.
- [ ] No protected `.partner.json`, raw access key, auth token, or cloud
      credential is tracked.
- [ ] Stable worktree remains clean.

Commands:

```powershell
cd D:\flutter-mini-program-platform-mp-engine
git status -sb
git diff --check
git grep -n "mpk_live_" -- .
```

Review every access-key-shaped match. Synthetic test fixtures are allowed; live
keys are not.

## 2. Automated Verification

- [ ] Contracts tests and analyze pass.
- [ ] Pure-Dart UI tests and analyze pass.
- [ ] Base SDK tests and analyze pass.
- [ ] Tooling tests and analyze pass.
- [ ] VS Code tests pass.
- [ ] Mp-only, super app, and partner host tests pass.
- [ ] Mp fixtures build, validate, and static-publish.
- [ ] Base SDK dependency boundary check passes.

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\verify_mp_engine_release.ps1
```

## 3. Mp Runtime And Compatibility

- [ ] New mini-program scaffold defaults to `screenFormat: mp`.
- [ ] Mp build produces deterministic `mp/.build/screens`.
- [ ] Workflow status reports schema `1` and entry ready.
- [ ] Auth, backend, paging, assets, and navigation work through Mp JSON.
- [ ] Unsupported formats and schema versions fail safely.
- [ ] Mp-only host has no legacy adapter or Stac dependency.

## 4. Firebase Hosting Delivery Gate

- [ ] Build and validate Mp mini-program.
- [ ] Publish static delivery to Firebase Hosting.
- [ ] Create a Publisher API contract for the middle server if backend data is used.
- [ ] Contract validate and smoke pass.
- [ ] Create and import handoff.
- [ ] Chrome host passes.
- [ ] Windows host passes.
- [ ] Physical Android host passes.

Use [Mp engine cloud end-to-end guide](mp_engine_cloud_e2e_guide.md).

## 5. AWS Live Gate

- [ ] Build and validate Mp mini-program.
- [ ] Publish protected delivery to S3/API Gateway.
- [ ] Create a dedicated partner access key.
- [ ] Create a Publisher API contract for the middle server if backend data is used.
- [ ] Contract validate and smoke pass.
- [ ] Create and import protected handoff.
- [ ] Protected smoke passes and does not expose the raw key.
- [ ] Security matrix is `health 200`, missing key `401`, invalid key `403`,
      valid key `200`.
- [ ] Chrome host loads protected delivery and Publisher API data.
- [ ] Windows host loads protected delivery and Publisher API data.
- [ ] Physical Android host loads protected delivery and Publisher API data.

Use [Mp engine cloud end-to-end guide](mp_engine_cloud_e2e_guide.md).

## 6. Size And Dependency Gate

- [ ] Build Mp-only Android arm64 release with `--analyze-size`.
- [ ] Record APK size, commit, Flutter version, and analysis file.
- [ ] Compare against the stable Stac baseline.
- [ ] Confirm Stac dependencies are absent from the Mp-only host.
- [ ] Build the super app host separately for the full reference app size.

Commands:

```powershell
cd D:\flutter-mini-program-platform-mp-engine\hosts\mp_only_host
flutter build apk --release --analyze-size --target-platform android-arm64

cd D:\flutter-mini-program-platform-mp-engine\hosts\super_app_host
flutter build apk --release --analyze-size --target-platform android-arm64
```

Record results in [Mp engine size baseline](mp_engine_size_baseline.md).

## 7. Documentation And Version Gate

- [ ] Root README describes Mp as the default engine.
- [ ] Authoring docs cover `Mp.*`, auth, backend, paging, and navigation.
- [ ] Publisher API, AWS delivery, and Firebase Hosting docs match current CLI help.
- [ ] Release checklist evidence is current.
- [ ] Changelogs describe public behavior.
- [ ] Package versions match the reviewed stable release versions.
- [ ] Pub package dry-runs pass before publishing.
- [ ] VS Code VSIX builds and installs locally.

Do not publish until every required gate is checked and the feature branch is
reviewed for stable merge.

## 8. Final Merge Decision

- [ ] Required Chrome, Windows, and Android delivery/API gates pass.
- [ ] Known limitations are documented.
- [ ] No live secret is present in Git history.
- [ ] No destructive cloud command was used during verification.
- [ ] Stable branch merge plan and rollback tag are prepared.
- [ ] Package publish order is documented.

Recommended publish order after the stable merge:

```text
mini_program_contracts
mini_program_ui
mini_program_sdk
mini_program_tooling
mini_program_vscode
```
