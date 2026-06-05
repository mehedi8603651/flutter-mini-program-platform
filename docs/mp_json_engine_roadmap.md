# Mp JSON Engine Roadmap

## Goal

Use a small platform-owned JSON engine while preserving the published delivery,
backend, auth, access-key, and
host-handoff workflows.

The target pipeline is:

```text
Mini-program Dart source using Mp.*
  -> mini_program_tooling build
  -> versioned Mp JSON
  -> mini_program_sdk parser + validator
  -> SDK-owned Mp renderer and design system
  -> Flutter core widgets
```

The SDK owns one consistent visual system. Mini-program authors use `Mp.*`
components instead of Material, Cupertino, or host-specific widgets. Host apps
continue to embed mini-programs through the existing SDK boundary.

The Mp frontend stays declarative and frontend-only. Publisher business logic
runs behind a protected HTTPS API owned by the publisher. The future backend
direction is tracked in
[Publisher backend HTTPS API roadmap](publisher_backend_https_api_roadmap.md).
For custom backends, Mp screens use only relative endpoints and the host
handoff supplies `backendBaseUrl`; Firebase and AWS are optional deployment
helpers, not requirements of the Mp runtime.

## Development Rules

Develop this engine on the isolated `feature/mp-json-engine` worktree until it
is merged back to the main repository.

Use these reviewed release versions after the migration passes all release
gates:

```text
mini_program_contracts 0.2.0
mini_program_ui 0.1.0
mini_program_sdk 0.4.0
mini_program_tooling 0.4.0
mini_program_vscode 0.2.0
```

Before publishing, verify the release gates with path overrides in local host
apps and test workspaces.

## Contracts

Extend mini-program manifests with explicit screen format metadata:

```json
{
  "screenFormat": "mp",
  "screenSchemaVersion": 1
}
```

Compatibility rules:

- A missing `screenFormat` means `mp`.
- New scaffolds default to `mp`.
- `screenSchemaVersion` defaults to `1` for Mp manifests and must be positive
  when present.
- Unsupported formats or schema versions render a controlled SDK error.

Use a stable Mp screen document:

```json
{
  "schemaVersion": 1,
  "screenId": "coupon_home",
  "root": {
    "type": "column",
    "props": {},
    "children": []
  }
}
```

Replace the closed capability enum with a value-based capability ID while
preserving existing wire values:

```text
auth
analytics
secure_api
native_navigation
media.video
document.pdf
browser.webview
```

## Authoring Package

Add `mini_program_ui`, a small pure-Dart package. It must not depend on
Flutter, Material, Cupertino, analyzer, or build_runner.

Authors write:

```dart
Mp.column(
  children: [
    Mp.heading('Publisher account'),
    Mp.text('Sign in to continue'),
    Mp.primaryButton(
      label: 'Sign in',
      action: Mp.auth.showEmailAuth(),
    ),
  ],
)
```

Use an explicit screen registry:

```dart
final miniProgram = MpProgram(
  screens: {
    'coupon_home': buildCouponHome,
    'coupon_details': buildCouponDetails,
  },
);
```

Scaffold `tool/build_mp.dart`. Tooling runs this local Dart entrypoint and
writes deterministic artifacts:

```text
mp/.build/screens/<screenId>.json
```

## SDK Runtime

Add a renderer abstraction:

```dart
abstract interface class MiniProgramScreenRenderer {
  String get screenFormat;
  Set<int> get supportedSchemaVersions;
  Widget render(MiniProgramRenderRequest request);
}
```

Implement the SDK-owned `MpScreenRenderer`. Its first stable component set
includes:

```text
text
heading
image
icon
sizedBox
padding
row
column
stack
scrollView
list
card
divider
primaryButton
secondaryButton
authBuilder
backendBuilder
pagedBackendBuilder
loading
empty
error
```

Preserve current behavior:

- publisher-owned email auth, cached login, and bearer headers
- public and protected delivery access keys
- backend actions and bindings
- paged lists and Load more
- screen navigation and cache fallback
- Firebase, AWS, static delivery, and host handoff

Add controlled theme tokens to the manifest:

```text
colors
typography scale
spacing scale
radius scale
light and dark values
```

The SDK owns component structure and interaction behavior. Hosts cannot replace
the design system. Accessibility scale, safe areas, and platform input behavior
remain host-compatible.

## Security Defaults

Validate Mp JSON before rendering:

