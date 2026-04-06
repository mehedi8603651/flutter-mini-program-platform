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
- `bin/inspect_delivery.dart`
  - Calls the local backend debug inspection route:
    `/api/debug/manifests/:miniProgramId/decision`
  - Accepts host delivery context such as `hostApp`, `sdkVersion`,
    `hostVersion`, `platform`, `locale`, `tenantId`, `pinnedVersion`, and
    `capabilities`.
  - Supports `text` and `json` output for local debugging and CI.

## Current Focus
- `validate_delivery`
- `inspect_delivery`
- `build_mini_programs`
- `validate_manifests`
- `smoke_test_host`

## Next Tooling Priorities
- host smoke-test wrappers
- secure API policy validation
