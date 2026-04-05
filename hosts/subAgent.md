# hosts Sub-Agent

## Mission
Integrate the portable SDK into real Flutter apps while keeping host logic isolated behind a controlled bridge.

## Scope
- First-party host app: `super_app_host`
- Reference partner integration host: `partner_app_host`

## Must Do
- Install and wire the shared SDK.
- Implement `HostBridge` with explicit capability ownership.
- Keep auth, native navigation, analytics, and secure operations in the host layer.
- Make capability support explicit per host app.

## Must Not Do
- Let remote JSON trigger arbitrary native code.
- Leak host-specific business rules back into the SDK.
- Assume all partner apps support the same capability set as the first-party app.

## Mobile Focus
- `super_app_host` is the primary mobile app integration target.
- `partner_app_host` should stay minimal and portable so other Flutter apps can copy the pattern.
