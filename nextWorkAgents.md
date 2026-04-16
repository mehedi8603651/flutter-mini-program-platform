# Next Work Agents

## Mission
This document is the handoff for the **next** implementation wave.
The local Flutter CLI foundation is already shipped. The next work must build
on that baseline instead of redesigning it again.

## Current Shipped Baseline

These are already done and should be treated as stable unless a bug forces a
change:

- published packages:
  - `mini_program_contracts`
  - `mini_program_sdk`
  - `mini_program_tooling`
- global CLI:
  - `miniprogram create`
  - `miniprogram doctor`
  - `miniprogram env init|use|status`
  - `miniprogram build`
  - `miniprogram preview -d <chrome|windows>`
  - `miniprogram validate`
  - `miniprogram publish`
  - `miniprogram embed init`
  - `miniprogram backend init|start|stop|status|reset-local`
- standalone local backend workspace:
  - default Windows root at `%LOCALAPPDATA%\mini_program\backend\`
- target-aware local host behavior:
  - Android emulator default `10.0.2.2:8080`
  - desktop and Chrome default `127.0.0.1:8080`
  - Android USB support through `adb reverse`
- managed pinned Stac builder inside the tooling package
- managed preview host under `.mini_program/preview_host`
- internal preview server with watch, rebuild, and full preview refresh for
  Chrome and Windows
- hosted embed dependencies through `mini_program_sdk` and
  `mini_program_contracts`

## Locked Direction

### CLI stays the source of truth
- `miniprogram` remains the primary developer interface.
- Any future VS Code extension must wrap the CLI instead of duplicating the
  platform logic.
- CI/CD and non-VS-Code workflows must keep working from the CLI alone.

### Native power stays behind the bridge
- portable mini-program UI remains declarative
- secure and host-sensitive behavior remains native
- future payment, banking, TV, and secure API scenarios must expand the bridge
  and contracts, not bypass them

### Cloud delivery splits static and dynamic work
- static versioned artifacts belong in:
  - S3
  - CloudFront
- dynamic selection and secure operations belong in:
  - API Gateway
  - Lambda

### Native host expansion should reuse Flutter first
- if Android native hosts are added later, the first strategy should be:
  - native app + embedded Flutter runtime for mini-programs
- do not start by building a second full native renderer

## Priority Roadmap

### 1. Preview workflow expansion
Managed preview is now shipped for:

- `miniprogram preview -d chrome`
- `miniprogram preview -d windows`

Current preferred developer flow:

- `miniprogram create my_coupon_app`
- `cd my_coupon_app`
- `miniprogram preview -d chrome`

Already shipped behavior:

- infer the current mini-program from the working directory
- build the current mini-program automatically
- run a CLI-managed preview host automatically
- avoid requiring manual `backend init` or `backend start` for normal preview
- avoid publishing into `backend/api/` for the normal preview loop
- use current build artifacts directly for preview
- start or reuse a tiny internal preview transport when the target requires
  HTTP-style serving
- keep real backend flow separate for integration and delivery testing

Current preview-mode rules:

- this is a developer preview loop, not a replacement for real delivery
- Chrome and some device targets may still need an internal local preview
  server, but the developer should never manage it directly
- preview transport should be treated as tooling internals, not as a published
  backend workspace

Current watch and refresh behavior:

- watch `manifest.json`
- watch `stac/**`
- watch `assets/**`
- rebuild mini-program JSON on save
- keep the last successful preview running if a rebuild fails
- trigger a full preview refresh after a successful rebuild

Shipped per-target refresh behavior:

- Chrome: reload the browser tab
- Windows desktop: restart the preview window or recreate the preview route

Next preview work:

- Android emulator preview support
- Android USB physical-device preview support
- Android Wi-Fi physical-device preview support
- optional advanced form:
  - `miniprogram preview -d chrome --host-app <path>`
- lower-latency refresh and better preview error overlays where needed

### 2. Cloud publish and cloud env
After preview flow is stable, add cloud delivery support:

- `miniprogram publish --target cloud`
- `miniprogram env use cloud`

Expected architecture:

- S3 versioning for:
  - manifests
  - screens
  - themes
  - assets
- CloudFront in front of S3
- API Gateway + Lambda for:
  - discovery
  - rollout and host-aware selection
  - capability filtering
  - secure API routes

### 3. Payment and other host-native capabilities
Add new capabilities only through explicit contracts:

- `payment`
- future banking-style secure actions
- TV-focused navigation and subscription or recharge flows

Rules:

- mini-program owns the portable UI flow
- host-native SDK owns sensitive execution
- results return in structured payloads

### 4. Native host expansion
For future Java/Kotlin or other native hosts:

- embed the Flutter runtime first
- keep mini-program usage bounded to the mini-program surface
- prewarm and reuse the engine where needed
- only consider a second renderer if business and performance evidence force it

### 5. IDE UX layer on top of the CLI
After the CLI preview and cloud model are stable, a VS Code extension is a good
follow-up:

- command palette wrappers around CLI flows
- backend status and logs
- cloud target UI
- preview launch UI
- manifest and publish inspection

This remains a wrapper over the CLI, not a replacement for it.

### 6. Authoring quality-of-life
Smaller future UX improvements that fit the current system:

- make author helper `requestId` optional and auto-generate it when omitted
- improve generated logs and diagnostics for host/backend resolution
- keep zero-argument workflows when the current directory already provides
  enough context

## Deferred Or Explicitly Not Next

- do not replace the CLI with a VS Code-only workflow
- do not move the platform to a WebView or WASM runtime as the main host model
- do not let mini-programs directly own secure payment or banking execution
- do not build a third-party marketplace before cloud publish and host
  capabilities are stable

## Near-Term Concrete Task List

1. Extend `miniprogram preview` from Chrome and Windows to Android emulator
   targets on the same preview architecture.
2. Add physical-device preview support for Android USB and Wi-Fi flows.
3. Keep preview transport internal to the CLI-managed preview flow instead of
   publishing into `backend/api/` for the normal authoring loop.
4. Keep target-aware local backend defaults and device overrides inside the
   generated host runtime for real backend flows and advanced preview cases.
5. Add cloud publish support with S3 object layout and versioned keys.
6. Add API Gateway/Lambda-compatible cloud route design for discovery, latest,
   rollout, and secure routes.
7. Add first-class payment capability contracts and payload models.
8. Implement payment host bridge support in Flutter hosts first.
9. Plan Android native-host embedding around a reused Flutter engine.
10. Keep the CLI as the single source of truth before adding any IDE wrapper.
11. Add optional auto-generated `requestId` support in author helpers.
