# AGENTS.md

## Project: Portable Flutter Mini-Program Platform

**Goal:** build a portable mini-program platform where one mini-program can run inside multiple Flutter host apps through a shared SDK/runtime.

**Core stack:** Flutter + Stac + backend manifest delivery + host-specific native bridges.

**Primary outcome:** portable, safe, versioned, server-delivered UI flows.

---

## 0. Read This First

This repository is **not** a normal single-app Flutter project.
It is a **platform repository** with five separate concerns:

1. **Contracts** - shared language used by all parts of the platform
2. **SDK/runtime** - rendering engine installed by host apps
3. **Mini-program source** - portable UI flows written in Stac DSL
4. **Host apps** - real Flutter apps that consume the SDK
5. **Backend delivery** - manifest, JSON, rollout, and asset distribution

The most important design rule is:

> Keep portable UI declarative, keep native power behind a bridge, and keep host-specific logic out of mini-program definitions.

---

## 1. Non-Negotiable Truths

### 1.1 What this system is good at
Use this platform for:
- forms
- onboarding
- profile/settings flows
- simple product or recharge flows
- campaign pages
- dashboards
- modular business workflows
- tenant-specific or app-specific presentation changes
- remote UI updates without shipping a full app release

### 1.2 What this system is not good at
Do **not** force this platform into:
- advanced editors
- drag and drop builders
- Figma-like or canvas-like interactions
- game-like UIs
- highly custom animations everywhere
- map-heavy real-time views
- camera-heavy flows as primary UI
- complex platform SDK screens that are tightly native

Those should remain native Flutter screens exposed through the host bridge.

### 1.3 Critical correction about Stac
Do **not** assume this workflow:

`arbitrary normal Flutter widgets -> stac build -> JSON`

That assumption is too optimistic and should be treated as **invalid for platform design**.

For portable mini-program UI, the safe working assumption is:

`Stac DSL / StacWidget-based Dart -> stac build -> JSON`

Agents and developers must write mini-program UI using Stac DSL patterns, Stac-prefixed widgets, supported parsers, and registered custom actions/widgets.

### 1.4 Docs mismatch warning
Current Stac docs are useful, but some pages show different generated output paths:
- some docs show generated files in `stac/.build/`
- some docs show generated files in `build/screens/` and `build/themes/`

Treat generated output paths as **tool-managed**.
Do not hardcode folder assumptions without verifying the installed Stac CLI behavior in the real project.

---

## 2. Architecture in One Picture

```text
[Developer writes Stac DSL mini-programs]
              |
              v
        [stac build]
              |
              v
 [JSON screens + themes + manifest metadata]
              |
              v
      [backend/CDN/API delivery]
              |
              v
        [mini_program_sdk]
              |
              v
 [Host app + HostBridge + capability registry]
              |
              v
     [Rendered UI + controlled native actions]
```

---

## 3. Recommended Monorepo Structure

