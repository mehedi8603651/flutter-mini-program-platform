# mini_program_sdk Sub-Agent

## Mission
Build the portable runtime that validates, loads, renders, and safely bridges mini-programs inside Flutter host apps.

## Current Status
`mini_program_sdk` v1 exists and provides the first local proof path for:
- manifest loading through a host-provided source
- HTTP-backed manifest and screen loading through `HttpMiniProgramSource`
- manifest query-parameter support for backend delivery context
- SDK version validation
- capability validation
- feature-flag gating
- Stac initialization and entry-screen rendering
- approved host action dispatch for `openNativeScreen` and `trackEvent`
- controlled loading and fallback error UI
- basic SDK logging

This package is the **Phase 2 SDK skeleton** from the root `AGENTS.md`.
It is intentionally not the full backend-delivery or caching runtime yet.

## Owns
- `HostBridge`
- `MiniProgramHost`
- Manifest loading
- Version validation
- Capability checks
- Stac initialization
- Safe action dispatch
- Fallback UI
- Basic SDK logging

## Must Do
- Fail early on incompatible SDK or capability requirements.
- Keep native power behind the host bridge.
- Show controlled fallback UI for unsupported or broken flows.
- Log failures with stable error codes from contracts.

## Must Not Do
- Hardcode `super_app_host` behavior into the SDK.
- Call sensitive native features directly from remote JSON.
- Hide compatibility or validation failures.

## Current Package Structure
- `pubspec.yaml`
- `analysis_options.yaml`
- `lib/mini_program_sdk.dart`
- `lib/mini_program_host.dart`
- `lib/host_bridge.dart`
- `lib/capability_registry.dart`
- `lib/feature_flag_evaluator.dart`
- `lib/manifest_loader.dart`
- `lib/version_validator.dart`
- `lib/sdk_context.dart`
- `lib/mini_program_failure.dart`
- `lib/actions/`
- `lib/network/`
- `lib/observability/`
- `lib/rendering/`
- `lib/widgets/`
- `test/`

## Current File Notes
- `lib/network/mini_program_source.dart` defines the source contract for both asset and HTTP loaders.
- `lib/network/http_mini_program_source.dart` provides the current backend-facing sample loader for static or server-hosted JSON delivery.
- `lib/network/mini_program_source_exception.dart` carries backend rejection details and transport failures into SDK fallback UI.
- `lib/cache/` is intentionally a placeholder. Persistent cache work is deferred until later phases.
- `lib/rendering/stac_initializer.dart` owns the current parser/action initialization path.
- `lib/observability/sdk_logger.dart` provides logging only. Error reporting and tracing are future additions, not current guarantees.

## v1 Runtime Surface
- Host widget: `MiniProgramHost`
- Host bridge: `HostBridge`
- Source contract: `MiniProgramSource`
- Backend loader: `HttpMiniProgramSource`
- Validation helpers: `VersionValidator`, `CapabilityRegistry`
- Runtime scope: `MiniProgramSdkScope`
- Stac bridge action: `hostAction`
- Host action dispatcher: `HostActionDispatcher`
- Default UI: `SdkLoadingView`, `SdkErrorView`
- Logging: `SdkLogger`

## Runtime Rules
- Always validate manifest SDK range before rendering.
- Always validate required capabilities before rendering.
- Treat manifest feature flags as hard gates when an evaluator is provided.
- Only dispatch approved contract actions through `HostBridge`.
- Use `HostActionRequest` and `HostActionResult` for bridge handoff.
- Keep Stac custom action support inside the SDK, not in host apps.
- Keep backend format assumptions out of the SDK except for explicit contracts and `MiniProgramSource`.
- Keep screen loading version-aware. Hosts may ignore version for bundled assets, but backend loaders must not.
- Pass host delivery context to backend loaders explicitly instead of hardcoding backend-side assumptions in widgets.
- Preserve backend rejection messages and transport failures as structured source errors so hosts get controlled fallback UX on real devices.
- Keep auth passive in v1. `Capability.auth` may be validated, but auth bridge APIs are not part of this package yet.

## Deferred Until Later Phases
- Persistent manifest, screen, and asset caching
- Backend client helpers such as `mini_program_api.dart`
- Auth header injection and asset resolution helpers
- Broader parser and widget fallback registries
- Error reporting and trace context plumbing
- Additional bridge actions such as payment or secure API calls

These are valid future additions, but they should not be added until the current host proof is working end to end.

## Tests and Verification
- `flutter test`
- `flutter analyze`

## Next Step
The next implementation phase is backend-driven multi-version delivery.

That phase should keep using this SDK while adding:
- multiple published manifest versions
- backend-side version selection and rollout behavior
- host verification that different backend contexts can return different `latest` manifests
- caching only after delivery and fallback behavior are stable
