# super_app_host Sub-Agent

## Mission
Implement the first-party Flutter host app that proves the end-to-end mobile mini-program flow.

## Current Status
`super_app_host` now exists as a runnable Flutter app and proves the first
local host integration path for:
- host capability registration
- concrete `HostBridge` wiring
- asset-backed `MiniProgramSource` delivery
- local backend HTTP delivery through `HttpMiniProgramSource`
- mini-program list and entry flow
- host-owned native route handling for `openNativeScreen`
- loading a built snapshot from `mini_programs/profile_center`
- SDK fallback handling for an explicit unsupported-capability demo

## Owns
- Host app shell integration
- `HostBridge` implementation for the primary app
- Capability registration
- Mini-program discovery and entry pages
- First-party analytics and auth wiring

## Must Do
- Be the main proof-of-value host for the SDK.
- Start with a small, predictable set of capabilities.
- Keep app-specific business logic inside this host, not in shared packages.

## Must Not Do
- Become the default assumption for every partner integration.
- Expose unrestricted bridge power just because the app is first-party.

## MVP Direction
- Validate one mini-program locally first.
- Prefer auth, analytics, and native navigation before harder capabilities like payment.

## Current Structure
- `pubspec.yaml`
- `lib/main.dart`
- `lib/app/app_routes.dart`
- `lib/app/super_app_host_app.dart`
- `lib/bridge/host_bridge_impl.dart`
- `lib/capabilities/supported_capabilities.dart`
- `lib/mini_programs/local_mini_program_catalog.dart`
- `lib/mini_programs/local_mini_program_source.dart`
- `lib/mini_programs/source_configuration.dart`
- `lib/mini_programs/mini_program_list_page.dart`
- `lib/mini_programs/mini_program_entry_page.dart`
- `lib/mini_programs/native_profile_editor_page.dart`
- `test/widget_test.dart`

## Runtime Rules
- Keep host-specific routing and analytics logic inside this app.
- Expose only approved bridge actions already defined in contracts.
- Treat this app as the first proof host, not as the default for all partner hosts.
- Map portable route aliases to host-native routes inside `HostBridge`, not inside the mini-program source.
- Keep the host asset snapshot in sync with the real built output from `mini_programs/profile_center` by using `tools/sync_assets.ps1`.
- Default to bundled assets for predictable local runs, and opt into local backend mode with `SUPER_APP_SOURCE_MODE=local_backend`.
- In local backend mode, target the real Dart service in `backend/local_backend_service`, not a generic static file server.

## Next Step
Keep the real local backend service, then add version selection, rollout rules, and capability-aware delivery to it.