```text
flutter-mini-program-platform/
├── packages/
│   ├── mini_program_contracts/
│   │   ├── lib/
│   │   │   ├── manifest.dart
│   │   │   ├── capability.dart
│   │   │   ├── sdk_version.dart
│   │   │   ├── action_names.dart
│   │   │   ├── result_payloads.dart
│   │   │   ├── error_codes.dart
│   │   │   └── feature_flags.dart
│   │   └── pubspec.yaml
│   │
│   ├── mini_program_sdk/
│   │   ├── lib/
│   │   │   ├── mini_program_host.dart
│   │   │   ├── host_bridge.dart
│   │   │   ├── capability_registry.dart
│   │   │   ├── manifest_loader.dart
│   │   │   ├── version_validator.dart
│   │   │   ├── feature_flag_evaluator.dart
│   │   │   ├── sdk_context.dart
│   │   │   ├── cache/
│   │   │   │   ├── manifest_cache.dart
│   │   │   │   ├── screen_cache.dart
│   │   │   │   └── asset_cache.dart
│   │   │   ├── network/
│   │   │   │   ├── mini_program_api.dart
│   │   │   │   ├── auth_header_provider.dart
│   │   │   │   └── asset_resolver.dart
│   │   │   ├── rendering/
│   │   │   │   ├── stac_initializer.dart
│   │   │   │   ├── parser_registry.dart
│   │   │   │   ├── action_registry.dart
│   │   │   │   └── widget_fallbacks.dart
│   │   │   ├── actions/
│   │   │   │   ├── host_action_dispatcher.dart
│   │   │   │   ├── open_payment_action.dart
│   │   │   │   ├── open_native_screen_action.dart
│   │   │   │   ├── call_secure_api_action.dart
│   │   │   │   └── analytics_action.dart
│   │   │   ├── widgets/
│   │   │   │   ├── sdk_product_card.dart
│   │   │   │   ├── sdk_error_view.dart
│   │   │   │   └── sdk_loading_view.dart
│   │   │   └── observability/
│   │   │       ├── sdk_logger.dart
│   │   │       ├── error_reporter.dart
│   │   │       └── trace_context.dart
│   │   └── pubspec.yaml
│   │
│   └── mini_program_tooling/
│       ├── bin/
│       ├── lib/
│       └── pubspec.yaml
│
├── mini_programs/
│   ├── food_order/
│   │   ├── stac/
│   │   │   ├── screens/
│   │   │   ├── components/
│   │   │   └── theme/
│   │   ├── assets/
│   │   ├── manifest.json
│   │   └── README.md
│   │
│   ├── recharge/
│   ├── profile_center/
│   └── feedback_form/
│
├── hosts/
│   ├── super_app_host/
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── app/
│   │   │   ├── bridge/
│   │   │   │   └── host_bridge_impl.dart
│   │   │   ├── capabilities/
│   │   │   └── mini_programs/
│   │   │       ├── mini_program_list_page.dart
│   │   │       └── mini_program_entry_page.dart
│   │   └── pubspec.yaml
│   │
│   └── partner_app_host/
│       ├── lib/
│       │   ├── main.dart
│       │   ├── bridge/
│       │   │   └── host_bridge_impl.dart
│       │   ├── capabilities/
│       │   └── mini_programs/
│       └── pubspec.yaml
│
├── backend/
│   ├── api/
│   │   ├── manifests/
│   │   ├── screens/
│   │   ├── themes/
│   │   ├── capability-policies/
│   │   └── rollout-rules/
│   ├── storage/
│   ├── pipelines/
│   └── README.md
│
├── tools/
│   ├── build_mini_programs.sh
│   ├── validate_manifests.sh
│   ├── publish_mini_programs.sh
│   ├── smoke_test_host.sh
│   └── sync_assets.sh
│
├── docs/
│   ├── architecture.md
│   ├── host_bridge_contract.md
│   ├── manifest_spec.md
│   ├── rollout_plan.md
│   ├── testing_strategy.md
│   ├── security_model.md
│   └── known_limitations.md
│
└── AGENTS.md
```

---

## 4. What Each Layer Does

### 4.1 `packages/mini_program_contracts`
This package is the **shared language** of the platform.

#### Responsibilities
- define manifest schema
- define capability names
- define action names
- define result payload contracts
- define SDK compatibility rules
- define stable error codes
- define feature flag keys

#### Why it exists
Without this package, the SDK, backend, mini-programs, and host apps will drift apart.
That drift is the fastest way to create runtime breakage.

#### Rule
Every new capability, action, or payload contract must be added here first.

---

### 4.2 `packages/mini_program_sdk`
This package is the **portable runtime engine**.

Any host app that wants mini-program support installs this package.

