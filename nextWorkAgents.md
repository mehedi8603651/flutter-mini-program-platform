# Next Work Agents

## Mission
This document is the handoff for the **next** implementation wave.
The local Flutter CLI foundation is already shipped. The next work must build
on that baseline instead of redesigning it again.

## not completed: for future can be add
Mp.lazy.chunk manual Load more v1 ✅
infinite scroll ❌
secure persistent session ❌
real video cache ❌
real image disk cache ❌
Mp.cache Dart authoring API ❌

## Future Lazy Loading Roadmap

Current shipped base:

- `Mp.lazy.section` is implemented as the first lazy primitive.
- It can hydrate from runtime cache, run existing Mp actions after first mount,
  write normalized action data into state, cache successful target state, retry
  failures, and render placeholder/error templates.
- It is intended for one lazy section or one cached action block, not large
  paged lists by itself.

### Done: `Mp.lazy.chunk` manual Load More v1

Goal: manual chunk/page loading with a `Load more` button.

Target flow:

```text
Open mini-program
  -> load chunk/page 1
  -> save page 1 to cache
  -> user taps Load More
  -> load page 2
  -> merge page 2 into targetState
  -> save page 2 to cache
```

Use cases:

```text
products list
news feed
messages
orders
comments
videos list metadata
search results
medium/large table rows
```

Public API direction:

```dart
Mp.lazy.chunk({
  required String id,
  required MpNode itemTemplate,
  required List<MpAction> initialActions,
  required List<MpAction> loadMoreActions,
  required String itemsState,
  String? cursorState,
  String? hasMoreState,
  String? statusState,
  String? cacheKeyPrefix,
  String bucket = 'data',
  MpNode? placeholder,
  MpNode? empty,
  MpNode? error,
  MpNode? loadingMore,
  MpNode? loadMore,
  MpNode? end,
  bool once = true,
  int retry = 0,
  Duration retryDelay = const Duration(milliseconds: 300),
})
```

Implementation rules:

- Keep existing `Mp.pagedBackendBuilder` working.
- Do not replace `Mp.pagedBackendBuilder` in this batch.
- Use existing Mp actions, especially current `backend.query` /
  `backend.loadMore` shapes.
- Do not invent `network.get`, `path`, or action-level `targetState`.
- Start with manual `Load more`; no viewport auto-load yet.
- Guard against duplicate in-flight initial loads and load-more requests.
- Merge page items into `itemsState` deterministically.
- Cache page/chunk data by page or cursor using `cacheKeyPrefix`.
- Hydrate cached page 1 immediately when available.
- Preserve cached visible content if refresh/load-more fails.
- Keep `session` and `video` buckets rejected for mini-program lazy cache.
- Treat videos list as JSON-safe metadata only; no video binary cache here.
- Add parser validation for item template, action JSON, state keys, cache keys,
  retry values, buckets, and unknown props.

Use `Mp.lazy.chunk` when data is repeated, large, dynamic, comes from a
backend/database, and needs pagination, Load more, or future infinite scroll.
Do not use it for login pages, small settings pages, static about pages, single
product/profile details, payment forms, fixed menus, or small local JSON lists.

### Recommended Next Batch 2: Auto Load On Scroll

Only build this after manual `Mp.lazy.chunk` is stable.

Goal: automatically trigger load more when the user nears the bottom of a
chunk/list viewport.

Implementation rules:

- Reuse `Mp.lazy.chunk` state/cache/action internals.
- Add threshold control, for example `loadMoreThresholdPx` or item threshold.
- Use an in-flight guard so scroll events cannot start duplicate requests.
- Respect `hasMoreState` and stop once there is no more data.
- Support retry and error templates without losing already loaded rows.
- Keep screen-level scrolling safe; avoid nested uncontrolled scroll views.
- Large/infinite lists should eventually graduate to `Mp.virtualList`.

### Later List Systems

After manual and auto lazy chunks:

- `Mp.virtualList` for very large feeds and search results.
- `Mp.dataTable` for large table data with columns, sort, and pagination.
- Optional search/filter helpers that write query state and refresh chunks.
- Optional skeleton presets for chunk rows/cards.
- Optional cache invalidation helpers for stale list pages.

## Active Architecture Wave: Mp JSON Engine

The next major architecture wave is the platform-owned Mp JSON engine:

```text
Mini-program Dart source using Mp.*
  -> mini_program_tooling build
  -> versioned Mp JSON
  -> mini_program_sdk parser + validator
  -> SDK-owned Mp renderer and design system
  -> Flutter core widgets
```

