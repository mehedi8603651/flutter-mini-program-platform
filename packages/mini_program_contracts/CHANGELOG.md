# Changelog

## 0.2.1

- default missing `screenFormat` to `mp` with schema version `1`

## 0.2.0

- add `screenFormat` and `screenSchemaVersion` manifest metadata for the Mp JSON engine
- default missing `screenFormat` to legacy `stac`
- switch manifest required capabilities to value-based capability IDs
- add dotted capability IDs for future optional media/document/browser features
- keep the old `Capability` enum as deprecated compatibility API

## 0.1.1

- add `endpoint_not_configured` for host runtime endpoint routing failures
- add MiniProgram access key error codes for backend delivery authorization

## 0.1.0

- add manifest models and SDK version helpers
- add stable action names and typed payload models
- add capability, feature flag, and error code contracts
- add internal mini-program navigation payload models
