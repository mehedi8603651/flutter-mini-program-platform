# Flutter Mini-Program Platform Guide

This file is the persistent repository guide for maintainers and coding agents. Read it before changing code. It explains the architecture, source ownership, important paths, generated files, workflows, tests, security boundaries, release conventions, and unfinished work.

## Project Purpose

This repository provides a provider-neutral Flutter mini-program platform. A mini-program is authored in Dart with `mini_program_ui`, compiled into static JSON screens and assets, and rendered by a host Flutter app through `mini_program_sdk`.

The primary delivery model is:

```text
Mini-program Dart source
  -> miniprogram build
  -> static manifest, screens, and assets
  -> miniprogram artifact build
  -> immutable artifacts/<appId>/<version>/ bundle
  -> any public static storage
  -> host opens appId + artifactBaseUrl
  -> SDK validates and renders the JSON UI
```

A mini-program may optionally call its publisher's HTTPS middle-server at runtime. The static artifact host and runtime API are separate systems. The Flutter host must not become a proxy for publisher business logic.

## Current Package Set

These versions are the repository's current development/release line. Check each `pubspec.yaml` before publishing because this section can become stale after a version bump.

| Package | Current version | Role |
| --- | ---: | --- |
| `mini_program_contracts` | `0.3.7` | Shared wire models, action names, errors, capabilities, and manifest contracts |
| `mini_program_ui` | `0.1.13` | Pure-Dart authoring API that serializes UI and actions to JSON |
| `mini_program_sdk` | `0.5.13` | Flutter host runtime, renderer, state, cache, loading, and host integration |
| `mini_program_tooling` | `0.6.14` | `miniprogram` CLI, generators, validation, artifacts, preview, and host import |
| `mini_program_vscode` | `0.4.1` | VS Code workflows that invoke the CLI |

Dependency direction:

```text
mini_program_contracts
  <- mini_program_ui
  <- mini_program_sdk
  <- mini_program_tooling

mini_program_vscode -> invokes mini_program_tooling through the CLI
mini-program projects -> depend on mini_program_ui
host applications -> depend on mini_program_sdk
```

Do not make `mini_program_ui` depend on Flutter. It must remain usable by plain Dart build scripts.

## Architecture Rules

These are system invariants, not preferences:

1. A host opens a static mini-program using only `appId + artifactBaseUrl`.
2. Static mini-program artifacts are public, untrusted UI bundles. Never place secrets in them.
3. Runtime API configuration is optional and belongs to mini-program runtime actions.
4. Publisher middle-servers own authentication, databases, payments, files, secrets, external APIs, admin logic, and business rules.
5. Runtime API actions may call only the validated artifact-declared publisher middle-server URL after host acceptance.
6. `mini_program_ui` stays pure Dart.
7. SDK runtime and tooling remain provider-neutral. Provider examples belong in docs or example backends.
8. The host owns accepted permissions, cache policy, live-state limits, capabilities, and static artifact endpoint configuration.
9. A mini-program may declare one Publisher API in root `publisher_backend.json`; the host may enable or deny it but does not override its URL.
10. A publisher request is never runtime authority. Runtime uses host-accepted policy only.
11. Published version directories are immutable. A changed release gets a new version.
12. Mini-program JSON is strictly validated before rendering or dispatching actions.
13. Session, token, password, login data, and other sensitive host storage are never exposed as mini-program cache buckets.
14. Device location is an optional host capability: a mini-program may request
    one-time approximate foreground access, but runtime authority comes only
    from host-accepted policy and a host-installed provider.

## Repository Map

The trees below list maintained source and important generated boundaries. Flutter platform boilerplate (`android/`, `ios/`, `web/`, and similar generated runner files), package build output, and repetitive test fixtures are grouped instead of listing every generated file.

### Root

```text
flutter-mini-program-platform/
|-- AGENTS.md                                  # This architecture and maintenance guide; keep it current
|-- README.md                                  # Public project overview and primary quick commands
|-- LICENSE                                    # Repository license
|-- .gitignore                                 # Ignores Dart/Flutter output, logs, secrets, and local CLI state
|-- .github/
|   `-- workflows/
|       `-- repo-smoke.yml                     # Windows CI: delivery, backend, SDK, and reference-host smoke tests
|-- packages/                                  # Publishable contracts, authoring, runtime, tooling, and editor packages
|-- mini_programs/                             # In-repo example mini-program source projects
|-- hosts/                                     # Reference Flutter host applications
|-- backend/                                   # Reference local delivery and secure API implementations
|-- docs/                                      # Architecture, authoring, embedding, and end-to-end guides
|-- tools/                                     # PowerShell wrappers, validation, synchronization, and release checks
|-- emulator.flutter_emulator.log              # Local ignored emulator log; not project source
`-- firebase-debug.log                         # Local ignored Firebase log; not project source
```

### `packages/mini_program_contracts`

The contracts package defines the stable data crossing package, process, and network boundaries. Add a contract here when both producers and consumers must agree on the same serialized value.

```text
packages/mini_program_contracts/
|-- lib/
|   |-- mini_program_contracts.dart             # Public export barrel; public contracts must be exported here
|   |-- action_names.dart                       # Canonical action type strings shared by UI, SDK, and validators
|   |-- action_payloads.dart                    # Typed action payload models
|   |-- action_payloads.freezed.dart            # Generated immutable-model code; never edit manually
|   |-- action_payloads.g.dart                  # Generated JSON code; never edit manually
|   |-- host_actions.dart                       # Host action request/result wire models
|   |-- host_actions.freezed.dart               # Generated immutable-model code; never edit manually
|   |-- host_actions.g.dart                     # Generated JSON code; never edit manually
|   |-- manifest.dart                           # Mini-program manifest and delivery metadata models
|   |-- manifest.freezed.dart                   # Generated manifest model code; never edit manually
|   |-- manifest.g.dart                         # Generated manifest JSON code; never edit manually
|   |-- sdk_version.dart                        # SDK version/range compatibility models
|   |-- sdk_version.freezed.dart                # Generated version model code; never edit manually
|   |-- sdk_version.g.dart                      # Generated version JSON code; never edit manually
|   |-- capability.dart                         # Host capability names and capability contracts
|   |-- error_codes.dart                        # Stable machine-readable error codes used across layers
|   |-- mini_program_location.dart              # Approximate one-time location enums and JSON-safe result contract
|   |-- feature_flags.dart                      # Feature flag contract and identifiers
|   |-- mini_program_navigation_actions.dart    # Navigation action contracts
|   |-- publisher_backend_contract.dart         # Optional publisher HTTPS API request/response contract
|   `-- screen_format.dart                      # Static screen document format/version contract
|-- test/                                       # Contract serialization, equality, compatibility, and error tests
|-- pubspec.yaml                                # Dart dependencies and package version
|-- CHANGELOG.md                                # Published and pending contract changes
|-- README.md                                   # Package-facing contract documentation
`-- analysis_options.yaml                       # Package analyzer configuration
```

Regenerate Freezed/JSON files from this package directory after changing annotated models:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

### `packages/mini_program_ui`

The UI package is the publisher-facing pure-Dart authoring DSL. It creates deterministic JSON; it does not render Flutter widgets.

```text
packages/mini_program_ui/
|-- lib/
|   |-- mini_program_ui.dart                    # Only supported public import for mini-program authors
|   `-- src/
|       |-- mp.dart                             # Stable `Mp` facade; signatures, docs, delegation, compatibility exports only
|       |-- core/                               # Feature-independent serializable values and validation primitives
|       |   |-- mp_action.dart                  # Serializable action descriptor
|       |   |-- mp_node.dart                    # Serializable widget-node descriptor
|       |   |-- mp_json.dart                    # Deterministic JSON normalization
|       |   |-- authoring_validation.dart       # Shared strings, keys, paths, and collection validation
|       |   |-- binding_validation.dart         # Full-binding syntax recognition
|       |   `-- value_normalization.dart        # Shared range, duration, enum, and finite-number normalization
|       |-- program/                            # Screen registry, schema, and deterministic build output
|       |   |-- mp_program.dart                 # Program and screen-document assembly
|       |   |-- mp_build_output.dart            # Development screen JSON writer
|       |   `-- mp_schema.dart                  # Authoring schema constants and screen ID validation
|       |-- features/                           # Node/action implementations grouped by behavior
|       |   |-- shared/                         # Presentation-only colors, icons, spacing, and style validation
|       |   |-- layout/                         # Row, column, stack, sizing, padding, flex, and section nodes
|       |   |-- content/                        # Text, display, image nodes, and image models
|       |   |-- collections/                    # List, repeat, grid, and wrap nodes
|       |   |-- controls/                       # Buttons, list tiles, dropdowns, checkbox, and radio nodes
|       |   |-- forms/                          # Inputs, forms, submit nodes, and `MpOption`
|       |   |-- charts/                         # Line-chart authoring
|       |   |-- lifecycle/                      # Initialize, condition, scopes, refresh, and countdown
|       |   |-- state/                          # Memory-state actions
|       |   |-- math/                           # Restricted math actions
|       |   |-- cache/                          # Host-managed cache actions
|       |   |-- data/                           # Artifact JSON loading and ranked search actions
|       |   |-- location/                       # Host-controlled current-location action
|       |   |-- navigation/                     # Navigation and router actions
|       |   |-- backend/                        # Publisher API actions, nodes, and search
|       |   |-- auth/                           # Authentication actions and state builder
|       |   |-- lazy/                           # Lazy section/chunk models and builders
|       |   |-- skeleton/                       # Skeleton models and builders
|       |   |-- theme/                          # Lightweight theme node
|       |   |-- feedback/                       # Toast and dialog actions
|       |   `-- composition/                    # Sequence, conditional, and scoped action calls
|       |-- mp_*.dart                           # Temporary legacy re-export shims; remove in 0.2.0
|       `-- widgets/*.dart                      # Temporary legacy widget re-export shims; remove in 0.2.0
|-- test/
|   |-- core/                                   # Dependency boundaries and core behavior
|   |-- program/                                # Program/build-output behavior
|   |-- features/                               # Feature and cross-feature serialization/validation
|   |-- compatibility/                          # Legacy internal import coverage
|   `-- public_api_test.dart                    # Supported barrel compile surface
|-- pubspec.yaml                                # Pure-Dart dependencies and package version
|-- CHANGELOG.md                                # Published and pending authoring API changes
|-- README.md                                   # Package-facing authoring examples
`-- analysis_options.yaml                       # Package analyzer configuration
```