Implementation is now Mp-first. The old Stac runtime/builder path has been
removed from this repository; do not reintroduce it in new work.

Decision-complete roadmap:

- [docs/mp_json_engine_roadmap.md](docs/mp_json_engine_roadmap.md)

Milestone order:

1. roadmap, isolated worktree, and release-size baseline
2. contract metadata, extensible capabilities, and `mini_program_ui`
3. strict Mp parser, validator, renderer, core nodes, and theme tokens
4. navigation, backend, auth, paging, and asset parity
5. tooling build, scaffold, preview, validate, and publish migration
6. Mp publish and host E2E parity
7. Mp starter UI and VS Code workflow parity
8. fixture migration, documentation, and interim release-size comparison
9. remove old Stac runtime, builder, fixtures, and compatibility package
10. final release-size comparison and stable merge

Milestone 8 adds tracked Mp fixtures:

- `mini_programs/mp_profile_center`
- `mini_programs/mp_rewards_center`

The super host bundles both fixtures. The Mp-only reference host is
`hosts/mp_only_host`.

Do not publish the release packages before all release gates pass.

## Current Mp Engine Branch State

Milestone 9 is complete:

- `mini_program_sdk` is Mp-only by default
- the old Stac runtime, managed builder, fixtures, and compatibility package
  have been removed
- generated and managed-preview hosts are Mp-only
- `hosts/mp_only_host` is the dependency and size reference
- the Mp-only arm64 APK is `16,503,270` bytes, a `26.3%` reduction from the
  stable Stac baseline
- the base SDK dependency graph is free of Stac and its targeted transitive
  dependencies
- protected Firebase Mp-only E2E is complete against
  `miniprogram-backend-test`:
  - Firebase Functions deploy, Firestore seed, Firebase Hosting publish,
    protected access key, partner handoff, and host import passed
  - the live protected Mp screen and all paged `Load more` results passed in
    Chrome and Windows
  - the Android x64 debug APK built and installed; the emulator could not
    complete Firebase HTTPS requests through the current China/VPN route
- live verification fixed two tooling issues:
  - new Mp scaffolds now use the established `>=1.0.0 <2.0.0` runtime
    compatibility range
  - generated remote host endpoints now use explicit 20-second delivery and
    30-second publisher-backend timeouts

Milestone 10 cloud verification now includes:

- protected AWS delivery and publisher backend access-key enforcement
- AWS security matrix: public health `200`, missing key `401`, invalid key
  `403`, valid key `200`
- protected AWS Mp-only host flow with all paged Load more results in Chrome
  and Windows
- protected AWS Mp-only host flow confirmed by the user on physical Android
- protected Firebase Mp-only host flow in Chrome and Windows

The focused workflows and gates are documented in:

- [docs/mp_engine_cloud_e2e_guide.md](docs/mp_engine_cloud_e2e_guide.md)
- [docs/mp_engine_release_checklist.md](docs/mp_engine_release_checklist.md)

The next release step is to record the exact protected Firebase physical
Android run, execute the release verification script from a clean checkout,
confirm the reviewed stable versions, and prepare the stable release. Do not
publish packages before all required release gates pass.

Provider-neutral standalone API support is available through the contract
commands:

```text
miniprogram publisher-backend contract init
miniprogram publisher-backend contract validate
miniprogram publisher-backend contract smoke
miniprogram publisher-backend contract handoff
```

Use this path when the publisher already has a custom HTTPS server. The
mini-program keeps only relative endpoints; the handoff package carries
`backendBaseUrl` and optional access-key configuration into the host app.

## Next Architecture Wave: Provider-Neutral Publisher Backend

After the Mp engine release gates pass, the next major implementation wave is a
provider-neutral publisher backend foundation. It should let mini-program
developers build full web-style server systems without adding Firebase, AWS, or
other provider SDKs to the Flutter host app.

Decision-complete backend direction:

- [docs/publisher_backend_https_api_roadmap.md](docs/publisher_backend_https_api_roadmap.md)

Target architecture:

```text
Mp mini-program frontend
  -> mini_program_sdk provider-neutral HTTPS client
  -> publisher-owned standalone HTTPS server
  -> Firebase / AWS / Cloud Run / Docker / custom provider services
```

The host app remains lightweight. It knows only:

```text
appId
delivery API base URL
publisher backend base URL
MiniProgram access key
publisher auth session token when signed in
declared host capabilities
```

