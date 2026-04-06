# mini_program_tooling Sub-Agent

## Mission
Provide repeatable developer and CI tooling for build, validation, publishing, and smoke testing.

## Owns
- Build automation
- Manifest validation helpers
- Capability and action validation
- Packaging helpers
- Publish helpers
- Host smoke-test helpers

## Must Do
- Treat Stac CLI output paths as tool-managed until verified locally.
- Prefer validation and reporting over hidden mutation.
- Keep tooling usable by both local developers and CI.

## Must Not Do
- Hardcode unverified Stac output folders.
- Recreate contract logic separately when it can be shared from packages.
- Assume one backend environment or one host app forever.

## Current Tool
- `bin/validate_delivery.dart`
  - Validates authored manifests and backend delivery files before runtime.
  - Checks published manifest/screen linkage, rollout rule versions, and
    capability-policy query requirements.
  - Also validates secure API policy files such as endpoint naming, allowlists,
    and minimum payload rules.
- `bin/inspect_delivery.dart`
  - Calls the local backend debug inspection route:
    `/api/debug/manifests/:miniProgramId/decision`
  - Accepts host delivery context such as `hostApp`, `sdkVersion`,
    `hostVersion`, `platform`, `locale`, `tenantId`, `pinnedVersion`, and
    `capabilities`.
  - Supports `text` and `json` output for local debugging and CI.
- `bin/create_mini_program.dart`
  - Generates a buildable starter mini-program under `mini_programs/<id>/`.
  - Emits the starter manifest, pubspec, default Stac options, starter screen,
    README, and placeholder folders for assets/components/theme.
  - Validates mini-program IDs and current capability wire values before
    writing files.
- `bin/build_mini_program.dart`
  - Builds a mini-program through the available Stac CLI path.
  - Prefers an explicit script path, then vendored `stac-dev`, then a global
    `stac` command.
  - Runs `dart pub get` in the mini-program package by default and verifies the
    expected entry screen JSON after the build.
- `bin/publish_mini_program.dart`
  - Chains build, validation, and local backend publish into one safe command.
  - Stops before publish if validation has errors.
  - Re-validates after copying artifacts into `backend/api/`.

## Current Focus
- `create_mini_program`
- `build_mini_program`
- `publish_mini_program`
- `validate_delivery`
- `inspect_delivery`
- `build_mini_programs`
- `validate_manifests`
- `smoke_test_host`

## Next Tooling Priorities
- host smoke-test wrappers
- publish pipeline integration
