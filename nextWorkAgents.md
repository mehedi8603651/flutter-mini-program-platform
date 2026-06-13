# Next Work Agents

This file is only for future work. Completed milestones, release evidence, and
old provider-backend experiments belong in changelogs or release notes, not
here.

## Architecture Rules

- Mini-program UI bundles are static frontend artifacts.
- Static artifacts can be served from local artifact hosting, CDN, object
  storage, Firebase Hosting, S3, or any simple HTTPS file host.
- Business logic belongs behind a separate provider-neutral Publisher API
  backend owned by the publisher.
- The Publisher API handles auth, database reads/writes, payments, file
  storage rules, admin logic, secrets, dynamic lists, and user actions.
- Mini-program JSON must never directly call Firestore, DynamoDB, Firebase
  Admin, AWS SDKs, databases, payment SDKs, or arbitrary provider APIs.
- Firebase and AWS may be used behind the Publisher API or as static artifact
  hosting targets, but they are not the platform's publisher backend model.
- The CLI remains the source of truth. VS Code should wrap CLI commands, not
  reimplement platform logic.

## Immediate Priorities

1. Harden the provider-neutral Publisher API contract.
2. Add lazy list improvements on top of `Mp.lazy.chunk`.
3. Add first-class cache authoring APIs.
4. Improve image/video caching without adding provider-specific backend logic.
5. Add future static artifact hosting providers after the contract is stable.

## Lazy Data Roadmap

`Mp.lazy.chunk` manual Load more v1 is available. Future work should build on
its state, cache, action, and duplicate-request guard internals.

### Auto Load On Scroll

Add automatic load-more behavior when the user nears the bottom of a list.

Requirements:

- Reuse `Mp.lazy.chunk` internals.
- Add a threshold option such as `loadMoreThresholdPx` or item threshold.
- Guard duplicate scroll-triggered requests.
- Respect `hasMoreState` and stop when no more data exists.
- Keep loaded rows visible when refresh or load-more fails.
- Avoid unsafe nested scrolling.
- Keep manual Load more behavior available.

### Larger List Systems

Add these only after auto load is stable:

- `Mp.virtualList` for very large feeds, search results, and long histories.
- `Mp.dataTable` for large table data with columns, sorting, and pagination.
- Search/filter helpers that write query state and refresh lazy chunks.
- Skeleton presets for chunk rows/cards.
- Cache invalidation helpers for stale list pages.

## Cache Roadmap

Add an authoring-level cache API that stays provider-neutral.

Future API direction:

- `Mp.cache.get`
- `Mp.cache.set`
- `Mp.cache.remove`
- `Mp.cache.clearPrefix`
- TTL support for safe cached data
- explicit buckets for safe runtime data
- no `session` or video-binary cache through generic mini-program cache

Rules:

- Do not cache secrets, auth tokens, payment state, or unrestricted backend
  responses.
- Keep cache keys validated and namespace-safe.
- Keep cache behavior deterministic for tests.

## Publisher API Contract Roadmap

The next backend work should focus on one stable HTTPS contract that any
publisher can implement with any stack.

Target runtime model:

```text
Mp mini-program frontend
  -> mini_program_sdk provider-neutral HTTPS client
  -> publisher-owned HTTPS Publisher API
  -> any provider or service
```

The host app should only need:

```text
appId
static artifact base URL
Publisher API base URL
MiniProgram access key
publisher auth session token when signed in
declared host capabilities
```

### Contract V1

Define stable behavior for:

- `GET /health`
- auth session/status endpoints
- cursor pagination
- safe JSON success/error envelopes
- stable error codes
- request IDs and trace propagation
- MiniProgram access-key verification
- publisher-owned user auth and authorization
- idempotency keys for writes
- CORS and required headers
- payload, timeout, and rate-limit behavior
- signed upload URL creation
- background job creation and polling
- redaction rules for provider errors, credentials, access keys, and auth
  tokens

Recommended business routes should be specific:

```text
GET  /products
POST /orders
GET  /orders/<orderId>
POST /cart/items
POST /support/tickets
POST /files/upload-url
```