The host must not install publisher-specific Firebase, AWS, database, payment,
email, AI, or storage SDKs. A host can connect hundreds of mini-programs backed
by different providers without meaningful binary-size growth because every
publisher backend uses the same HTTPS boundary.

### Locked Backend Direction

- Business logic and provider credentials stay on the publisher server.
- Mini-program JSON must never directly call Firestore, DynamoDB, Firebase
  Admin, AWS SDKs, databases, or arbitrary provider APIs.
- Do not use hidden/custom Chromium as the mini-program backend runtime.
- Do not create an unrestricted generic proxy such as
  `POST /call-any-provider`.
- Publisher servers expose business-specific routes such as `/products`,
  `/orders`, `/profile`, `/support/tickets`, and `/files/upload-url`.
- Delivery, publisher backend, access-key policy, auth, and handoff formats
  remain provider-neutral.
- Firebase and AWS become deployment/runtime adapters around the same backend
  contract, not separate mini-program architectures.
- Native-sensitive features such as payments, camera, contacts, and push
  notifications still require explicit host capability and bridge contracts.

### Backend Scope

The first backend milestone should not create provider-specific runtime
packages. The first milestone should define a small protected HTTPS API
contract that any backend developer can implement with any stack:

```text
Node / Dart / Go / Java / Python / .NET / PHP
Firebase Functions / AWS Lambda / Cloud Run / Docker / VPS / Kubernetes
Firestore / DynamoDB / PostgreSQL / S3 / Stripe / email / SMS / AI APIs
```

Optional examples or templates can come later for Dart, Node, Firebase, AWS,
Cloud Run, Docker, or other targets. They are developer conveniences, not a new
mini-program backend architecture.

### Backend Contract V1

Standardize shared behavior before adding more generated routes:

```text
GET  /health
POST /auth/...
GET  /auth/session
GET  /<resource>?limit=<limit>&cursor=<cursor>
POST /files/upload-url
POST /jobs
GET  /jobs/<jobId>
```

Publishers can add custom routes:

```text
GET  /products
POST /orders
GET  /orders/<orderId>
POST /cart/items
POST /support/tickets
```

The contract must define:

- API and schema versioning
- consistent JSON success/error envelopes
- stable error codes and safe client messages
- request IDs and trace propagation
- access-key verification and partner isolation
- publisher-owned user auth and authorization
- cursor pagination
- idempotency keys for writes
- CORS and allowed headers
- payload, timeout, and rate-limit behavior
- signed upload URL flow for large files
- job IDs and polling for long-running work
- redaction rules for credentials, access keys, auth tokens, and provider
  errors

Realtime WebSocket or Server-Sent Events support is later work. Do not block
the initial custom-route release on realtime.

### Developer Experience Target

Dart example:

```dart
final app = MiniProgramBackend(appId: 'rewards');

app.get('/products', requireAccessKey: true, handler: listProducts);
app.post('/orders', requireAuth: true, handler: createOrder);
app.post('/payments/webhook', handler: paymentWebhook);

await app.serve();
```

Node/TypeScript example:

```typescript
const app = createMiniProgramBackend({ appId: "rewards" });

app.get("/products", requireAccessKey(), listProducts);
app.post("/orders", requireAuth(), createOrder);
app.post("/payments/webhook", verifyWebhook(), paymentWebhook);
```

Tooling should eventually expose:

```text
miniprogram publisher-backend create --runtime dart|node
miniprogram publisher-backend start
miniprogram publisher-backend validate
miniprogram publisher-backend smoke
miniprogram publisher-backend package --target docker|firebase|aws
miniprogram publisher-backend handoff
```

The CLI remains the source of truth. VS Code only wraps these commands.

### Implementation Milestones

1. Write a decision-complete backend HTTPS contract and threat model.
2. Add deterministic JSON fixtures and compatibility tests for the contract.
3. Update tooling to validate and smoke-test any backend URL that claims the
   contract.
4. Add generic handoff guidance for existing publisher backends.
5. Add optional starter templates for one or two popular stacks after the
   contract is stable.
6. Refactor generated Firebase and AWS publisher backends to match the shared
   contract without changing existing client behavior.
7. Add signed upload URL and background-job contract sections.
8. Add VS Code guided workflows and diagnostics around contract validation.
9. Verify one custom multi-provider backend, for example:

   ```text
   Cloud Run standalone server
     -> Firebase Auth
     -> PostgreSQL business data
     -> AWS S3 files
     -> external email/payment/AI APIs
   ```

