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
- AWS cloud management through CLI:
  - `miniprogram cloud deploy`
  - `miniprogram cloud status`
  - `miniprogram cloud outputs`
  - `miniprogram cloud logs`
  - `miniprogram cloud destroy`
  - `miniprogram cloud doctor`
  - `miniprogram cloud rollback <version> [mini-program-id]`
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

### Host apps open by appId, not by raw API URL
- feature pages and buttons should keep the developer-friendly call shape:

```dart
openAppMiniProgram(
  context,
  appId: 'aws_coupon_demo',
  title: 'AWS Coupon Demo',
);

openAppMiniProgram(
  context,
  appId: 'gcp_rewards',
  title: 'GCP Rewards',
);
```

- do not add a required `api`, `url`, or backend endpoint parameter to every
  `openAppMiniProgram(...)` call
- the host runtime configuration should own endpoint routing, for example:

```dart
MiniProgramScope(
  config: buildMiniProgramConfig(
    endpoints: {
      'aws_coupon_demo': MiniProgramEndpoint(
        apiBaseUri: Uri.parse('https://aws.example.com/prod/api/'),
        accessKey: 'mpk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
      ),
      'gcp_rewards': MiniProgramEndpoint(
        apiBaseUri: Uri.parse('https://gcp.example.com/api/'),
        accessKey: 'mpk_live_yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy',
      ),
    },
  ),
  child: const MyApp(),
);
```

- practical partner flow should be:
  - partner A gives the host team `appId + API base URL + MiniProgram access key`
  - partner B gives the host team `appId + API base URL + MiniProgram access key`
  - the host registers those values once in config
  - app screens open each mini-program by `appId`
- this keeps one host app able to include mini-programs published by different
  developers on AWS, GCP, or custom servers without scattering provider URLs
  throughout Flutter UI code
- an optional `sourceId` or per-launch endpoint override can exist later for
  testing or advanced routing, but the recommended production API should stay:
  UI knows `appId`; config knows server/API and access key
- use the name `MiniProgram access key` for partner access control
- one mini-program should support multiple access keys, usually one key per
  host company, environment, or distribution partner
- all versions of a mini-program can share the same active access key unless a
  publisher intentionally rotates or revokes it
- if Company B should lose access, the mini-program owner revokes Company B's
  key only; Company A and Company C continue working with their own keys
- access keys should support at least:
  - create
  - revoke
  - rotate
  - optional expire time
  - audit metadata such as host company, environment, createdBy, revokedBy
- backend manifest and screen delivery should validate:
  - `appId`
  - `MiniProgram access key`
  - host app id
  - host version
  - SDK/runtime compatibility version
  - requested capabilities/platform where relevant
- access keys are access-control and revocation tools, not strong mobile
  secrets; APKs can be inspected, so secure payment/banking actions must still
  go through host-owned auth, backend, and bridge contracts

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
- `miniprogram cloud deploy|status|outputs|logs|destroy|doctor|rollback`
- `infra/aws/mini_program_cloud_api/template.yaml`

Next cloud provider work should be:

- `gcp`
- `custom-s3-compatible`
- multi-endpoint host consumption, where one Flutter host app can register
  multiple `appId -> API base URL + MiniProgram access key` mappings and open
  all of them through the same `MiniProgramScope`

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

- rollout rules and capability filtering in the cloud backend
- secure API route execution in Lambda
- GCP provider implementation
- custom S3-compatible provider implementation
- CloudFront provisioning and opinionated CDN setup automation
- SDK/tooling support for registering multiple remote mini-program endpoints in
  one host app and resolving each launch by `appId`
- cloud backend support for `MiniProgram access key` management, validation,
  revocation, rotation, and audit logs

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
After the CLI preview, AWS publish, access-key, partner package, and host
endpoint import flows are stable, a VS Code extension is a good follow-up.
The extension should be a native VS Code Activity Bar/sidebar extension first,
not a webview dashboard.

