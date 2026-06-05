# mini_program_contracts

Shared contracts for the portable Flutter mini-program platform.

This package holds the stable language shared by mini-program authoring,
backend delivery, host apps, and runtime/tooling packages.

## What it exports

- manifest models and cache policy types
- value-based capability IDs
- screen format metadata for Mp JSON screens
- stable action names
- typed action payload models
- host action request/result envelopes
- mini-program screen navigation payloads
- SDK semver compatibility helpers
- stable error codes and feature flag keys

## Who should depend on it

- runtime and tooling packages that need to read or validate mini-program
  manifests
- backend packages that serve or validate contract data
- host apps that implement typed bridge payloads

Most application code should depend on a higher-level package such as the SDK
or tooling package. Depend on `mini_program_contracts` directly when you need
the shared wire-level types and constants.

## Screen formats

Mp JSON is the default screen format. Missing values decode as `mp` with
schema version `1`. Manifests may declare the format explicitly:

```json
{
  "screenFormat": "mp",
  "screenSchemaVersion": 1
}
```

Unknown non-empty screen format strings are preserved so SDKs can show a
controlled unsupported-format error.

## Capability IDs

New code should use `CapabilityId` strings and the constants in
`CapabilityIds`, for example `CapabilityIds.auth` or
`CapabilityIds.mediaVideo`. The old `Capability` enum remains available as a
deprecated compatibility API while the Mp engine branch migrates callers.
