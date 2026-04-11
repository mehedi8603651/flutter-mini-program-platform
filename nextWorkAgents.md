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

### 1. Managed preview workflow
The next major developer-facing feature should be:

- `miniprogram run -d chrome`
- `miniprogram run -d windows`
- `miniprogram run -d emulator-5554`
- `miniprogram run -d <physical-device-id>`

Expected behavior:

- infer the current mini-program from the working directory
- start the local backend if needed
- build and publish to the local backend automatically
- run a CLI-managed preview host app automatically
- keep backend URL selection target-aware

Optional advanced form:

- `miniprogram run -d chrome --host-app <path>`

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

1. Design the managed preview host for `miniprogram run -d <device>`.
2. Implement `miniprogram run` so it starts backend, builds, publishes, and
   launches preview automatically.
3. Keep target-aware local backend defaults and device overrides inside the
   generated host runtime.
4. Add cloud publish support with S3 object layout and versioned keys.
5. Add API Gateway/Lambda-compatible cloud route design for discovery, latest,
   rollout, and secure routes.
6. Add first-class payment capability contracts and payload models.
7. Implement payment host bridge support in Flutter hosts first.
8. Plan Android native-host embedding around a reused Flutter engine.
9. Keep the CLI as the single source of truth before adding any IDE wrapper.
10. Add optional auto-generated `requestId` support in author helpers.