#### Responsibilities
- load manifest and screen JSON
- validate SDK version and feature compatibility
- compare required capabilities with host support
- initialize Stac parsers and action parsers
- render portable UI safely
- dispatch custom actions to the host bridge
- cache manifests/screens/assets when appropriate
- show controlled fallback UI when something fails
- log and report rendering or integration failures

#### The SDK must not do
- hardcode one host app's business rules
- call native platform features directly without a bridge
- assume one backend format without contracts
- hide compatibility failures

---

### 4.3 `mini_programs/`
This folder contains actual mini-program source units.

Each mini-program should be portable and self-contained.

#### Responsibilities
- Stac screen definitions
- reusable components for that mini-program
- theme references
- assets
- manifest metadata
- mini-program-specific documentation

#### Recommended local structure per mini-program
- `stac/screens/` for flows and entry points
- `stac/components/` for reusable parts
- `stac/theme/` for theming
- `assets/` for local images/icons
- `manifest.json` for metadata and requirements
- `README.md` for dev notes and supported behaviors

#### Manifest should include at minimum
- `id`
- `version`
- `entry`
- `requiredCapabilities`
- supported SDK version range
- optional feature flags
- optional fallback behavior metadata

---

### 4.4 `hosts/`
These are real Flutter apps consuming the runtime.

#### Responsibilities
- install `mini_program_sdk`
- implement `HostBridge`
- declare supported capabilities
- provide native flows and secure operations
- own auth/session state
- own host-specific analytics wiring
- own host navigation shell
- own device permission policy

#### Rule
Mini-programs must never directly know a host app implementation.
They only talk through the bridge and declared capabilities.

---

### 4.5 `backend/`
This is the delivery and rollout side.

#### Responsibilities
- host manifest and JSON payloads
- host themes and assets
- return latest, pinned, or rollout-gated versions
- enable tenant or app-specific delivery rules
- enable feature flags and staged rollout
- optionally enforce capability-aware delivery

#### Backend must answer questions like
- which mini-program version should this host app receive?
- is this version enabled for this user segment?
- which assets belong to this version?
- should this screen be cached aggressively or treated as sensitive?

---

### 4.6 `tools/`
This folder is for automation, repeatability, and CI/CD.

#### Responsibilities
- build mini-program artifacts
- validate manifests
- validate action names and capability usage
- package assets
- publish artifacts to backend or CDN
- run smoke tests against host apps
- help agents produce predictable changes

---

## 5. AI Agent Map

This project is intended to be built with **you + AI agents**.
Use agents to accelerate structured work, but do not let agents invent platform contracts.

### 5.1 Contract Agent
**Focus:** contracts package, manifest schema, action names, version rules

#### Good tasks
- add or update manifest fields
- add new capability enums
- add stable error codes
- document compatibility rules

#### Must not do
- create undocumented action names
- bypass version rules

---

### 5.2 SDK Agent
**Focus:** runtime package, rendering flow, caching, validation

#### Good tasks
- implement `MiniProgramHost`
- add manifest loading and version checks
- add fallback UI and error paths
- register parsers and action parsers

#### Must not do
- add host-specific business logic into the SDK

---

### 5.3 Host Integration Agent
**Focus:** host app setup, bridge implementation, capability registration

#### Good tasks
- implement `host_bridge_impl.dart`
- wire analytics, auth, and native navigation
- register supported capabilities

#### Must not do
- expose unrestricted platform access
- let JSON call arbitrary native code

---

### 5.4 Mini-Program Authoring Agent
**Focus:** Stac DSL screens, components, theme references

#### Good tasks
- create Stac DSL screens
- refactor common UI blocks into reusable components
- wire supported Stac actions or approved custom actions

#### Must not do
- assume arbitrary Flutter widgets can be serialized
- add unsupported widget types without parser registration

---

### 5.5 Backend Delivery Agent
**Focus:** publishing, manifests, rollout rules, asset delivery

#### Good tasks
- expose manifest endpoints
- expose screen/theme endpoints
- add rollout gating and version pinning