The required foundation is a CLI-first status layer, likely in tooling `0.3.9`:

- `miniprogram workflow status`
- `miniprogram workflow status --json`
- `miniprogram doctor --json`
- `miniprogram env status --json`
- `miniprogram backend status --json`
- `miniprogram cloud status --json`
- `miniprogram access-key list <mini-program-id> --json`

The human output should show what is ready, what is missing, and the next
recommended command. The JSON output should be stable enough for the extension
to render without scraping terminal text.

The workflow status command should detect at least:

- current workspace type:
  - mini-program
  - Flutter host app
  - unknown folder
- mini-program status:
  - `manifest.json` exists
  - build output exists
  - validation status
  - active cloud environment
  - API base URL configured
  - cloud catalog/release exists
  - active access-key count
  - nearby partner package files
- host app status:
  - `pubspec.yaml` exists
  - `miniprogram embed init` was run
  - generated runtime setup exists
  - generated endpoint map exists
  - endpoint count
  - configured backend/API status
  - suggested run/build command

VS Code extension MVP:

- Activity Bar icon: `MiniProgram`
- Sidebar sections:
  - Project
  - Workflow Status
  - Cloud / Backend
  - Access Keys
  - Host Apps
  - Logs
- Command Palette actions:
  - `MiniProgram: Create MiniProgram`
  - `MiniProgram: Build`
  - `MiniProgram: Validate`
  - `MiniProgram: Preview`
  - `MiniProgram: Publish`
  - `MiniProgram: Create Access Key`
  - `MiniProgram: Create Partner Package`
  - `MiniProgram: Import Host Endpoint`
  - `MiniProgram: Run Host App`
  - `MiniProgram: Refresh Status`
- Create flow:
  - ask user for target folder
  - ask for appId
  - ask for title
  - run `miniprogram create <appId> --title <title> --output-root <folder>/<appId>`
  - offer to open the created folder
- Status flow:
  - run `miniprogram workflow status --json`
  - render small status rows/cards in the sidebar
  - show next recommended action
  - keep raw command output in a MiniProgram output channel

The extension must call the CLI for real work. It must not reimplement create,
build, validate, publish, AWS, access-key, partner package, host endpoint, or
backend logic.

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
3. Done in tooling `0.3.6`: add host runtime support for multiple partner endpoints:
   `appId -> API base URL + MiniProgram access key`, keeping
   `openAppMiniProgram(...)` appId-only for normal UI code.
4. Partly done in tooling `0.3.6`: add `MiniProgram access key` management to
   AWS cloud backends with create, list, revoke, and rotate. Next: expire and
   audit per mini-program.
5. Done in tooling `0.3.7`: add partner handoff packages and host endpoint
   import, so publishers can share one JSON file per app/key and host apps can
   keep button code appId-only.
6. Add rollout rules and host-aware selection to the cloud backend.
7. Add capability filtering enforcement to cloud manifest delivery.
8. Add secure API route execution contracts and Lambda-side handlers.
9. Add deployment drift detection and richer stack update diagnostics for the
   AWS CLI cloud flow.
10. Keep target-aware local backend defaults and device overrides inside the
   generated host runtime for real backend flows.
11. Add first-class payment capability contracts and payload models.
12. Implement payment host bridge support in Flutter hosts first.
13. Plan Android native-host embedding around a reused Flutter engine.
14. Keep the CLI as the single source of truth before adding any IDE wrapper.
15. Done in tooling `0.3.9`: add workflow status and machine-readable `--json` output
    for doctor/env/backend/cloud/access-key status so a VS Code extension can
    render status without scraping terminal text.
16. Done in `packages/mini_program_vscode`: build a native VS Code
    Activity Bar/sidebar extension MVP that wraps CLI status plus core create,
    build, validate, preview, publish, host embed/init, host endpoint import/add,
    and host run commands.
17. Add optional auto-generated `requestId` support in author helpers.