When adding an authoring API, keep `mp.dart` limited to its public signature and delegation. Put implementation and feature-specific validation under the owning feature, reuse `core` only for truly cross-feature rules, emit explicit JSON, and add deterministic serialization tests. Features may depend on core and local public models but must never import the `Mp` facade. Do not import Flutter or duplicate runtime behavior here.

### `packages/mini_program_sdk`

The SDK is the Flutter execution boundary. It fetches, validates, caches, binds, renders, and executes static mini-program documents under host policy.

```text
packages/mini_program_sdk/
|-- lib/
|   |-- mini_program_sdk.dart                   # Public SDK export barrel
|   |-- mini_program_host.dart                  # Public MiniProgramHost widget, typedef, imports, and private part registry
|   |-- host_runtime/
|   |   |-- host_state.dart                     # Private State fields plus Flutter lifecycle and build/setState delegates
|   |   |-- loading.dart                        # Generation-safe initial manifest, screen, renderer, cache, and auth loading
|   |   |-- policies.dart                       # Cache, live-state, and location policy lookup from the active source
|   |   |-- publisher_backend.dart              # Artifact Publisher API connector creation, ownership, and disposal
|   |   |-- cache_lifecycle.dart                # Active app cache close and policy cleanup
|   |   |-- navigation.dart                     # Legacy screen actions, Mp router stack operations, and screen loading
|   |   |-- rendering.dart                      # Future/loading/error UI, SDK scope, keyed screen rendering, and offline notice
|   |   |-- failures.dart                       # Source/load/render exception conversion and SDK error view selection
|   |   `-- models.dart                         # Rendered screen, route result, asset counts, and navigation identity
|   |-- mini_program_page.dart                  # Public page widget for a loaded mini-program
|   |-- mini_program_launcher.dart              # Launch orchestration from app ID/options to runtime page
|   |-- mini_program_launch_options.dart        # Per-launch route/input/options model
|   |-- mini_program_config.dart                # Host-provided SDK dependencies and defaults
|   |-- mini_program_scope.dart                 # Inherited runtime scope for active mini-program services
|   |-- mini_program_runtime.dart               # Runtime assembly and execution services
|   |-- mini_program_controller.dart            # Imperative host/runtime controller
|   |-- mini_program_discovery.dart             # Public availability resolver import boundary and part registry
|   |-- discovery_runtime/
|   |   |-- models.dart                         # Public source/status enums and immutable discovery state
|   |   |-- resolver.dart                       # Public availability resolve operation and orchestration
|   |   |-- cache.dart                          # Remote manifest cache writes/removals and stale-age checks
|   |   |-- offline_fallback.dart               # Retryable failure gating and cached entry-screen availability
|   |   `-- messages.dart                       # Stable bundled/remote unavailable messages
|   |-- mini_program_failure.dart               # Typed SDK loading/runtime failure model
|   |-- manifest_loader.dart                    # Public loader facade, imports, and private delivery part registry
|   |-- delivery_loading/
|   |   |-- pipeline.dart                       # Manifest-to-entry-screen orchestration and public result assembly
|   |   |-- validation.dart                     # SDK range, capability, and feature-flag acceptance order
|   |   |-- publisher_backend.dart              # Optional artifact Publisher API contract loading and app ownership checks
|   |   |-- manifest_cache.dart                 # Fresh manifest loading, persistence, stale fallback, and structured failures
|   |   |-- screen_cache.dart                   # Fresh screen loading, persistence, stale fallback, and structured failures
|   |   |-- stale_cache.dart                    # Retryable source errors and maximum stale-age rules
|   |   `-- models.dart                         # Loaded public results plus private manifest/screen load results
|   |-- host_bridge.dart                        # Boundary for approved host actions/capabilities
|   |-- capability_registry.dart                # Host capability registration and checks
|   |-- feature_flag_evaluator.dart             # Runtime feature flag evaluation
|   |-- sdk_context.dart                        # Internal SDK context shared during rendering
|   |-- version_validator.dart                  # Manifest/SDK compatibility checks
|   |-- actions/
|   |   `-- host_action_dispatcher.dart         # Dispatches approved actions to the host bridge
|   |-- auth/
|   |   |-- mini_program_auth.dart              # Public auth import boundary and private part registry
|   |   `-- runtime/
|   |       |-- headers_paths.dart              # Auth clock, authorization header, and backend route configuration
|   |       |-- user.dart                       # Public normalized auth user model
|   |       |-- session.dart                    # Token-bearing session model, parsing, expiry, and redacted bindings
|   |       |-- snapshot.dart                   # Reactive public status and token-free binding projection
|   |       |-- result.dart                     # Public operation result and stable JSON projection
|   |       |-- store.dart                      # Session persistence contract
|   |       |-- memory_store.dart               # App-scoped in-memory session persistence
|   |       |-- secure_store.dart               # Stable-key FlutterSecureStorage session persistence
|   |       `-- controller/
|   |           |-- controller.dart             # Public controller members, factories, owned sessions, and notifications
|   |           |-- restoration.dart            # Cached-session restoration and expired-session routing
|   |           |-- email_auth.dart             # Email validation plus sign-in/sign-up requests
|   |           |-- refresh.dart                # Refresh and local-first sign-out execution
|   |           |-- authorization.dart          # Expiry-aware bearer request authorization
|   |           `-- session_updates.dart        # Backend response persistence, failure mapping, and session clearing
|   |-- observability/
|   |   `-- sdk_logger.dart                     # Provider-neutral structured SDK logging hook
|   |-- location/
|   |   `-- mini_program_location.dart          # Host provider, accepted policy, and structured provider failures
|   |-- state/
|   |   |-- mp_state.dart                       # Public state/router import boundary and private part registry
|   |   |-- live_state/
|   |   |   |-- policy.dart                     # Host-owned limits, policy provider, and stable quota exception
|   |   |   |-- store.dart                      # MpStore public members, watchers, lifecycle, and mutation entry points
|   |   |   |-- manager.dart                    # MpStateManager public facade over one store
|   |   |   |-- batching.dart                   # Atomic nested batches, rollback, commits, and watcher coalescing
|   |   |   |-- paths.dart                      # Public key validation plus dotted-path read/write/remove helpers
|   |   |   |-- values.dart                     # JSON-safe value normalization and defensive cloning
|   |   |   |-- limits.dart                     # UTF-8 byte, recursive entry, value-size, and depth enforcement
|   |   |   `-- models.dart                     # Private branch metrics and batch checkpoints
|   |   `-- router/
|   |       `-- router.dart                     # MpRouter public callback typedefs and forwarding facade
|   |-- cache/
|   |   |-- mini_program_cache_bundle.dart      # Host-selected delivery/runtime cache composition
|   |   |-- manifest_cache.dart                 # Public compatibility barrel for manifest cache APIs
|   |   |-- screen_cache.dart                   # Public compatibility barrel for screen cache APIs
|   |   |-- asset_cache.dart                    # Public compatibility barrel for asset cache APIs
|   |   |-- delivery/
|   |   |   |-- storage_key_codec.dart          # Shared base64url delivery-cache filename encoding
|   |   |   |-- manifest/
|   |   |   |   |-- entry.dart                  # Cached manifest JSON model
|   |   |   |   |-- store.dart                  # Manifest cache contract
|   |   |   |   |-- memory_store.dart           # In-memory manifest cache
|   |   |   |   `-- file_store.dart             # Corruption-tolerant file-backed manifest cache
|   |   |   |-- screen/
|   |   |   |   |-- entry.dart                  # Versioned cached screen JSON model
|   |   |   |   |-- keys.dart                   # Stable app/version/screen cache-key construction
|   |   |   |   |-- store.dart                  # Screen cache contract
|   |   |   |   |-- memory_store.dart           # In-memory screen cache
|   |   |   |   `-- file_store.dart             # Corruption-tolerant file-backed screen cache
|   |   |   `-- asset/
|   |   |       |-- entry.dart                  # Cached asset metadata model
|   |   |       |-- store.dart                  # Asset cache contract
|   |   |       |-- no_op_store.dart            # Disabled/non-persistent asset cache
|   |   |       `-- file_store.dart             # Asset bytes, metadata, extensions, and cleanup
|   |   |-- runtime_cache.dart                  # Public runtime-cache import boundary and private part registry
|   |   |-- runtime/
|   |   |   |-- types.dart                      # Cache clock plus bucket, storage, and priority enums
|   |   |   |-- policy.dart                     # Host policy, allowed buckets, TTLs, limits, and policy provider
|   |   |   |-- usage.dart                      # Host usage models and privacy-filtered mini-program JSON
|   |   |   |-- entries.dart                    # Cache entry and per-app metadata models
|   |   |   |-- store.dart                      # Base and indexed runtime cache store contracts
|   |   |   |-- memory_store.dart               # In-memory indexed store implementation
|   |   |   |-- manager.dart                    # Public overrideable manager methods and service state
|   |   |   |-- operations.dart                 # Reads, writes, removals, clears, TTL clamping, totals, and usage
|   |   |   |-- lifecycle.dart                  # App open/close, expiry, logout, inactive, and global cleanup
|   |   |   |-- enforcement.dart                # Bucket/total quota eviction order and host-pinned protection
|   |   |   |-- tracking.dart                   # Known apps, policy memory, access timestamps, and metadata refresh
|   |   |   |-- app_cache.dart                  # Mini-program-visible app-scoped cache facade and bucket checks
|   |   |   `-- values.dart                     # App/key safety, JSON value normalization, and byte sizing
|   |   |-- runtime_file_cache.dart             # Public compatibility barrel for file runtime persistence
|   |   |-- runtime_shared_preferences_cache.dart # Public compatibility barrel for preferences persistence
|   |   `-- persistence/
|   |       |-- runtime_entry_codec.dart         # Shared immutable schema-v1 runtime entry codec
|   |       |-- storage_key_codec.dart           # Runtime filename/preference-key encoding and prefix validation
|   |       |-- file_runtime_store.dart          # Atomic file-backed indexed runtime store
|   |       `-- preferences_runtime_store.dart   # SharedPreferences/web-compatible indexed runtime store
|   |-- data/
|   |   |-- mini_program_data_resource.dart     # Public data-resource import boundary and private part registry
|   |   `-- runtime/
|   |       |-- constants.dart                  # Public JSON asset byte, depth, member, and path limits
|   |       |-- models.dart                     # Public load result and stable data exception
|   |       |-- manager.dart                    # Public manager operations and owned resource/index state
|   |       |-- loading.dart                    # Cache-first artifact loading, source mapping, persistence, and replacement
|   |       |-- resource_keys.dart              # Versioned cache keys and app/version/resource runtime keys
|   |       |-- resource_state.dart             # Loaded resource model and index invalidation
|   |       |-- resource_validation.dart        # Cache policy, resource ID, safe path, size, depth, and member validation
|   |       `-- search/
|   |           |-- models.dart                 # Private search index, record, and ranked-item models
|   |           |-- indexing.dart               # List/path extraction, field normalization, index building, and eviction
|   |           |-- ranking.dart                # Diacritic normalization and exact/prefix/contains ranking
|   |           `-- execution.dart              # Query validation, stale suppression, sorting, limits, and result projection
|   |-- network/
|   |   |-- mini_program_source.dart            # Abstract static artifact source
|   |   |-- http_mini_program_source.dart       # Public HTTP static-delivery import boundary and part registry
|   |   |-- mini_program_source_exception.dart  # Fetch/source failure taxonomy
|   |   |-- asset_resolver.dart                 # Public offline image-resolution import boundary and part registry
|   |   |-- mini_program_endpoint.dart          # Public endpoint-routing import boundary and part registry
|   |   |-- mini_program_delivery_context.dart  # Delivery metadata available during loading
|   |   |-- published_mini_program_catalog_client.dart # Public catalog client import boundary and part registry
|   |   |-- mini_program_backend_connector.dart # Public Publisher API connector import boundary and part registry
|   |   |-- mini_program_backend_store.dart     # Public reactive store import boundary and part registry
|   |   |-- asset_resolution/
|   |   |   |-- models.dart                     # Public result counters and private mutable statistics
|   |   |   |-- resolver.dart                   # Public resolver constructor and entry/screen operations
|   |   |   |-- traversal.dart                  # Sequential recursive map/list screen rewriting
|   |   |   |-- detection.dart                  # Eligible network-image recognition and extension inference
|   |   |   `-- image_resolution.dart           # Cache reads, HTTP download, persistence, fallback, logging, and rewrite
|   |   |-- published_catalog/
|   |   |   |-- models.dart                     # Public catalog and published mini-program summary models
|   |   |   |-- client.dart                     # Public client construction, delivery context, and list operation
|   |   |   |-- transport.dart                  # Catalog URI, GET, timeout, transport, and HTTP status handling
|   |   |   |-- parsing.dart                    # JSON object, ordered entries, capability normalization, and trace ID
|   |   |   `-- errors.dart                     # Nested backend failure normalization and details
|   |   |-- static_delivery/
|   |   |   |-- http/
|   |   |   |   |-- source.dart                 # Public HTTP source constructor, fields, operations, and disposal
|   |   |   |   |-- paths.dart                  # Canonical artifact URI resolution and manifest query parameters
|   |   |   |   |-- loading.dart                # Candidate iteration plus JSON-object and byte loading
|   |   |   |   |-- transport.dart              # HTTP GET, headers, timeout, status handling, and response bytes
|   |   |   |   |-- loopback.dart               # Localhost/Android-emulator fallback candidates and transport wrapper
|   |   |   |   |-- errors.dart                 # Backend error normalization and structured response details
|   |   |   |   `-- publisher_backend.dart      # Optional artifact-owned Publisher API contract loading/validation
|   |   |   `-- endpoint/
|   |   |       |-- models.dart                 # Public endpoint model and source-factory typedef
|   |   |       |-- routing_source.dart         # Public routing operations, accepted policies, and disposal
|   |   |       |-- source_factory.dart         # Lazy per-app source identity and default HTTP construction
|   |   |       |-- capabilities.dart           # Optional JSON asset and Publisher API contract delegation
|   |   |       |-- policies.dart               # Accepted endpoint policy resolution and missing-app failures
|   |   |       `-- validation.dart             # App ID and endpoint-map normalization
|   |   |-- publisher_api/
|   |   |   |-- connector/
|   |   |   |   |-- policy.dart                 # Host-accepted Publisher API policy and provider
|   |   |   |   |-- headers.dart                # Stable delivery/request header names and precedence
|   |   |   |   |-- models.dart                 # Endpoint, cache policy, request, result, and HTTP client factory
|   |   |   |   |-- interfaces.dart             # Connector and disposable connector contracts
|   |   |   |   |-- disabled.dart               # Stable host-denied connector behavior
|   |   |   |   |-- endpoint_routing.dart       # Public endpoint-routing connector members and lifecycle
|   |   |   |   |-- endpoint_validation.dart    # Backend map, method, relative path, URI, and header normalization
|   |   |   |   |-- request_transport.dart      # Lazy HTTP client, verbs, timeout, and loopback fallback
|   |   |   |   |-- response_decoder.dart       # HTTP/JSON normalization and stable result failures
|   |   |   |   `-- memory_cache.dart           # GET-only TTL cache and authorization partitioning
|   |   |   `-- store/
|   |   |       |-- queries.dart                 # Single/paged query models and request conversion
|   |   |       |-- snapshots.dart               # Single-query immutable reactive snapshot
|   |   |       |-- pagination.dart              # Paged snapshot, append behavior, and nested-path reads
|   |   |       |-- store.dart                   # Public store members, lifecycle, and owned state
|   |   |       |-- execution.dart               # Connector execution, interceptors, and stale-result suppression
|   |   |       |-- in_flight.dart               # Request identity, deduplication, and completion cleanup
|   |   |       `-- binding_data.dart            # Combined single/paged binding projection
|   |   `-- local_backend_defaults.dart         # Local development source defaults
|   |-- rendering/
|   |   |-- mini_program_screen_renderer.dart   # Higher-level renderer facade
|   |   |-- mini_program_backend_binding_resolver.dart # Resolves bindings from backend response snapshots
|   |   |-- mp_screen_renderer.dart             # Core validated JSON-to-Flutter renderer entry
|   |   `-- mp_runtime/
|   |       |-- models.dart                     # Internal parsed runtime node/action models
|   |       |-- bindings.dart                   # Resolves `{{state...}}` and other runtime bindings
|   |       |-- action_dispatcher.dart          # Public runner plus central action routing, logging, and error boundary
|   |       |-- actions/
|   |       |   |-- shared.dart                 # Common action property, authorization, cache, and duration helpers
|   |       |   |-- auth_backend.dart           # Authentication and basic Publisher API execution
|   |       |   |-- backend_search.dart         # Search paging, refresh, clear, and result-state helpers
|   |       |   |-- state.dart                  # State mutations and stable state failure results
|   |       |   |-- math.dart                   # Math execution, normalization, and aggregate helpers
|   |       |   |-- data.dart                   # Artifact JSON resource load and search execution
|   |       |   |-- location.dart               # Accepted one-time location execution and request deduplication
|   |       |   |-- cache.dart                  # App-scoped cache action execution
|   |       |   |-- feedback_forms_lazy.dart    # Form, lazy-load, toast, and dialog execution
|   |       |   |-- composition.dart            # Sequence, conditional, and reusable-action calls
|   |       |   `-- navigation.dart             # Router action execution and failures
|   |       |-- math_engine.dart                # Restricted core-Dart expression tokenizer/parser/evaluator
|   |       |-- validation/
|   |       |   |-- screen_validator.dart       # Public validator facade, limits, root parsing, and dispatch tables
|   |       |   |-- shared.dart                 # Cross-feature template and action parsing helpers
|   |       |   |-- shared/
|   |       |   |   |-- structure.dart          # Object keys, child cardinality, and generic object/list parsing
|   |       |   |   |-- strings.dart            # Stable strings, field names, locales, and dotted data paths
|   |       |   |   |-- numbers.dart            # Integer, number, boolean, and bounded scalar validation
|   |       |   |   |-- presentation.dart       # Spacing, positioning, icons, tones, text choices, and headings
|   |       |   |   |-- theme.dart              # Theme colors, typography, tokens, and theme-specific values
|   |       |   |   |-- media.dart              # Image sources, headers, URLs, base64 data, and preview hosts
|   |       |   |   |-- collections_forms.dart  # Collection direction/limits and selection option parsing
|   |       |   |   |-- state_cache.dart        # State paths, patch overlap, cache keys, buckets, and JSON values
|   |       |   |   `-- failures.dart           # Unsupported type and controlled render failures
|   |       |   |-- nodes/                      # Private node validators grouped by runtime feature
|   |       |   `-- actions/                    # Private action validators grouped by runtime feature
|   |       |-- widgets.dart                    # Screen/root rendering and central node-type dispatch only
|   |       `-- widgets/
|   |           |-- shared.dart                 # Shared node property readers, numeric helpers, and no-op listenable
|   |           |-- theme.dart                  # Theme models, tokens, typography, tones, and button colors
|   |           |-- layout.dart                 # Row/column/container/scroll/stack/flex layout implementations
|   |           |-- collections.dart            # List, repeat, grid, wrap, and repeated-item bindings
|   |           |-- content.dart                # Text, cards, alerts, skeletons, badges, and display content
|   |           |-- media.dart                  # Images, box fit, icon rendering, glyphs, and const icon table
|   |           |-- controls.dart               # Tap/styled/icon buttons, list-tile actions, and action wrappers
|   |           |-- feedback.dart               # SDK-owned toast and dialog views
|   |           |-- charts/
|   |           |   `-- line_chart.dart         # fl_chart-backed single-series line chart rendering
|   |           |-- forms/
|   |           |   |-- models.dart             # Form controller, scope, field registration, and validators
|   |           |   |-- shared.dart             # Shared field frame, decoration, options, and selection marks
|   |           |   |-- state_builder.dart      # State-key-driven subtree rebuilding
|   |           |   |-- form_container.dart     # Form lifecycle and controller identity
|   |           |   |-- text_input.dart         # Controlled form text and text-area fields
|   |           |   |-- backend_search_input.dart # Debounced Publisher API search field
|   |           |   |-- state_search_field.dart # Controlled local-state search field
|   |           |   |-- selection_controls.dart # Dropdown, checkbox, and radio controls
|   |           |   `-- submit.dart             # Form validation and Publisher API submission
|   |           |-- backend/
|   |           |   |-- auth_builder.dart       # Authentication snapshot builder
|   |           |   |-- query_builder.dart      # Single Publisher API query lifecycle
|   |           |   |-- pagination.dart         # Paged Publisher API query lifecycle
|   |           |   `-- helpers.dart            # Query keys, request models, and normalized search data
|   |           |-- lazy/
|   |           |   |-- section.dart            # Lazy action section lifecycle and cache hydration
|   |           |   |-- chunk.dart              # Lazy paged chunk lifecycle and load-more execution
|   |           |   |-- models.dart             # Lazy result models, registries, and once-key storage
|   |           |   `-- helpers.dart            # Runtime keys, cache keys, merge rules, and result parsing
|   |           `-- lifecycle/
|   |               |-- refresh_viewport.dart   # Root pull-to-refresh viewport
|   |               |-- condition_scopes.dart   # Conditional rendering and reusable action scope
|   |               |-- countdown.dart          # Countdown timer, lifecycle suspension, and completion
|   |               |-- initialize.dart         # One-time initialization, retries, and error rendering
|   |               |-- state_scope.dart        # State-prefix disposal ownership
|   |               `-- identity.dart           # Stable lifecycle runtime-key calculation
|   `-- widgets/
|       |-- sdk_loading_view.dart               # Default host loading UI
|       |-- sdk_error_view.dart                 # Default host failure UI
|       |-- sdk_offline_notice.dart             # Temporary stale-content/offline notice overlay
|       `-- sdk_email_auth_sheet.dart           # Reference host-owned email auth UI
|-- test/                                       # Unit/widget tests for loading, rendering, state, cache, source, and actions
|-- pubspec.yaml                                # Flutter dependencies, SDK floor, and package version
|-- CHANGELOG.md                                # Published and pending SDK behavior changes
|-- README.md                                   # Host integration API documentation
`-- analysis_options.yaml                       # Package analyzer configuration
```

`MiniProgramHost` uses one private Dart `part` library rooted at `mini_program_host.dart`. Keep its public constructor and typedef in the root file; host loading, policies, Publisher API ownership, cache lifecycle, navigation, rendering, failures, and internal screen models belong in `host_runtime/`. `State.build` and protected `setState` access stay as thin delegates in `host_state.dart`. Preserve load-generation checks, cache open/close order, host-versus-SDK connector ownership, navigation identity, route-result propagation, stale-content behavior, callback order, and disposal behavior.

`ManifestLoader` uses one private Dart `part` library rooted at `manifest_loader.dart`. Keep the public loader signatures, constructor, result-type APIs, imports, and part registry stable; orchestration, result implementations, manifest acceptance, optional Publisher API contract loading, cache reads/writes, stale fallback, and private load results belong in `delivery_loading/`. Runtime order is compatibility-sensitive: load the manifest, validate SDK/capabilities/feature flags, load the entry screen, then load the optional Publisher API contract. Preserve cache write/remove order, retryable error classification, maximum stale-age checks, warning/error payloads, structured failure details, and the rule that Publisher API connectivity failures do not fail static app loading.

Live state and routing use one private Dart `part` library rooted at `state/mp_state.dart`. Keep `MpStore`, `MpStateManager`, `MiniProgramLiveStatePolicy`, `MiniProgramStateLimitException`, `validateStateKey`, router typedefs, and `MpRouter` available through the existing public SDK barrel. State values must remain JSON-safe and defensively cloned; reads inside a batch must observe staged writes; nested batches must commit once or roll back as one unit; related-path watchers must notify once after the outer commit; policy and quota failures must preserve prior state and stable details. Preserve UTF-8 JSON byte accounting, recursive entry/depth rules, secret-like key blocking, dispose behavior, and exact router argument/result/request-ID forwarding.

Runtime cache uses one private Dart `part` library rooted at `cache/runtime_cache.dart`. Keep all public cache enums, models, store interfaces, `MiniProgramCacheManager`, and `MiniProgramAppCache` available through the existing barrel. Public manager operations must remain real class members because hosts may subclass and override lifecycle or cleanup behavior; internal orchestration must call those public methods where the previous implementation did. Preserve namespaced keys, injected-clock TTL behavior, stored-null versus missing semantics, policy memory, metadata timestamps, cleanup order by priority then bucket then access time, and host-pinned protection. Mini-program app caches must never expose session or host-pinned writes, disabled buckets must fail before access, and usage JSON must hide session entries and host-pinned bytes.

Delivery cache APIs keep their historical `manifest_cache.dart`, `screen_cache.dart`, and `asset_cache.dart` import paths as explicit compatibility barrels; models, contracts, memory/no-op stores, and file stores belong under `cache/delivery/`. Runtime persistence keeps the historical file and SharedPreferences import paths as compatibility barrels while implementations and the shared schema-v1 codec live under `cache/persistence/`. Preserve base64url filenames and preference keys, JSON property names and ordering, UTC timestamp encoding, corruption and expiration cleanup, asset extension resolution, atomic runtime file replacement, and the distinct default persistent bucket sets. `MiniProgramCacheBundle.inMemory`, `.fileBacked`, and `.webPersistent` composition is a public behavior boundary.

Publisher API networking uses private Dart `part` libraries rooted at `network/mini_program_backend_connector.dart` and `network/mini_program_backend_store.dart`. Keep every existing connector, policy, request/result, query/snapshot, and store type available through those historical files and the SDK barrel. `EndpointRoutingMiniProgramBackendConnector.call`/`dispose` and all public `MiniProgramBackendStore` operations must remain actual class members. Preserve relative endpoint and traversal rejection, lazy client creation, HTTP method/body behavior, local loopback fallback order, delivery/backend/request header precedence, GET-only TTL caching, authorization-based cache partitioning, response normalization, error codes/messages, and disposal. Reactive store order is compatibility-sensitive: publish loading, apply the optional interceptor, invoke the connector, reject late generation/disposal results, publish the terminal snapshot, then clean matching in-flight identity. Failed refreshes and page loads keep previous data/items; pagination registration, deduplication, binding-map ordering, listener notification timing, `clear()`, and `dispose()` semantics must remain unchanged.

Authentication uses one private Dart `part` library rooted at `auth/mini_program_auth.dart`. Keep all auth models, stores, and `MiniProgramAuthController` available through that historical file and the SDK barrel; controller public operations remain actual class members so host subclasses retain virtual dispatch. Auth tokens may appear only in the token-bearing session/storage model and Publisher API request headers, never in snapshot, result, or binding projections. Preserve the base64url secure-storage key, JSON property ordering, UTC expiry parsing, 30-second default expiry skew, app-ID isolation, notification transitions, expired restore-to-refresh routing, refresh failure cleanup, local-first sign-out, request-header precedence, and calls through public `refresh()` where prior subclass dispatch was possible.

Artifact JSON data uses one private Dart `part` library rooted at `data/mini_program_data_resource.dart`. Keep the four public asset limits, load result, data exception, and `MiniProgramDataResourceManager` available through that historical file and the SDK barrel; `load`, `search`, and `clear` remain actual manager members. Preserve validation order, host-approved data-bucket enforcement, versioned internal cache keys, cache-before-source loading, force-refresh behavior, source-error mapping, UTF-8 JSON size/depth/member limits, cache-write-before-resource replacement, and app/version/resource isolation. Search behavior is compatibility-sensitive: increment generation and yield before short-query/resource checks, suppress only matching app/resource/target requests, build indexes by items path plus ordered fields, keep at most eight insertion-ordered indexes, normalize case/whitespace/diacritics, rank exact then token-prefix then contains, preserve source order for ties, and invalidate resource indexes on replacement or clear.

Static artifact delivery uses private Dart `part` libraries rooted at `network/http_mini_program_source.dart` and `network/mini_program_endpoint.dart`. Keep `ManifestRequestQueryParametersBuilder`, `HttpMiniProgramSource`, `MiniProgramEndpointSourceFactory`, `MiniProgramEndpoint`, and `EndpointRoutingMiniProgramSource` available through those historical files and the SDK barrel. Public load, policy, and disposal operations remain actual class members. Preserve canonical `artifacts/<appId>/...` paths, latest-manifest-only query parameters, request headers and timeouts, transport-only loopback fallback order, attempted-URI details, JSON object validation, backend error normalization, optional Publisher API contract 404 behavior, contract app-ID matching, normalized endpoint identity, one lazy source per app, optional source capabilities, host-accepted policy lookup, injected-client ownership, and source disposal order.

Offline image resolution uses one private Dart `part` library rooted at `network/asset_resolver.dart`. Keep `AssetResolutionResult` and `AssetResolver` available through that historical file and the SDK barrel; `resolveEntryScreenAssets` and `resolveScreenAssets` remain actual class members. Preserve entry-screen cache-policy gating, the shallow top-level clone when disabled, sequential depth-first map/list traversal, eligible `image` plus HTTP(S) plus null/`network` detection, fresh-cache short circuiting, direct `DateTime.now()` age checks, HTTP 200/non-empty-byte requirements, content type and source-extension forwarding, cache-write-before-file rewrite, second cache read after every unsuccessful download, exact warning/error ordering for exceptions, unchanged failed image JSON, and cached/downloaded/failed counters.

Published catalog and list-level availability use private Dart `part` libraries rooted at `network/published_mini_program_catalog_client.dart` and `mini_program_discovery.dart`. Keep all catalog models, `PublishedMiniProgramCatalogClient`, discovery enums/state, and `MiniProgramDiscoveryResolver` available through those historical files and the SDK barrel; `listAvailableMiniPrograms` and `resolve` remain actual class members. Preserve `discovery/mini-programs.json` URI resolution, delivery query ordering, timeout and transport failures, body-over-header trace precedence, ordered entry parsing, capability normalization, nested backend errors/details, and malformed success/error behavior. Discovery order is compatibility-sensitive: read cached manifest, load source manifest, mutate manifest cache only for remote sources, then return live/cached; on failure, offline fallback is remote-only, accepts only backend unreachable/timeout, validates manifest policy/age before reading entry-screen cache, validates screen policy/age inclusively, and otherwise returns the same manifest metadata, details, badges, `canOpen`, and stable bundled/remote messages.

Renderer files use one Dart `part` library rooted at `mp_screen_renderer.dart`. Read the central library and the owning runtime parts before moving symbols or changing private contracts. Keep validation behavior in `mp_runtime/validation/nodes/` or `actions/`; only document parsing, limits, and central dispatch belong in `screen_validator.dart`. Shared scalar and structural validation belongs in the matching file under `mp_runtime/validation/shared/`; preserve validation call order, exact messages, paths, details, defaults, regexes, allowed sets, and normalized map insertion order when moving helpers. Keep action execution in `mp_runtime/actions/`; `action_dispatcher.dart` owns only parsing entry, binding resolution, routing, logging, and common exception mapping. Keep widget behavior in the owning file under `mp_runtime/widgets/`; `widgets.dart` owns only root scrolling, node dispatch, trivial inline wrappers whose ancestry is compatibility-sensitive, and unsupported-node failures. Runtime parts remain private to the renderer library and must not add imports or exports. Preserve private widget class names, state classes, runtime-key formulas, controller/focus lifecycles, callback order, and Flutter ancestry when reorganizing renderer code.

### `packages/mini_program_tooling`

The tooling package is the supported CLI and generator layer. Prefer extending its command groups over adding standalone repository scripts.

```text
packages/mini_program_tooling/
|-- bin/
|   |-- miniprogram.dart                        # Primary user-facing CLI executable
|   |-- create_mini_program.dart                # Compatibility create entry point
|   |-- build_mini_program.dart                 # Compatibility build entry point
|   |-- validate_delivery.dart                  # Compatibility delivery validator entry point
|   |-- inspect_delivery.dart                   # Compatibility delivery inspector entry point
|   |-- publish_mini_program.dart               # Legacy/static publisher entry point
|   `-- init_mini_program_embedding.dart        # Compatibility host embedding entry point
|-- lib/
|   |-- mini_program_tooling.dart                # Public tooling export barrel
|   `-- src/
|       |-- miniprogram_cli.dart                 # Top-level command parser and dispatcher
|       |-- mini_program_scaffolder.dart         # Creates a new mini-program source project
|       |-- mini_program_builder.dart            # Builds fast development output in `mp/.build`
|       |-- mini_program_artifacts.dart          # Builds/verifies immutable portable artifact bundles
|       |-- mini_program_partner_handoff.dart    # Reads/writes partner handoff and requested policy
|       |-- mini_program_embedding_initializer.dart # Generates host integration files
|       |-- mini_program_host_capability_installer.dart # Installs optional generic native host providers safely
|       |-- mini_program_host_controller.dart    # Starts and controls generated/reference hosts
|       |-- mini_program_preview_host_initializer.dart # Generates a preview Flutter host
|       |-- mini_program_preview_controller.dart # Coordinates preview build/server/host lifecycle
|       |-- mini_program_preview_server.dart     # Serves local static artifacts with development headers
|       |-- mini_program_path_resolver.dart      # Resolves workspace/project paths consistently
|       |-- mini_program_workflow_status.dart    # Computes project workflow status for CLI/editor
|       |-- miniprogram_doctor.dart              # Environment and project diagnostics
|       |-- local_cli_state.dart                 # Ignored local process/port/workflow state
|       |-- delivery_validation.dart             # Delivery validation result models
|       |-- delivery_validator.dart              # Validates static delivery content
|       |-- delivery_inspector.dart              # Human/JSON inspection of built delivery
|       |-- mini_program_publisher.dart           # Older publishing orchestration retained for compatibility
|       |-- mini_program_static_publisher.dart    # Static directory publishing support
|       |-- local_backend_initializer.dart        # Creates local artifact backend workspace
|       |-- local_backend_controller.dart         # Starts/stops local backend service
|       |-- publisher_backend_starter.dart        # Creates optional publisher API starter
|       |-- publisher_backend_contract_controller.dart # Publisher API contract commands
|       |-- publisher_backend/
|       |   |-- core_operations.dart              # Shared create/start/stop/validate API workspace operations
|       |   |-- models.dart                       # Public/internal publisher backend workflow models
|       |   |-- internal_models.dart              # Implementation-only operation values
|       |   |-- starter_helpers.dart              # Workspace starter path, template, and process helpers
|       |   |-- runtime_smoke_helpers.dart        # Runtime API health/contract smoke helpers
|       |   |-- models/
|       |   |   `-- local_models.dart             # Local backend process and endpoint models
|       |   |-- generated_files.dart              # Generates mock middle-server workspace files
|       |   `-- generated_files/
|       |       `-- mock_templates.dart           # Source templates embedded by generated API workspaces
|       |-- cli/
|       |   |-- core_commands.dart                # Create/build/validate/preview core commands
|       |   |-- artifact_commands.dart            # `artifact build` and `artifact verify`
|       |   |-- host_partner_commands.dart        # Partner handoff and host endpoint import commands
|       |   |-- workflow_commands.dart            # Higher-level workflow/status commands
|       |   |-- backend_commands.dart             # Local backend compatibility commands
|       |   |-- publisher_backend_commands.dart   # Optional publisher API starter/runtime commands
|       |   |-- publisher_backend_contract_commands.dart # API contract validation commands
|       |   |-- env_commands.dart                 # Environment and doctor commands
|       |   |-- json_output_helpers.dart          # Stable machine-readable CLI output helpers
|       |   |-- result_formatters.dart            # Human CLI formatting
|       |   |-- publisher_backend_output_helpers.dart # API command output formatting
|       |   |-- shared_helpers.dart               # Shared command validation/path helpers
|       |   |-- usage_helpers.dart                # CLI usage/help text
|       |   |-- miniprogram_cli_constants.dart    # Command names/defaults/limits
|       |   `-- private_models.dart               # CLI-internal values not exported as API
|-- templates/
|   `-- backend_workspace/                       # Files copied for generated mock publisher API workspaces
|-- test/                                       # CLI, generator, artifact, policy, host, and backend tests
|-- pubspec.yaml                                # CLI dependencies, executable, and package version
|-- CHANGELOG.md                                # Published and pending tooling changes
|-- README.md                                   # CLI command and workflow documentation
`-- analysis_options.yaml                       # Package analyzer configuration
```

All CLI failures should be actionable and have nonzero exit status. Preserve JSON output compatibility when commands are consumed by VS Code or scripts.

### `packages/mini_program_vscode`

The extension is a thin user interface over CLI capabilities. Business rules belong in tooling so terminal and editor workflows behave the same.

```text
packages/mini_program_vscode/
|-- src/
|   |-- extension.ts                            # Activates extension and registers commands/views
|   |-- cli.ts                                  # CLI discovery and invocation facade
|   |-- diagnostics.ts                          # Maps CLI/project issues to VS Code diagnostics
|   |-- workflowStatus.ts                       # Reads and refreshes CLI workflow status
|   |-- statusTree.ts                           # VS Code tree view provider
|   |-- statusTreeModel.ts                      # Editor-independent status tree model
|   |-- hostIntegration.ts                      # Guided host embedding/import integration
|   |-- guidedWorkflows.ts                      # Multi-step editor workflows
|   |-- commands/
|   |   |-- coreCommands.ts                     # Create/build/validate/preview command handlers
|   |   |-- hostCommands.ts                     # Host integration handlers
|   |   |-- partnerCommands.ts                  # Partner handoff handlers
|   |   |-- localBackendCommands.ts             # Local backend handlers
|   |   |-- publisherBackendContractCommands.ts # Publisher API contract handlers
|   |   |-- environmentCommands.ts              # Doctor/environment handlers
|   |   `-- guidedCommands.ts                   # Guided workflow entry points
|   `-- extensionSupport/
|       |-- index.ts                            # Support-module export barrel
|       |-- workspace.ts                        # Workspace/project path discovery
|       |-- prompts.ts                          # Consistent VS Code user prompts
|       |-- jsonValues.ts                       # Safe parsing of CLI JSON values
|       |-- commandRunner.ts                    # Process execution and output handling
|       `-- cliCapabilities.ts                  # Detects installed CLI command support/version
|-- test/                                       # Node tests for commands, status, diagnostics, and registration
|-- media/                                      # Extension/marketplace icons
|-- package.json                                # Extension manifest, commands, views, scripts, and version
|-- package-lock.json                           # Reproducible npm dependency resolution; update with npm
|-- tsconfig.json                               # TypeScript compiler configuration
|-- .vscodeignore                               # Excludes development-only files from packaged extensions
|-- mini-program-tools-*.vsix                   # Built extension release archives; do not edit as source
|-- README.md                                   # Marketplace/user documentation
|-- CHANGELOG.md                                # Extension release notes
`-- LICENSE                                     # Extension package license copy
```

`out/` and `node_modules/` are generated. Edit `src/`, then compile and test with npm.

All Dart package roots also use the following conventional files where present:

```text
packages/<dart-package>/
|-- pubspec.yaml                                # Published dependency constraints, SDK floor, and version
|-- pubspec.lock                                # Current checked-in local resolution where already tracked
|-- pubspec_overrides.yaml                      # Local cross-package path overrides for repository development
|-- analysis_options.yaml                       # Analyzer/lint configuration
|-- README.md                                   # Public package usage documentation
|-- CHANGELOG.md                                # Release history and pending release notes
|-- LICENSE                                     # Package license copy
`-- .gitignore                                  # Package-specific generated/local exclusions where present
```