#### Must not do
- serve incompatible versions without explicit fallback handling

---

### 5.6 QA and Observability Agent
**Focus:** tests, logs, traces, fallback verification

#### Good tasks
- verify happy path and failure path
- verify incompatible capability handling
- verify stale cache behavior
- verify unsupported widget/action diagnostics

#### Must not do
- mark a feature complete without failure-path coverage

---

## 6. Runtime Flow

### 6.1 Authoring
A developer or agent writes Stac DSL source under `mini_programs/<id>/stac/`.

### 6.2 Build
`stac build` produces generated JSON artifacts.

### 6.3 Validate
Manifest, version rules, capability declarations, and action names are checked.

### 6.4 Publish
Manifest, screens, themes, and assets are uploaded to backend/CDN.

### 6.5 Discover
A host app requests available mini-program metadata.

### 6.6 Validate in host
The SDK checks:
- manifest integrity
- SDK compatibility
- required capabilities
- rollout and feature flags

### 6.7 Load screen
The SDK fetches the entry screen and related assets/themes.

### 6.8 Render
Stac renders the screen into Flutter widgets using registered parsers.

### 6.9 Interact
User actions trigger built-in or custom action parsers.

### 6.10 Native work
Sensitive or host-specific work is delegated to the `HostBridge`.

### 6.11 Continue
The result payload can return to the portable flow to continue the user journey.

---

## 7. HostBridge Design

`HostBridge` is the most important contract in the whole platform.

It is the only safe bridge between portable UI definitions and host-native capabilities.

### Example shape

```dart
abstract class HostBridge {
  Future<String?> getAccessToken();
  Future<Map<String, dynamic>?> getCurrentUser();
  Future<void> openPayment(Map<String, dynamic> params);
  Future<Map<String, dynamic>?> pickImage();
  Future<void> openNativeScreen(String route, Map<String, dynamic> args);
  Future<Map<String, dynamic>?> callSecureApi(String endpoint, Map<String, dynamic> body);
  void trackEvent(String name, Map<String, dynamic> data);
}
```

### Rules for the bridge
- keep it small
- keep it stable
- keep it versioned
- expose only approved capabilities
- return structured payloads, not random blobs when avoidable
- document every bridge method and expected error case

### Never allow through the bridge
- arbitrary method execution
- unrestricted file system access
- unrestricted native plugin access from raw JSON
- dynamic code execution
- hidden host-only side effects not declared by capability or action contract

---

## 8. Capability System

Mini-programs declare what they need.
Hosts declare what they support.
The SDK compares the two before rendering.

### Example capabilities
- `auth`
- `payment`
- `storage`
- `camera`
- `location`
- `analytics`
- `secure_api`
- `native_navigation`
- `webview`

### Required behavior
If a mini-program requires `payment` and the host app does not support it, the SDK must not silently continue.
It must reject early and show controlled fallback UX.

### Rule
Capabilities are platform contracts, not UI hints.
Treat them as enforcement points.

---

## 9. Versioning Rules

Versioning must be treated as a first-class concern.

### There are at least three versions to care about
1. mini-program version
2. SDK/runtime version
3. contracts/schema version

### Rules
- every manifest must declare supported SDK range
- incompatible manifests must be rejected early
- breaking contract changes require version bump
- host apps must not auto-accept unknown contract versions

### Practical rule
Fail fast during validation, not late during rendering.

---

## 10. Caching and Offline Strategy

Caching is useful, but must be intentional.

### Cache candidates
- stable informational screens
- reusable assets
- low-risk UI layouts
- previously visited screens that are safe to reuse

### Avoid or heavily control caching for
- sensitive financial screens
- auth bootstrap screens
- flows whose correctness depends on fresh server state
- one-time or security-sensitive decisions

### Rule
Caching policy must be defined by contract or manifest metadata, not guessed ad hoc in host code.

