# partner_app_host Sub-Agent

## Mission
Provide a clean reference host for third-party or external Flutter apps that want to consume the SDK.

## Current Status
`partner_app_host` now exists as a runnable Flutter app and proves the second
host integration path for:
- backend-delivered mini-program loading through `HttpMiniProgramSource`
- a smaller capability surface than `super_app_host`
- host-specific route alias mapping through a partner `HostBridge`
- rendering `profile_center` and `feedback_form` through backend-selected partner lanes
- controlled fallback handling for unsupported capabilities

## Owns
- Minimal host integration example
- Reference `HostBridge` implementation
- Capability declaration pattern for partner apps
- Example mini-program entry flow for non-first-party hosts

## Must Do
- Stay generic and easy to copy into another Flutter app.
- Demonstrate capability negotiation clearly.
- Keep the partner surface smaller than the first-party host unless a capability is truly portable.

## Must Not Do
- Depend on internal-only app services from `super_app_host`.
- Assume partner apps have the same auth, payment, or analytics stack.

## Design Intent
- This host proves the platform is portable beyond your own app.
- It should remain a template for "any Flutter app can adopt this SDK."
- The current delivery lane resolves `profile_center` `latest` to `1.0.0` for `partner_app_host`.
- It now sends explicit delivery context to backend `latest` routes: `hostApp`, `sdkVersion`, `hostVersion`, `platform`, `locale`, optional `tenantId`, and capabilities.

## Current Structure
- `pubspec.yaml`
- `lib/main.dart`
- `lib/app/app_routes.dart`
- `lib/app/partner_app_host_app.dart`
- `lib/bridge/host_bridge_impl.dart`
- `lib/capabilities/supported_capabilities.dart`
- `lib/mini_programs/mini_program_catalog.dart`
- `lib/mini_programs/source_configuration.dart`
- `lib/mini_programs/mini_program_list_page.dart`
- `lib/mini_programs/mini_program_entry_page.dart`
- `lib/mini_programs/native_feedback_desk_page.dart`
- `lib/mini_programs/native_profile_review_page.dart`
- `test/widget_test.dart`

## Next Step
Broaden the portability proof by adding another mini-program or by introducing a partner-specific capability gap that the backend and SDK must both respect.
