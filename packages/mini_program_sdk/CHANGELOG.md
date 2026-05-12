# Changelog

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