10. Run protected host E2E in Chrome, Windows, and physical Android before
    stable release.

### Security And Release Gates

- No provider credential or database secret enters mini-program JSON, host
  source, APK, IPA, web JavaScript, partner handoff, logs, or diagnostics.
- Access keys remain partner revocation/identification tools, not permanent
  mobile secrets.
- Add short-lived signed host tokens, request signing, app/device attestation,
  quotas, rate limits, key expiry, and audit events as later hardening layers.
- Custom routes must use allowlisted HTTP methods, paths, payload limits, and
  response limits.
- Uploads use signed provider URLs; large files do not pass through the SDK as
  JSON.
- Long-running work returns a job ID; requests must not wait indefinitely.
- Firebase, AWS, and custom backends pass the same shared contract fixtures and
  smoke suite.
- A host with many providers must show no meaningful binary-size increase
  compared with the same host using one provider.
- Do not publish backend framework packages until Dart, Node, Firebase, AWS,
  Docker/custom-server, Chrome, Windows, and physical Android gates pass.

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
  - watch `manifest.json`, `mp/**`, `tool/build_mp.dart`, and `assets/**`
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
        accessKey: '<partner-access-key-for-aws-coupon-demo>',
      ),
      'gcp_rewards': MiniProgramEndpoint(
        apiBaseUri: Uri.parse('https://gcp.example.com/api/'),
        accessKey: '<partner-access-key-for-gcp-rewards>',
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

### Immediate Firebase Auth Design Work

AWS publisher backend work is mature. Firebase publisher backend work now has
the core production path plus publisher-to-host handoff and Firebase Hosting
static delivery:

- Firebase Functions + Firestore scaffold
- deploy/status/outputs
- read and write smoke tests
- Firestore seed/data status/export/import/redemptions
- guarded function destroy
- `publish --target firebase-hosting`
- `publisher-backend firebase host-command`
- `publisher-backend firebase handoff`
- VS Code Firebase Hosting publish UI
- VS Code Firebase host wiring UI with `hostEndpointReady` diagnostics
- VS Code Firebase handoff package UI

The publisher/host split is now clear:

- the mini-program publisher owns Firebase project, Firebase CLI login,
  Cloud Functions, Firestore, data, and backend secrets
- the host app developer owns Flutter host code and endpoint imports
- the host app developer should not need Firebase credentials, Firebase env
  state, Firebase SDKs, or publisher backend secrets

#### Done: mini_program_tooling 0.3.40 Firebase Hosting Static Delivery

Firebase Hosting static delivery is now the recommended Firebase delivery path
before creating a handoff package.

Implemented behavior:

- publish built manifest/screen/assets to Firebase Hosting
- return the delivery API base URL needed by `firebase handoff`
- keep Firestore/Functions business backend separate from static delivery
- support dry-run/preview output before deployment
- preserve existing public/static publish behavior for GitHub/CDN workflows
- keep `host run` usable for Firebase endpoint-map hosts without requiring an
  AWS cloud backend environment

#### Done: mini_program_vscode 0.1.32 Firebase Hosting Publish UI

VS Code now exposes Firebase Hosting delivery:

- publish current mini-program static delivery to Firebase Hosting
- show generated delivery URL
- offer "Create Firebase Host Handoff Package" as the next step
- keep host import provider-neutral

#### Next: Firebase Auth

Only start Firebase Auth once delivery/handoff is stable. The host should still
own user auth unless a mini-program has an explicit publisher-owned auth use
case. Any Firebase Auth feature must avoid putting publisher secrets in the
host app.

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
    host run, and access-key create/list/revoke/rotate commands.
17. Done through tooling `0.3.38`: Firebase Functions + Firestore publisher
    backend scaffold/deploy/status/outputs/smoke/write-smoke/seed/data
    export/import/redemptions/guarded destroy/host-command.
18. Done through VS Code `0.1.30`: Firebase host wiring UI and Windows-safe
    command execution for multi-word titles.
19. Done through tooling `0.3.39`: Firebase publisher handoff package.
20. Done through VS Code `0.1.31`: Firebase handoff package UI.
21. Done through tooling `0.3.40`: Firebase Hosting static delivery publish.
22. Done through VS Code `0.1.32`: Firebase Hosting publish UI with handoff next step.
23. Next: design Firebase Auth integration after delivery/handoff is stable.
24. Add optional auto-generated `requestId` support in author helpers.