Do not add or remove lock/override files mechanically across all packages. Preserve each package's existing repository convention.

### Example Mini-Programs

These projects are executable documentation. Their source is authoritative; generated `mp/.build` output is disposable.

```text
mini_programs/
|-- mp_profile_center/                          # Basic profile/layout/image/navigation example
|-- mp_rewards_center/                          # Backend bindings, auth builder, lazy chunks, and load-more example
|-- food_order/                                 # Static multi-screen food-order interaction fixture
`-- recharge/                                   # Static recharge/form/action fixture

mini_programs/<project>/
|-- manifest.json                               # App ID, title, version, SDK requirement, and entry screen
|-- pubspec.yaml                                # Authoring dependency, normally `mini_program_ui`
|-- mp/
|   |-- program.dart                            # Program/screen registry used by the build script
|   |-- screens/*.dart                          # Maintained screen definitions using `Mp.*`
|   `-- .build/                                 # Generated development JSON; ignored and safe to rebuild
|-- tool/build_mp.dart                          # Project build entry that writes deterministic screens
`-- README.md                                   # Example-specific run and behavior notes
```

Do not edit generated JSON to implement a feature. Edit `mp/*.dart`, rebuild, and verify the resulting artifact.

### Reference Hosts

```text
hosts/
|-- mp_only_host/                               # Smallest reference host for pure Mp static screens
|-- super_app_host/                             # Full first-party host: discovery, bridge, auth, cache, offline, secure API
`-- partner_app_host/                           # External partner host with a deliberately narrower capability surface

hosts/mp_only_host/
|-- lib/main.dart                               # Entire minimal host, bundled source, bridge, and launch example
|-- assets/                                     # Bundled static profile fixture used by the minimal host
|-- test/widget_test.dart                       # Minimal host loading/rendering smoke test
|-- android/, ios/, web/, ...                   # Flutter-generated platform runners and configuration
`-- pubspec.yaml                                # Flutter dependencies and bundled assets

hosts/{super_app_host,partner_app_host}/
|-- lib/app/                                    # Flutter application shell, routes, and host-level UI
|-- lib/bridge/                                 # Host action bridge implementations
|-- lib/capabilities/                           # Capability registrations and policy decisions
|-- lib/mini_programs/                          # Endpoint/registry/loading integration for mini-programs
|-- lib/services/                               # Host-owned services such as auth and secure API adapters
|-- assets/                                     # Bundled artifact snapshots used by reference/offline tests
|-- test/                                       # Host integration and widget tests
|-- android/, ios/, web/, ...                   # Flutter-generated platform runners and configuration
`-- pubspec.yaml                                # Flutter dependencies and bundled assets
```

Bundled host assets are copies, not authoring source. Synchronize maintained examples with `tools/sync_assets.ps1` instead of hand-editing both locations.

Generated host integration normally lives in an application's `lib/mini_program/` directory:

```text
lib/mini_program/
|-- mini_program.dart                           # Generated public barrel; ordinary host UI imports only this
|-- mini_program_host_setup.dart                # Host-owned runtime composition; created once and preserved
|-- mini_program_runtime_setup.dart             # Generated SDK/cache/runtime construction
|-- mini_program_endpoints.dart                 # Endpoint-import generated artifact routes plus accepted policies
|-- mini_program_registry.dart                  # Generated app ID to endpoint registry
|-- mini_program_policies.json                  # Host-owned requested/accepted policy source of truth
|-- mini_program_policy_resolver.dart           # Generated Dart mapping for accepted cache/state/location policy
|-- mini_program_launcher.dart                  # Generated dynamic and registry-based launch helpers
|-- app_android_location_provider.dart          # Optional host-owned adapter installed by the location capability command
`-- app_host_bridge.dart                        # Host-owned capability implementation; created once and preserved
```

Android one-time approximate location additionally installs
`MiniProgramLocationChannel.kt`, registers it from `MainActivity`, and adds
only `ACCESS_COARSE_LOCATION`. Run
`miniprogram host capability init location --platform android` once per host.
The installer never edits accepted app policy; provider availability and app
authorization remain separate controls.

`embed init --force` refreshes scaffold-generated files but must preserve
`mini_program_host_setup.dart`, `app_host_bridge.dart`,
`mini_program_policies.json`, and endpoint-import generated output. Read
generator headers before editing generated Dart. Preserve host-owned files and
accepted policy fields when running import/update commands.

### Backend References

```text
backend/
|-- api/
|   |-- manifests/                              # Legacy/reference manifest delivery fixtures
|   |-- screens/                                # Legacy/reference screen delivery fixtures
|   |-- capability-policies/                    # Host capability policy fixtures
|   |-- rollout-rules/                          # Delivery rollout fixtures
|   `-- secure-api-policies/                    # Secure host API policy fixtures
`-- local_backend_service/
    |-- bin/server.dart                         # Starts the local Dart HTTP reference service
    |-- lib/local_backend_service.dart           # Public service export
    |-- lib/src/local_backend_handler.dart       # Request routing and artifact/API response handling
    |-- lib/src/manifest_delivery_selection.dart # Selects manifest versions/rollouts
    |-- lib/src/secure_feedback_handler.dart     # Reference secure feedback endpoint
    |-- lib/src/backend_response_contracts.dart  # Local service response shapes
    |-- lib/src/backend_observability.dart       # Local service logging/metrics hooks
    |-- test/                                   # Handler, selection, contract, and security tests
    `-- pubspec.yaml                            # Standalone Dart service dependencies
```

This backend is a development/reference implementation. Real publisher middle-servers remain independent deployments and must not be coupled into the SDK.

### Documentation

```text
docs/
|-- quickstart_static_miniprogram_to_host.md    # Beginner path from static app source to host loading
|-- mini_program_authoring.md                   # `Mp` nodes/actions, bindings, state, backend, and lazy patterns
|-- embed_existing_flutter_app.md               # Add SDK and generated integration to an existing Flutter host
|-- static_artifact_runtime_api_e2e_guide.md    # Complete static artifact plus optional runtime API flow
|-- middle_server_api_lambda_dynamodb.md        # Concrete provider example, not a platform dependency
`-- publisher_backend_https_api_roadmap.md      # Publisher API contract/runtime guidance and future evolution
```

Update docs when a public command, file layout, policy schema, action, or host setup changes.

### Repository Tools

```text
tools/
|-- create_mini_program.ps1                     # PowerShell wrapper for project creation
|-- build_mini_program.ps1                      # PowerShell wrapper for development builds
|-- init_mini_program_embedding.ps1             # PowerShell wrapper for host integration generation
|-- inspect_delivery.ps1                        # Inspects static delivery output
|-- publish_mini_program.ps1                    # Legacy local/static publishing wrapper
|-- publish_local_backend.ps1                   # Prepares/runs the local reference backend
|-- validate_delivery.ps1                       # Validates manifests/screens/assets and delivery rules
|-- sync_assets.ps1                             # Rebuilds/copies example artifacts into reference hosts
|-- smoke_repo.ps1                              # Repository-level smoke checks
|-- verify_global_cli.ps1                       # Verifies globally activated `miniprogram` behavior
`-- verify_mp_engine_release.ps1                # Cross-package release compatibility checks
```

Use the `miniprogram` CLI for normal user workflows. Use these scripts for repository maintenance, compatibility, and CI-style checks.

## Static Artifact Layout

`miniprogram artifact build` creates a portable storage-neutral tree inside a mini-program project:

```text
artifacts/
`-- <appId>/
    |-- latest.json                             # Active manifest copy, written atomically after a complete build
    |-- catalog.json                            # Available immutable versions and release metadata
    `-- <version>/
        |-- manifest.json                       # Runtime manifest for this exact version
        |-- publisher_backend.json              # Optional validated artifact-owned Publisher API declaration
        |-- release.json                        # Release identity and bundle metadata
        |-- checksums.json                      # Integrity hashes for all immutable release files
        |-- screens/
        |   `-- <screenId>.json                 # Validated static screen documents
        `-- assets/                             # Images/fonts/static files referenced by the screens
```

The host's `artifactBaseUrl` points to the public root that contains the canonical `artifacts/` directory. The SDK appends `artifacts/<appId>/latest.json`. For example, if storage serves the calculator pointer at `https://example.test/artifacts/calculator/latest.json`, use `https://example.test/` as the base.

Rules:

- Never replace `artifacts/<appId>/<publishedVersion>/` after publication.
- Bump `manifest.json` version before building changed content.
- Build the complete version directory and checksums before atomically updating the active `latest.json` manifest.
- Run `miniprogram artifact verify` after copying to local portable output and again in deployment automation when possible.
- `.nojekyll` and storage-specific metadata may exist at the deployment root, but the runtime format stays provider-neutral.

## Runtime System

### Loading and Rendering

1. The host resolves `MiniProgramEndpoint` from the app registry.
2. `HttpMiniProgramSource` fetches `artifacts/<appId>/latest.json`, then the selected screen files and optional versioned Publisher API contract.
3. `ManifestLoader` validates compatibility, loads the optional contract, and uses accepted host policy.
4. On a network failure, valid cached manifest/screens may render while `SdkOfflineNotice` appears temporarily.
5. `MpScreenRenderer` strictly validates each screen document.
6. Bindings are resolved against live state, launch inputs, forms, and approved backend snapshots.
7. Runtime widgets subscribe only to relevant state where possible; avoid replacing the entire screen to update one value.

### Current Widget Catalog

The authoring API currently maps to 63 unique SDK runtime node types. There are
67 distinct public constructors when the five `Mp.skeleton` variants are
counted separately, and 69 public builder entry points when the two aliases are
also counted. Actions such as `Mp.state.*`, `Mp.math.*`, `Mp.cache.*`, and
`Mp.location.*` are not widgets and are excluded from these totals.

Layout and structure:

- `Mp.column`: lays out children vertically in source order.
- `Mp.row`: lays out children horizontally in source order.
- `Mp.sizedBox`: reserves a validated fixed width, height, or both.
- `Mp.padding`: adds explicit edge insets around one child.
- `Mp.align`: positions one child using a supported alignment value.
- `Mp.center`: centers one child; it is the concise form of centered alignment.
- `Mp.spacer`: consumes remaining flex space inside a bounded row or column.
- `Mp.expanded`: makes a child fill its assigned remaining flex space.
- `Mp.flexible`: gives a child flexible space with a configurable flex and fit.
- `Mp.container`: applies sizing, padding, color, border, and radius to one child.
- `Mp.scrollView`: creates a one-child scrolling viewport for general content.
- `Mp.listView`: renders static children in a vertical or fixed-height horizontal scrolling list.
- `Mp.safeArea`: keeps one child clear of host display cutouts and system insets.
- `Mp.visibility`: shows or hides one child with optional layout-size and state preservation.
- `Mp.opacity`: paints one child with validated alpha without changing its layout.
- `Mp.aspectRatio`: constrains one child to a stable width-to-height ratio.
- `Mp.stack`: overlays children in paint order.
- `Mp.positioned`: places a child by stack edges; it is meaningful as a direct stack child.
- `Mp.divider`: draws a horizontal separator with configurable thickness and color.
- `Mp.grid`: lays out static children in a fixed-column grid.
- `Mp.wrap`: flows children onto additional horizontal or vertical runs when space is exhausted.
- `Mp.card`: gives one child the platform's standard framed card treatment.
- `Mp.section`: groups a title, optional subtitle/action, and one content child.
- `Mp.theme`: applies lightweight mini-program color and typography tokens to a subtree.

Display and visualization:

- `Mp.text`: renders body text, including supported runtime bindings and text styling.
- `Mp.heading`: renders hierarchy-aware heading text with supported heading styling.
- `Mp.image`: renders a validated image source with optional placeholder and error nodes.
- `Mp.icon`: renders a supported named icon with semantic and visual options.
- `Mp.avatar`: renders a compact person/entity image or fallback identity presentation.
- `Mp.alert`: renders a tone-aware inline status or warning message.
- `Mp.progress`: renders bounded linear progress from a required value and maximum.
- `Mp.emptyState`: renders a standardized no-data/error-style message with optional action.
- `Mp.chip`: renders a compact label that may optionally dispatch an action.
- `Mp.badge`: renders a small tone-aware status label.
- `Mp.lineChart`: renders one ordinal numeric series from bound data with points, grid, area, labels, and tooltips.
- `Mp.skeleton.box`: renders a rectangular loading placeholder.
- `Mp.skeleton.text`: renders a text-line loading placeholder.
- `Mp.skeleton.circle`: renders a circular loading placeholder.
- `Mp.skeleton.card`: renders a card-sized loading placeholder.
- `Mp.skeleton.list`: renders a repeated list of loading placeholders.

Inputs and controls:

- `Mp.primaryButton`: renders the standard high-emphasis command button.
- `Mp.secondaryButton`: renders the standard lower-emphasis command button.
- `Mp.button`: renders a fully styled text command button with stable dimensions.
- `Mp.iconButton`: renders a semantic icon command with explicit size and decoration.
- `Mp.listTile`: renders a scan-friendly row with title, subtitle, leading/trailing content, and optional action.
- `Mp.textInput`: edits one single-line form/state value.
- `Mp.searchInput`: performs debounced Publisher API search and writes bounded result state.
- `Mp.searchField`: edits live state and dispatches caller-provided local search actions after debounce or submit.
- `Mp.textArea`: edits one multiline form/state value.
- `Mp.dropdown`: selects one value from validated labeled options.
- `Mp.checkbox`: edits a boolean form/state value.
- `Mp.radioGroup`: selects one value from a visible group of labeled options.
- `Mp.form`: groups controls under a form identifier for validation and submission.
- `Mp.formSubmit`: validates and submits a form through its configured action behavior.

Dynamic data and lifecycle:

- `Mp.repeat`: renders a bounded template for each item in a bound list, with optional empty and separator nodes.
- `Mp.lazy.section`: mounts a section through lifecycle-owned actions with placeholder, retry, error, and optional cache hydration.
- `Mp.lazy.chunk`: renders bounded paged data with initial load, load-more, cache, empty, error, loading, and end states.
- `Mp.initialize`: runs a non-empty action list once per mounted instance before revealing its child, with bounded retries.
- `Mp.condition`: reactively chooses true or false child content from a boolean literal or binding.
- `Mp.timer.countdown`: owns a deadline-based countdown, writes remaining state, and optionally dispatches completion.
- `Mp.stateScope`: owns a state prefix and may clear that prefix when its subtree is disposed.
- `Mp.actionScope`: defines reusable named actions for descendants without duplicating sequences.
- `Mp.stateBuilder`: rebuilds one child template only for the declared live-state keys.
- `Mp.authBuilder`: selects loading, signed-out, signed-in, or error content from host-owned authentication state.
- `Mp.backendBuilder`: loads one Publisher API request and renders its loading, success, empty, or error content.
- `Mp.pagedBackendBuilder`: renders Publisher API pagination while preserving loaded items during additional-page failures.
- `Mp.refreshIndicator`: supplies root-level pull-to-refresh, prevents concurrent refreshes, and preserves existing content on failure.

Aliases do not add runtime node types:

- `Mp.forEach`: alias for `Mp.repeat`.
- `Mp.search.input`: namespace alias for `Mp.searchInput`.

When adding or changing a widget, update this catalog together with the UI
serialization tests, SDK validator, SDK renderer, package documentation, and
the widget count above.

### Actions and State

`MpAction` JSON is dispatched by the SDK, not evaluated as arbitrary Dart or JavaScript. Sequence steps resolve bindings immediately before each step, stop on failure, and may feed later state/cache/history actions.

Important state APIs include:

- `Mp.state.set`, `setDefault`, `patch`, `copy`, `toggle`, `increment`, and `decrement`.
- Text transforms: `appendText` and `backspace`.
- List transforms: append, prepend, insert, remove-at, and remove-value.
- `MpStateManager.batchUpdates` for synchronous, nested, rollback-capable host/runtime batches.
- `Mp.stateScope` for lifecycle-owned cleanup under a prefix.
- `Mp.initialize` for once-per-mounted-instance initialization and retry.
- `Mp.condition` for state-driven branches.
- `Mp.actionScope` plus `Mp.action.call` for reusable local action definitions and in-place updates.
- `Mp.timer.countdown` for declarative countdown state.
- `Mp.location.getCurrent` for explicit one-time approximate foreground
  location through an accepted host policy and installed host provider.

Live state is memory-only and centrally limited by host policy. Defaults are 2 MiB total JSON, 1,000 recursive entries, 256 KiB per top-level namespace, and depth 32. Persistent app data belongs in an accepted cache bucket.

### Math

The core-Dart math engine supports bounded expression evaluation, comparison, random values, and aggregates. It intentionally does not execute code, perform symbolic algebra, or parse LaTeX. Expressions and operations have strict size, depth, token, range, finite-number, and result limits.

### Cache

Mini-program-visible cache buckets are `memory`, `data`, `image`, `state`, and `video`. A calculator history, quiz history, preferences, and resumable UI state normally use `state`.

Host backends can use:

- `MiniProgramCacheBundle.inMemory()` for process-lifetime development/default behavior.
- `MiniProgramCacheBundle.fileBacked(...)` for persistent native/mobile storage.
- `MiniProgramCacheBundle.webPersistent()` for browser persistence.

TTL, enabled buckets, and byte limits are enforced consistently by the manager. `Mp.cache.info` reports only app-scoped accepted limits and usage; it never exposes keys, paths, other apps, global host usage, pinned host entries, or session storage.

### Host-Owned Policy

Partner handoff schema version 3 may request cache for `memory`, `data`,
`image`, `state`, or `video`, may request Publisher API access when the
artifact declares it, and may request one-time foreground approximate
location. Sensitive bucket/key names such as session, login data, token,
password, and secret are rejected.

`lib/mini_program/mini_program_policies.json` contains:

```json
{
  "schemaVersion": 1,
  "apps": {
    "example": {
      "requested": {
        "source": "example.partner.json",
        "cache": {},
        "publisherApi": {
          "enabled": true,
          "reason": "Load current publisher data.",
          "contract": "publisher_backend.json"
        },
        "permissions": {
          "location": {
            "enabled": true,
            "reason": "Load local content for the device area.",
            "accuracy": "approximate",
            "mode": "whenInUse"
          }
        }
      },
      "accepted": {
        "cache": {},
        "liveState": {},
        "publisherApi": { "enabled": false },
        "permissions": {
          "location": {
            "enabled": false,
            "accuracy": "approximate",
            "mode": "whenInUse"
          }
        }
      }
    }
  }
}
```

Import behavior:

- Normal import updates `requested` and preserves the host's `accepted` values.
- `--accept-requested-policy` explicitly copies supported requested cache,
  Publisher API, and location permission into accepted policy without
  replacing unrelated endpoint files.
- New location requests default to denied. Normal re-import preserves the
  host decision; `--force` resets location to denied and resets live-state
  limits to safe defaults.
- Runtime resolver generation reads only `accepted` for enforcement.
- Unknown accepted fields should be preserved for forward compatibility.

### Optional Publisher API

Static-only apps need no runtime backend. Apps requiring accounts, synchronized data, payments, notifications, files, or business rules declare one HTTPS middle-server in root `publisher_backend.json` and call relative endpoints through approved `Mp.backend.*` actions.

```text
Mini-program runtime action
  -> SDK validates action and artifact-declared API origin
  -> SDK checks host-accepted Publisher API permission
  -> MiniProgramBackendConnector
  -> publisher HTTPS middle-server
  -> publisher auth/database/payment/external services
  -> normalized response snapshot
  -> bound mini-program UI/state
```

Never add direct database credentials, cloud provider secrets, payment secrets, or unrestricted URLs to contracts, manifests, or screens.

## Main Workflows

Run commands from a mini-program project unless noted otherwise.

### Create and Develop

```powershell
miniprogram create <directory>
cd <directory>
dart pub get
miniprogram build
miniprogram preview
```

`miniprogram build` is fast development output. It writes generated documents under `mp/.build`; it does not create an immutable release.

### Build and Verify a Release

```powershell
miniprogram build
miniprogram validate
miniprogram artifact build
miniprogram artifact verify
```

Copy the resulting canonical `artifacts/` tree to any public static storage. Publishing/upload is intentionally outside the portable artifact command.

### Partner Handoff and Host Import

Use CLI help for the exact current arguments:

```powershell
miniprogram partner --help
miniprogram host endpoint import --help
```

After import, the host developer reviews `requested` versus `accepted` in `mini_program_policies.json`, rebuilds generated policy resolution as directed by the CLI, and tests with the same public/static artifact URL used by the app.

### Package Checks

From each Dart package:

```powershell
dart pub get
dart analyze
dart test
```

For the Flutter SDK and Flutter hosts:

```powershell
flutter pub get
flutter analyze
flutter test
```

For the VS Code extension:

```powershell
npm ci
npm run compile
npm test
```

Run repository checks from the root when changing cross-layer behavior:

```powershell
.\tools\validate_delivery.ps1
.\tools\smoke_repo.ps1
.\tools\verify_mp_engine_release.ps1
```

Consult `package.json` or `pubspec.yaml` when a script name/tool version changes; do not guess around a failing command.

## Changing the Platform Safely

### Add a New `Mp` Action

Most cross-layer actions require this order:

1. Add canonical names, payload contracts, and stable errors in `mini_program_contracts` when shared wire values are needed.
2. Add the pure-Dart helper and authoring validation in `mini_program_ui`.
3. Add strict allowed-property/schema validation in SDK runtime validators.
4. Implement dispatch with atomic state behavior and clear `HostActionResult` data/errors.
5. Add UI serialization tests, SDK validator tests, dispatcher/renderer tests, and sequence/binding tests.
6. Update changelogs and compatible dependency constraints across affected packages.
7. Update tooling templates/scaffolds if generated apps or hosts require the new minimum versions.
8. Test one real mini-program against local path dependencies before publishing.

### Add a New `Mp` Widget

1. Add a pure-Dart node builder under the owning `mini_program_ui/lib/src/features/<feature>/` library and delegate to it from `Mp`.
2. Define strict property validation and deterministic JSON tests.
3. Add SDK parsed-model validation.
4. Render it in the narrowest appropriate runtime widget part.
5. Subscribe to only relevant state; do not remount the whole screen for local changes.
6. Test mobile constraints, overflow, disposal, binding changes, and invalid JSON.

### Change Static Delivery

Coordinate contracts, tooling, SDK source/loading, docs, artifact tests, and backward compatibility. Existing published artifacts must continue to load unless a deliberate compatibility boundary and migration are documented.

### Change Host Policy

Test first import, re-import, host-edited accepted values, unknown fields, explicit acceptance, force behavior, generated resolver output, and runtime enforcement. Never let requested policy bypass host acceptance.

## Source Ownership and Generated Files

| Path/content | Owner | Editing rule |
| --- | --- | --- |
| `mini_programs/*/mp/**/*.dart` | Mini-program developer | Edit and rebuild |
| `mini_programs/*/mp/.build/` | Tooling | Generated; do not hand-edit |
| `artifacts/<appId>/<version>/` | Artifact builder | Immutable after publication |
| Mini-program `publisher_backend.json` | Mini-program publisher | Edit at source root; artifact tooling validates and packages it |
| `*.freezed.dart`, `*.g.dart` | build_runner | Regenerate; do not hand-edit |
| `packages/mini_program_vscode/out/` | TypeScript compiler | Generated; edit `src/` |
| Host `mini_program_policies.json` | Host developer | Source of truth for accepted policy |
| Generated host resolver/endpoints | Tooling plus reviewed host config | Regenerate through CLI; read headers |
| Reference host bundled assets | Sync tooling | Copy of mini-program output, not source |
| `.dart_tool/`, `build/`, `.mini_program/` | Dart/Flutter/CLI | Local generated state; never commit as source |
| `emulator*.log`, `firebase-debug.log` | Local tools | Diagnostic output; ignore |

The working tree may contain user changes. Never discard, reset, or overwrite unrelated modifications. Read the diff before editing a file that is already changed.

## Testing Expectations

- Keep narrow changes covered by focused tests near the owning module.
- Expand coverage for cross-package contracts, shared state/cache behavior, host policy, loading, and user-visible workflows.
- Test both valid and malicious/invalid mini-program JSON.
- Test binding values at execution time, not only static literals.
- Test disposal and stale async completion for timers, initialization, loading, and backend work.
- Test persistent and in-memory cache behavior under the same accepted policy.
- For UI smoothness, verify that local state changes rebuild only subscribed subtrees and preserve stable screen identity.
- For Android-facing changes, run host widget/unit tests and an emulator smoke test when the environment permits.
- For static delivery, verify checksums and test the exact served URL, including CORS and path casing.

## Release Conventions

- Package changelogs describe the pending release before publishing.
- Bump only affected packages, but update dependent constraints/templates/tests when the new API is required.
- Keep contracts, UI, SDK, and tooling versions mutually compatible.
- Run analysis and full tests for every affected package.
- Run `tools/verify_mp_engine_release.ps1` for a coordinated engine release.
- Publish generated code and package metadata, but not build/cache directories.
- Do not publish packages, create commits, or push unless the user explicitly requests it.
- Git line-ending warnings on Windows are informational unless a diff shows unintended whole-file churn.
- Use `git commit -m "message"`; `git commit "message"` treats the text as a pathspec and does not commit.

## Security Checklist

- Treat all remote manifests, screens, bindings, action payloads, and API responses as untrusted.
- Reject unknown properties where the schema is strict.
- Enforce length, count, depth, numeric, expression, state, and cache limits before committing data.
- Keep host secrets and authentication material outside static artifacts and public cache.
- Allow only the validated artifact-declared Publisher API origin after host acceptance.
- Stop action sequences on failure and preserve previous target state when specified by the action contract.
- Return stable machine-readable error codes with developer-friendly messages that do not leak secrets.
- Never expose cache keys, filesystem paths, session buckets, other applications, or global host storage through `Mp.cache.info`.
- Keep permissions and accepted policy host-controlled.

## External Integration Workspace

`D:\mini-app-store` is commonly used alongside this repository for real mini-programs such as Calculator and Brain Test plus an Android host. It is a separate Git repository and is not platform source.

When testing there:

- Use local path dependencies to this repository while validating unpublished platform changes.
- Rebuild the mini-program, immutable artifact, and host integration after a required-version change.
- Do not copy application-specific behavior into generic SDK APIs unless it benefits multiple mini-program categories.
- Do not commit or push the external repository unless the task explicitly requests it.
- After packages are published, switch consumers back to intentional pub.dev constraints only when requested.

## Future Work

Keep this section for unfinished platform work only. Remove items when completed rather than keeping a historical task log.

1. Add real runtime middle-server API examples for catalog search, profile update, file metadata, notification list, checkout draft, and form submit.
2. Add SDK/runtime tests for common middle-server errors: validation failure, `401` session expired, `403` forbidden, `429` rate limit, `500` server error, and `503` retryable outage.
3. Add a complete sample mini-program using `Mp.backend.query`, `Mp.backend.call`, `Mp.lazy.chunk`, search/load-more, and form submission against one mock middle-server.
4. Improve static artifact diagnostics for manifest URL, entry screen URL, public base path, path casing, CORS, and common static server mistakes.
5. Expand `Mp.lazy.chunk` examples for product lists, news feeds, chat history, order history, and search results.
6. Add a provider-neutral static artifact host checklist covering headers, cache control, immutable screen paths, latest manifest path, and local server testing.
7. Add release automation that verifies MVP documentation presents static artifact opening plus optional publisher middle-server APIs without reintroducing provider coupling.

## Agent Start Checklist

At the beginning of a new task:

1. Read this file, the root README, and the README/changelog for every affected package.
2. Run `git status --short` before making assumptions about the working tree.
3. Locate the owning layer: contract, authoring DSL, SDK runtime, tooling, extension, example, host, or backend.
4. Search for existing patterns and tests before creating a new abstraction.
5. Keep edits scoped and preserve user changes.
6. Implement through verification; do not stop after a proposal unless the user requested planning only.
7. Update this guide when architecture, important paths, generated boundaries, commands, or persistent future work changes.
