# mini_program_contracts Sub-Agent

## Mission
Define the shared language of the platform before any runtime or host behavior is implemented.

## Current Status
`mini_program_contracts` v1 exists and is the source of truth for the mobile MVP contract layer.

## Owns
- Manifest schema
- Capability names
- Action names
- Host action request/result envelopes
- SDK compatibility rules
- Stable error codes
- Feature flag keys

## Must Do
- Keep field names stable and explicit.
- Add every new capability or action here first.
- Make version compatibility easy to validate at runtime.
- Prefer portable contract terms over host-specific naming.

## Must Not Do
- Add runtime behavior here.
- Add app-specific business rules.
- Introduce undocumented or ad hoc string constants in other packages.

## Current Package Structure
- `pubspec.yaml`
- `analysis_options.yaml`
- `lib/mini_program_contracts.dart`
- `lib/manifest.dart`
- `lib/capability.dart`
- `lib/action_names.dart`
- `lib/action_payloads.dart`
- `lib/host_actions.dart`
- `lib/sdk_version.dart`
- `lib/error_codes.dart`
- `lib/feature_flags.dart`
- `test/`

## v1 Contract Surface
- Manifest contract: `MiniProgramManifest`, `MiniProgramFallback`, `MiniProgramFallbackStrategy`
- Capabilities: `auth`, `analytics`, `native_navigation`
- Actions: `openNativeScreen`, `trackEvent`
- Action payloads: `OpenNativeScreenActionPayload`, `TrackEventActionPayload`
- Host bridge envelope: `HostActionRequest`, `HostActionResult`, `HostActionStatus`
- SDK compatibility: `SdkVersionRange`
- Shared constants: `MiniProgramErrorCodes`, `FeatureFlagKey`

## Generated Files
- `*.freezed.dart` and `*.g.dart` are generated outputs.
- Do not hand-edit generated files.
- When source models change, run:
  - `dart run build_runner build --delete-conflicting-outputs`
  - `dart test`
  - `flutter analyze`

## Contract Extension Rules
- Add every new capability here before using it in the SDK, backend, hosts, or mini-programs.
- Add every new host action here before creating host bridge methods or Stac action parsers.
- Keep wire names stable once published.
- Prefer adding optional fields over breaking wire-shape changes.
- Do not add secrets or host-internal data models to this package.

## Files In Scope
- `lib/manifest.dart`
- `lib/capability.dart`
- `lib/action_names.dart`
- `lib/host_actions.dart`
- `lib/action_payloads.dart`
- `lib/sdk_version.dart`
- `lib/error_codes.dart`
- `lib/feature_flags.dart`

## Next Step
The next implementation phase is `packages/mini_program_sdk`.

The SDK should consume these contracts to add:
- `HostBridge` interface
- manifest loading/parsing
- SDK version compatibility checks
- capability matching
- host action dispatch using `HostActionRequest` / `HostActionResult`
- fallback error handling for unsupported manifests or capabilities
