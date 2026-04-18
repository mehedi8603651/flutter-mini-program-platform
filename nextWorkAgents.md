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
  - `miniprogram preview -d <supported-device>`
  - `miniprogram validate`
  - `miniprogram publish`
  - `miniprogram embed init`
  - `miniprogram backend init|start|stop|status|reset-local`
- standalone local backend workspace:
  - default Windows root at `%LOCALAPPDATA%\mini_program\backend\`
- managed preview flow:
  - `miniprogram create my_coupon_app`
  - `cd my_coupon_app`
  - `miniprogram preview -d chrome`
- managed preview targets:
  - Chrome
  - Edge
  - Windows
  - Linux
  - macOS
  - iOS simulator on macOS
  - Android emulator
  - Android USB physical device
  - Android Wi-Fi physical device
- preview behavior:
  - infer the current mini-program from the working directory
  - build the current mini-program automatically
  - run a CLI-managed preview host automatically
  - avoid requiring manual `backend init` or `backend start` for normal preview
  - avoid publishing into `backend/api/` for the normal preview loop
  - use current build artifacts directly for preview
  - watch `manifest.json`, `stac/**`, and `assets/**`
  - rebuild on save and trigger full preview refresh
  - keep the last successful preview running if a rebuild fails
- preview transport behavior:
  - desktop and web preview default to localhost
  - Android emulator prefers `adb reverse` and falls back to `10.0.2.2`
  - Android USB uses `adb reverse` plus `127.0.0.1`
  - Android Wi-Fi uses the detected or overridden LAN host IP
- target-aware local backend behavior for real delivery testing:
  - desktop and Chrome default `127.0.0.1:8080`
  - Android emulator supports `10.0.2.2:8080`
  - Android USB support through `adb reverse`
- managed pinned Stac builder inside the tooling package
- managed preview host under `.mini_program/preview_host`
- internal preview server with watch, rebuild, and full preview refresh for
  the managed preview flow
- hosted embed dependencies through `mini_program_sdk` and
  `mini_program_contracts`
- named cloud environments in CLI state:
  - `miniprogram env init`
  - `miniprogram env configure <env-name> --provider aws`
  - `miniprogram env list`
  - `miniprogram env use <env-name>`
  - `miniprogram env status`
- AWS cloud publish:
  - `miniprogram publish --target cloud`
  - `miniprogram publish --target cloud --env <env-name>`
  - versioned S3 artifact upload
  - release and catalog metadata upload
- deployable AWS cloud backend under:
  - `infra/aws/mini_program_cloud_api/`
  - AWS SAM template
  - API Gateway HTTP API
  - Lambda reading the published S3 artifact and metadata layout
  - backend-compatible routes for discovery, manifests, screens, debug, and
    health

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

### 1. Cloud publish and cloud env
Preview is shipped. The first AWS cloud path is also shipped:

- `miniprogram env init`
- `miniprogram env configure <env-name> --provider <provider>`
- `miniprogram env list`
- `miniprogram env use <env-name>`
- `miniprogram env status`
- `miniprogram publish --target cloud`
- `miniprogram publish --target cloud --env <env-name>`

Current shipped AWS pieces:

- `miniprogram env configure my-aws-prod --provider aws`
- `miniprogram publish --target cloud`
- `infra/aws/mini_program_cloud_api/template.yaml`

Next cloud provider work should be:

- `gcp`
- `custom-s3-compatible`

Important modeling rule:

- provider and environment are different concerns
- `aws-prod`, `aws-staging`, `gcp-dev`, and similar named environments should
  be first-class
- `publish --target cloud` should use the active cloud environment by default
  and allow `--env` as an override
- do not make raw `--provider aws|gcp|...` the main publish interface

Expected architecture:

- object storage with version-aware release handling for:
  - manifests
  - screens
  - themes
  - assets
- CDN in front of object storage
- dynamic gateway and serverless compute for:
  - discovery
  - rollout and host-aware selection
  - capability filtering
  - secure API routes

Provider mapping in v1:

- `aws`:
  - S3
  - CloudFront
  - API Gateway
  - Lambda
- `gcp`:
  - Cloud Storage
  - Cloud CDN
  - API Gateway
  - Cloud Run or Cloud Functions
- `custom-s3-compatible`:
  - S3-compatible object storage
  - user-supplied CDN base URL
  - user-supplied API base URL

Release and storage rules:

- publish immutable release paths per mini-program version
- treat bucket object versioning as recovery and rollback protection, not the
  primary release model
- use rollout or discovery metadata to point hosts at the active release
- prefer versioned file or path names over CDN invalidation as the default
  update strategy

What is still not done on the cloud path:

- CLI-driven provisioning or deployment of the AWS SAM stack
- rollout rules and capability filtering in the cloud backend
- secure API route execution in Lambda
- GCP provider implementation
- custom S3-compatible provider implementation
- CloudFront provisioning and opinionated CDN setup automation

### 2. Payment and other host-native capabilities
Add new capabilities only through explicit contracts:

- `payment`
- future banking-style secure actions
- TV-focused navigation and subscription or recharge flows

Rules:

- mini-program owns the portable UI flow
- host-native SDK owns sensitive execution
- results return in structured payloads

### 3. Native host expansion
For future Java/Kotlin or other native hosts:

- embed the Flutter runtime first
- keep mini-program usage bounded to the mini-program surface
- prewarm and reuse the engine where needed
- only consider a second renderer if business and performance evidence force it

### 4. IDE UX layer on top of the CLI
After the CLI preview and cloud model are stable, a VS Code extension is a good
follow-up:

- command palette wrappers around CLI flows
- backend status and logs
- cloud target UI
- preview launch UI
- manifest and publish inspection

This remains a wrapper over the CLI, not a replacement for it.

### 5. Authoring quality-of-life
Smaller future UX improvements that fit the current system:

- make author helper `requestId` optional and auto-generate it when omitted
- improve generated logs and diagnostics for host/backend resolution
- keep zero-argument workflows when the current directory already provides
  enough context
- optional advanced preview attachment such as:
  - `miniprogram preview -d chrome --host-app <path>`
- lower-latency refresh and better preview error overlays where needed

## Deferred Or Explicitly Not Next

- do not replace the CLI with a VS Code-only workflow
- do not move the platform to a WebView or WASM runtime as the main host model
- do not let mini-programs directly own secure payment or banking execution
- do not build a third-party marketplace before cloud publish and host
  capabilities are stable

## Near-Term Concrete Task List

1. Add `gcp` cloud publish and matching cloud backend deployment path.
2. Add `custom-s3-compatible` cloud publish and API configuration model.
3. Add rollout rules and host-aware selection to the cloud backend.
4. Add capability filtering enforcement to cloud manifest delivery.
5. Add secure API route execution contracts and Lambda-side handlers.
6. Decide whether the CLI should deploy or update the AWS SAM backend
   directly.
7. Keep target-aware local backend defaults and device overrides inside the
   generated host runtime for real backend flows.
8. Add first-class payment capability contracts and payload models.
9. Implement payment host bridge support in Flutter hosts first.
10. Plan Android native-host embedding around a reused Flutter engine.
11. Keep the CLI as the single source of truth before adding any IDE wrapper.
12. Add optional auto-generated `requestId` support in author helpers.