- maximum payload: `1 MiB` per screen
- maximum nodes: `2000`
- maximum depth: `64`
- maximum direct children: `500`
- maximum literal text: `32 KiB`
- maximum URL length: `2048`
- allow `https` assets
- allow `http` assets only for local preview loopback
- allowlist node types, properties, actions, and binding namespaces
- never execute downloaded Dart, JavaScript, or arbitrary expressions
- reject duplicate extension node registrations
- show a controlled fallback for unsupported nodes or capabilities

## Optional Features

Define `MpRendererExtension` and capability registration in the core engine.
Do not implement media features during the first migration.

Future opt-in packages:

```text
mini_program_feature_video
mini_program_feature_pdf
mini_program_feature_webview
```

Hosts add these packages at compile time. They support lazy initialization and
lazy network fetching, not runtime Dart code downloads.

## Runtime Dependency Boundary

The base `mini_program_sdk` owns the Mp renderer and no longer ships the old
Stac runtime, builder, or compatibility package. Hosts install the lightweight
base SDK and open Mp JSON screens only.

## Tooling Migration

Update tooling incrementally:

1. Add Mp build support selected by manifest `screenFormat`.
2. Make create and scaffold default to `mp`.
3. Watch `mp/**`, `manifest.json`, and `assets/**` during Mp preview.
4. Resolve `mp/.build` in workflow status and diagnostics.
5. Copy engine-neutral screen JSON during validate, local publish, static
   publish, Firebase Hosting publish, and AWS publish.
6. Generate Firebase and AWS starter UI with `Mp.*`.
7. Show the screen format in VS Code status rows while keeping VS Code as a
   CLI wrapper.

## Milestones

1. Add this roadmap, create the worktree, and record the release-size baseline.
2. Add contract metadata, extensible capabilities, and `mini_program_ui`.
3. Add strict Mp validation, renderer registration, and core nodes.
4. Reach navigation, backend, auth, paging, and asset parity.
5. Add Mp tooling build and preview support.
6. Prove Mp publish and host E2E parity.
7. Add Mp starter UI and VS Code workflow parity.
8. Add migration fixtures, documentation, and interim size comparison.
9. Remove the old Stac runtime, builder, fixtures, and compatibility package.
10. Complete final size/live release gates and merge the feature branch.

Commit each milestone separately.

Milestone 9 removed the old Stac runtime/builder path from this repository.
Milestone 10 has passed the Mp-only size gate and protected Firebase/AWS Chrome
and Windows flows. The protected AWS physical Android flow is user-verified. Use the
[Mp engine release checklist](mp_engine_release_checklist.md) to record the
remaining provider/platform evidence and prepare the stable merge.

## Test Plan

Run package tests after every milestone:

```powershell
dart test packages\mini_program_contracts
dart test packages\mini_program_ui
flutter test packages\mini_program_sdk
dart test packages\mini_program_tooling
npm test --prefix packages\mini_program_vscode
```

Add coverage for:

- Mp JSON serialization and validation limits
- fallback from a missing `screenFormat` to Mp schema version `1`
- Mp renderer components and binding parity
- auth, protected access keys, backend queries, and paged lists
- unsupported schemas, nodes, actions, and capabilities
- base SDK dependency graph without Stac transitives
- deterministic `mp/.build` output
- Firebase and AWS delivery-layout compatibility

Release blockers:

- protected Firebase host flow in Chrome and Android
- AWS host flow in Chrome and Android
- Windows desktop host verification
- release-size comparison using Flutter's
  [`--analyze-size`](https://docs.flutter.dev/perf/app-size) workflow
- Mp base host is no larger than the current baseline, with measured reduction
  recorded
- no package publish until all gates pass

## Assumptions

- The CLI remains the source of truth. VS Code remains a wrapper.
- Delivery screen JSON, publisher backends, auth, access keys, and handoff
  remain provider-neutral.
- Production publisher backend calls use HTTPS. HTTP is only for local preview
  or loopback development.
- The SDK owns one consistent Mp visual system.
- iOS verification is required before claiming iOS support, but does not block
  the initial Chrome, Android, and Windows release gate.
- Flutter reference material:
  - [App-size analysis](https://docs.flutter.dev/perf/app-size)
  - [Deferred components](https://docs.flutter.dev/perf/deferred-components)
  - [Widget rendering](https://api.flutter.dev/flutter/widgets/Widget-class.html)