Do not create generic unrestricted proxy routes such as:

```text
POST /call-any-provider
```

### Contract Tooling

Keep the active command surface provider-neutral:

```text
miniprogram publisher-api contract init
miniprogram publisher-api contract validate
miniprogram publisher-api contract smoke
miniprogram publisher-api contract handoff
```

Future work:

- add deterministic contract fixture tests
- add richer smoke-test cases for auth, pagination, writes, and errors
- add handoff guidance for existing publisher servers
- add optional example servers only after the contract is stable
- keep examples as implementation choices, not platform backend providers

## Auth And Session Roadmap

Add secure persistent session behavior through the Publisher API boundary.

Future work:

- define safe auth session response shapes
- support refresh/session-check flows
- keep tokens out of mini-program bindings and action results
- allow host-owned secure token storage
- support signed-out, signed-in, expired, and auth-error UI states
- document how Publisher API auth differs from MiniProgram access keys

## Media Roadmap

### Image Cache

Add real image disk cache support for safe public/static images.

Rules:

- HTTPS first; local loopback allowed only for preview.
- Respect cache headers or explicit safe TTL.
- Do not cache protected/private images unless the host opts into a secure
  storage policy.
- Keep cache size limits and eviction deterministic.

### Video Metadata And Playback

`Mp.lazy.chunk` can handle video feed metadata. Real video binary caching is
separate future work.

Rules:

- Keep video metadata as JSON-safe data.
- Add video playback only through explicit host capability.
- Do not put large video binaries into generic `Mp.cache`.
- Add download/offline behavior only after a clear storage and rights policy.

## Static Artifact Hosting Roadmap

Future provider work should stay about static artifact hosting, not business
backend logic.

Possible future targets:

- GCP Cloud Storage + CDN
- custom S3-compatible object storage
- static host/CDN adapter with user-supplied artifact base URL
- improved CloudFront or CDN automation for immutable artifact paths

Future artifact-host features:

- rollout rules for selecting active artifact versions
- host-aware selection
- capability filtering for manifest delivery
- deployment drift detection
- richer diagnostics for cloud stack updates
- multi-endpoint host consumption where one Flutter host can register many
  `appId -> static artifact URL + Publisher API URL + access key` entries

## Host-Native Capability Roadmap

Add sensitive capabilities only through explicit host bridge contracts.

Future capabilities:

- payment
- camera or scanner
- contacts
- push notifications
- banking-style secure actions
- TV navigation and subscription/recharge flows

Rules:

- Mini-program owns portable UI.
- Host-native SDK owns sensitive execution.
- Results return as structured payloads.
- Payments use Publisher API-created sessions and host/native execution.

## Native Host Roadmap

If Android native hosts are added later, start with:

- native app plus embedded Flutter runtime for mini-program surfaces
- prewarmed/reused Flutter engine where needed
- the same static artifact and Publisher API contracts

Do not start by building a second full native renderer unless real product and
performance evidence forces it.

## VS Code Roadmap

The extension should remain a CLI wrapper.

Future improvements:

- better status rendering from `workflow status --json`
- clearer Publisher API contract actions
- better static artifact hosting wording
- improved logs/output channel diagnostics
- guided import of handoff packages
- one-click smoke test for current mini-program + host endpoint

## Authoring Quality-Of-Life

Future small improvements:

- optional auto-generated `requestId` in author helpers
- better preview error overlays
- lower-latency preview refresh
- clearer diagnostics for artifact endpoint vs Publisher API endpoint
- zero-argument workflows when the current folder has enough context
- optional preview attachment such as
  `miniprogram preview -d chrome --host-app <path>`

## Deferred

- do not replace the CLI with a VS Code-only workflow
- do not move the platform to a WebView or WASM runtime as the main host model
- do not let mini-programs directly own secure payment or banking execution
- do not add provider-specific publisher backend command groups again
- do not build a marketplace before static artifact delivery, Publisher API,
  and host capability contracts are stable