### Important note
Even if Stac supports caching strategies, do not let the platform rely on caching before versioning and fallback paths are solid.

---

## 11. Security Model

This platform is safer when it is boring.

### Security principles
- JSON should describe UI and approved actions, not arbitrary power
- all sensitive work must go through vetted bridge methods
- backend should avoid serving incompatible or forbidden flows
- host apps should enforce capability allowlists
- logs should avoid leaking secrets or raw tokens

### Never do these
- allow raw backend URL injection for secure operations without policy
- allow arbitrary JavaScript/native bridging as a shortcut
- pass secrets into reusable JSON payloads if avoidable
- trust remote payloads as if they were local code

---

## 12. Testing Strategy

Testing is required across layers.

### Contract tests
- manifest parsing
- version compatibility
- capability matching
- action name validation

### SDK tests
- manifest loading success/failure
- fallback rendering
- unsupported widget/action handling
- cache hit and miss behavior

### Host integration tests
- bridge method invocation
- result payload handling
- permission-denied scenarios

### Mini-program tests
- basic DSL validity
- supported action usage
- entry screen existence

### End-to-end tests
- one happy path demo
- one failure path demo
- one unsupported capability demo
- one stale cache or version mismatch demo

---

## 13. What Should Be Native Flutter vs Stac

### Use Stac for
- simple pages
- layout-heavy screens
- text/image/button compositions
- forms and lightweight workflows
- promo/configuration steps
- tenant-specific presentation variations

### Use native Flutter for
- login bootstrap
- navigation shell
- payment SDK screens
- camera or file picker flows
- maps and tracking
- advanced real-time graphics
- advanced editors
- device-permission orchestration

### Golden rule
If the feature is mostly layout plus flow, Stac is a good candidate.
If the feature depends heavily on platform APIs, complex local state, or custom rendering, keep it native.

---

## 14. Impossible or Risky Assumptions

These assumptions should be treated as wrong unless proved in the real codebase.

### 14.1 Impossible assumption
**"We can write any normal Flutter widget tree and automatically ship it as Stac JSON."**

Why it is wrong:
- Stac authoring is based on Stac DSL and StacWidget-compatible definitions
- unsupported widgets require explicit parser support
- complex Flutter trees do not become portable automatically

### 14.2 Risky assumption
**"If it works in Host App A, it will automatically work in Host App B."**

Why it is risky:
- host apps may differ in capabilities
- bridge behavior may differ
- permission models may differ
- analytics or secure API expectations may differ

### 14.3 Risky assumption
**"Caching means the platform automatically has good offline support."**

Why it is risky:
- some flows require freshness
- asset availability may differ
- first-load offline experience still needs preloaded content
- version mismatches can break reused cached screens

### 14.4 Risky assumption
**"AI agents can finish the whole platform correctly without strong contracts."**

Why it is risky:
- agents are fast at scaffolding, but platform breakage often comes from contract drift
- inconsistent naming or version rules will create runtime failures that are hard to debug

---

## 15. Where To Start

Build the system in this exact order.

### Phase 1 - Contracts first
Build first:
1. `mini_program_contracts`
2. manifest schema
3. capability names
4. action names
5. result payload contracts
6. SDK compatibility rules

**Why:** this defines the language of the platform.

---

### Phase 2 - SDK skeleton
Build next:
1. `mini_program_sdk`
2. `HostBridge`
3. `MiniProgramHost`
4. manifest loader
5. version validator
6. capability checker
7. Stac initializer
8. fallback error UI

**Goal:** one host app can validate and render one simple screen.

---

### Phase 3 - First host app
Build next:
1. `hosts/super_app_host`
2. `host_bridge_impl.dart`
3. capability registration
4. mini-program list page
5. mini-program entry page
6. one native capability such as analytics or auth

**Goal:** host app can open one mini-program via SDK.

---

### Phase 4 - First mini-program
Start with a tiny mini-program such as:
- promo page
- profile card flow
- feedback form
- recharge form without real payment

