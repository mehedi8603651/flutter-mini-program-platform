# Changelog

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
