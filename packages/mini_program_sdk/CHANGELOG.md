# Changelog

## 0.4.0

- add memory-only Mp state with `MpStore`, `MpStateManager`, `MpRouter`, and
  `MpActionRunner`
- add Mp `stateBuilder`, namespaced `state.*` and `route.*` bindings, state
  actions, router params/results, and action sequences
- make Mp JSON the only built-in screen renderer
- remove the old Stac runtime path and its transitive runtime dependencies from
  the base SDK
- add Mp runtime parity support for auth, backend data, paged backend data,
  bindings, and mini-program navigation
- add Mp-native runtime widgets and actions
- add the SDK Mp screen renderer seam and default renderer registry
- add strict Mp JSON validation and basic Flutter-core node rendering

## 0.3.7

- add `miniProgramPagedBackendBuilder` for lazy publisher backend lists that
  render item templates and keep loaded pages in SDK state
- add `miniProgramLoadMore` so mini-program UI can append the next backend page
  by request id
- expose paged backend bindings such as `items`, `itemCount`, `pageCount`,
  `hasMore`, `nextCursor`, and `loadingMore` without changing existing
  `miniProgramBackendBuilder` behavior

## 0.3.6

- add publisher-owned email/password auth runtime APIs with per-mini-program
  session caching
- add secure auth session storage, SDK auth actions/builders, and native email
  auth sheet support
- attach bearer tokens to publisher backend calls without exposing auth tokens
  through bindings or logs

## 0.3.5

- make `MiniProgramBackendEndpoint.enableLocalLoopbackFallback` active for
  publisher backend calls so local mock backend URLs can fall back between
  `127.0.0.1` / `localhost` and Android emulator `10.0.2.2`

## 0.3.4

- add `MiniProgramBackendStore`, `MiniProgramBackendSnapshot`,
  `MiniProgramBackendQuery`, and binding resolution for lazy publisher backend
  data state
- add `miniProgramBackendQuery` actions that call the existing publisher
  backend connector, store loading/success/error state by request id, and
  trigger bound UI rebuilds
- add `miniProgramBackendBuilder` for loading, error, child, empty, and simple
  repeated item templates with `{{backend.*}}` and `{{item.*}}` bindings

## 0.3.3

- add lazy publisher-owned backend connector APIs for mini-program server calls
  without putting publisher backend secrets in the host app
- extend `MiniProgramEndpoint` with optional `backend` configuration and
  route `miniProgramBackend` Stac actions by the current mini-program appId
- keep backend HTTP clients lazy, cache GET calls only with explicit TTL, reject
  absolute action URLs, and send delivery access keys to publisher backends only
  when explicitly enabled

## 0.3.2

- add the MiniProgram Tools VS Code Marketplace link and install command to
  the README so host app developers can discover guided setup and diagnostics

## 0.3.1

- add `MiniProgramEndpoint.public(...)` for public/static CDN, GitHub Pages,
  and demo mini-program delivery without a MiniProgram access key
- allow `MiniProgramEndpoint.accessKey` to be null for public endpoints while
  keeping protected endpoint access-key validation unchanged

## 0.3.0

- add `MiniProgramEndpoint` and `EndpointRoutingMiniProgramSource` so one host
  app can open many mini-programs from different API base URLs by appId
- add MiniProgram access key support through the
  `x-mini-program-access-key` HTTP request header
- document pairing this header with backend-side key validation for protected
  multi-publisher endpoints
- keep UI launch calls appId-only while endpoint config owns server/API and
  access-key routing

## 0.2.0

- add `MiniProgramScope`, `MiniProgramController`, `MiniProgramConfig`,
  `MiniProgramLaunchOptions`, and `MiniProgramLauncher` as the primary
  host-owned app integration API
- keep `MaterialApp`, router, theme, localization, state management, and
  navigator setup fully owned by the host app
- deprecate the free `openMiniProgram(...)` helper and
  `MiniProgramLauncherButton` in favor of scope-based launching
- add lazy runtime creation and owned-source disposal support

## 0.1.3

- replace the minimal spinner with a full-screen branded loading surface so
  cloud-hosted mini-program launches do not show a blank page during manifest
  and screen fetches
- make `MiniProgramPage` render a scaffolded loading state with the resolved
  mini-program title before the delivered screen is ready
- refresh README examples around generated host app usage and cloud backend
  build/run defines

## 0.1.2

- add `LocalMiniProgramBackendDefaults` so host apps can resolve target-aware
  local backend URLs from one shared SDK helper
- keep stable local defaults for Android emulator, desktop, Chrome on the same
  machine, and iOS simulators while preserving explicit base-URL and host/port
  override support
- document the local backend conditions for emulator, USB `adb reverse`, and
  physical-device Wi-Fi workflows

## 0.1.1

- add local loopback fallback in `HttpMiniProgramSource` so local Android
  development can retry between `10.0.2.2` and `127.0.0.1` when the first
  local backend transport path is unavailable
- add regression coverage for transport fallback while keeping normal HTTP
  backend error handling unchanged

## 0.1.0

- first public release of the portable Flutter mini-program runtime SDK
- add `MiniProgramRuntime`, `MiniProgramRuntimeScope`, and `MiniProgramPage`
- add `openMiniProgram(...)` and `MiniProgramLauncherButton`
- add manifest loading, capability validation, feature flags, and cache helpers
- add host bridge dispatch and Stac-based rendering support