Do **not** start with:
- full payment flow
- map-based flow
- complex editor
- large multi-step operational workflow

**Goal:** prove authoring -> build -> validate -> render works end to end.

---

### Phase 5 - Backend delivery
After local proof works, add:
1. manifest hosting
2. screen/theme hosting
3. asset hosting
4. version pinning
5. rollout rules
6. basic caching policy metadata

**Goal:** move from local-only to remotely delivered mini-programs.

---

### Phase 6 - Custom widgets and actions
Add only when foundation is stable:
- `openPayment`
- `openNativeScreen`
- `callSecureApi`
- `trackEvent`
- custom cards or product blocks

**Goal:** real business usefulness without breaking portability.

---

### Phase 7 - Multi-host proof
Only after one host app is stable should another host app be added.

**Goal:** prove the platform is truly portable.

This is the real architecture test.

---

## 16. MVP Scope

For MVP, do only this:
1. contracts package
2. SDK package with bridge and validation
3. one host app
4. one mini-program
5. one backend manifest endpoint
6. one backend screen endpoint
7. one custom action
8. one failure-path demo

Do **not** start with:
- marketplace or third-party ecosystem
- plugin store
- advanced rollout console
- dynamic payment orchestration
- multi-tenant admin UI
- big analytics dashboard

---

## 17. Coding Rules for Agents and Humans

1. Do not couple mini-programs to a specific host app.
2. Do not put host business logic inside `mini_program_sdk`.
3. Do not bypass `HostBridge` for native work.
4. Do not invent new action names without updating contracts.
5. Do not introduce unsafe dynamic execution patterns.
6. Do not let strings drift across packages.
7. Prefer small stable interfaces over clever abstractions.
8. Every new capability must be declared, validated, and documented.
9. Every custom widget and action must have fallback behavior.
10. Every failure must be observable with logs or explicit error codes.
11. Keep generated build artifacts out of long-term source-of-truth logic.
12. Verify Stac output paths and CLI behavior in the installed version before scripting around them.

---

## 18. Definition of Done

A feature is complete only when:
- contract is defined
- SDK support exists
- host support exists if required
- mini-program usage is valid
- validation passes
- fallback behavior exists
- one happy-path demo works
- one failure-path demo works
- docs are updated
- logs/error codes are meaningful

---

## 19. First Concrete Task List

If starting from zero, do these tasks first:

1. Create `packages/mini_program_contracts`
2. Define `Manifest`, `Capability`, `ActionNames`, and `SdkVersionRange`
3. Create `packages/mini_program_sdk`
4. Add `HostBridge` abstract class
5. Add `MiniProgramHost` widget shell
6. Add manifest loader and version validator
7. Add capability registry and fallback error screen
8. Create `hosts/super_app_host`
9. Implement `host_bridge_impl.dart`
10. Create one simple mini-program in `mini_programs/profile_center`
11. Build and render locally first
12. Only then move manifest/screen delivery to backend

---

## 20. Final Guidance

Build this project as a **platform**, not just a feature.

When in doubt, choose the option that:
- reduces coupling
- improves portability
- keeps native power behind the bridge
- keeps portable UI declarative
- keeps contracts explicit
- makes failure easier to detect early

If a proposed shortcut breaks one of those rules, it is probably the wrong shortcut.

---

## 21. External References to Verify During Implementation

These are not source-of-truth contracts for your project, but they are important references while implementing:
- Stac docs: https://docs.stac.dev/
- Stac DSL: https://docs.stac.dev/dsl
- Stac project structure: https://docs.stac.dev/project_structure
- Stac CLI: https://docs.stac.dev/cli
- Stac caching: https://docs.stac.dev/concepts/caching
- Stac action parsers: https://docs.stac.dev/concepts/action_parsers/

Always verify installed package and CLI behavior in your actual repo before automating around docs examples.
