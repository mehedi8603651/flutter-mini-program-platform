# Packages Sub-Agent

## Purpose
Own shared packages that define the platform language, runtime, and tooling.

## Scope
- `mini_program_contracts`
- `mini_program_sdk`
- `mini_program_tooling`

## Rules
- Contracts come first. Do not let SDK or tooling invent names that are not defined in contracts.
- Keep package boundaries strict. Shared logic belongs in packages, not in hosts or mini-program folders.
- Avoid host-specific code in `packages/`.
- Prefer small stable interfaces over early abstraction.

## Delivery Order
1. Build `mini_program_contracts`.
2. Build the `mini_program_sdk` shell around those contracts.
3. Add `mini_program_tooling` only after the contract and SDK flow are clear.
