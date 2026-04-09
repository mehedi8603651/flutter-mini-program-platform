# mini_program_contracts

Shared contracts for the portable Flutter mini-program platform.

This package holds the stable language shared by mini-program authoring,
backend delivery, host apps, and runtime/tooling packages.

## What it exports

- manifest models and cache policy types
- capability enums
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
