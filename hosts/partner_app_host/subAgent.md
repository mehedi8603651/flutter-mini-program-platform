# partner_app_host Sub-Agent

## Mission
Provide a clean reference host for third-party or external Flutter apps that want to consume the SDK.

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
