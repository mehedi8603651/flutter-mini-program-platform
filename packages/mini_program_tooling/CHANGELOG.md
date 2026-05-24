# Changelog

## 0.3.35

- add Firebase write smoke support through
  `publisher-backend firebase smoke --include-write`
- verify write smoke redemptions by reading the expected Firestore redemption
  document after `POST /coupon/redeem`
- expose the Firebase write-smoke capability through
  `miniprogram capabilities --json`

## 0.3.34

- fix `workflow status --remote` for Firebase environments so it reports
  Firebase publisher backend status/data checks instead of AWS-only provider
  mismatch errors
- add Firebase Firestore data export/import/redemptions commands using a
  provider-neutral logical record export format
- add guarded Firebase Functions cleanup through
  `publisher-backend firebase destroy --yes`, blocking when Firestore records
  exist unless `--confirm-data-loss` is passed

## 0.3.33

- fix Firebase Firestore seed/data status authentication by exchanging the
  Firebase CLI refresh token for a fresh OAuth access token before calling the
  Firestore REST API
- continue accepting `FIREBASE_TOKEN` for CI, treating it as a Firebase CLI
  refresh token when possible

## 0.3.32

- improve Firebase publisher backend deploy reliability by avoiding reserved
  Firebase `.env` keys and reporting public invoker setup details
- add Firebase Firestore starter data seeding and data status commands for
  Cloud Functions v2 publisher backends

## 0.3.31

- add Firebase publisher backend `deploy`, `status`, `outputs`, and read-only
  `smoke` commands for scaffolded Cloud Functions v2 + Firestore backends
- support `env configure --provider firebase` with project, region, function
  name, and optional function URL settings

## 0.3.30

- add `publisher-backend scaffold --template firebase-functions --storage firestore`
  for a Firebase Cloud Functions v2 + Firestore publisher backend foundation
- report Firebase publisher backend scaffolds in `workflow status --json` and
  expose the Firebase scaffold capability through `miniprogram capabilities`

## 0.3.29

- add `miniprogram capabilities [--json]` so tools such as the VS Code
  extension can detect supported AWS publisher backend workflows with one
  stable command instead of repeated help probes

## 0.3.28

- add AWS DynamoDB publisher backend data export/import commands, redemption
  inspection, and safer stack destroy checks that require explicit data-loss
  confirmation when stack-owned DynamoDB data exists

## 0.3.27

- improve AWS DynamoDB publisher backend reliability with cold-start-aware
  deploy health checks, retried seed batch writes, paginated data status counts,
  consistent Lambda reads, and opt-in write smoke testing

## 0.3.26

- add opt-in DynamoDB storage for scaffolded AWS Lambda publisher backends,
  including `publisher-backend aws seed` and `publisher-backend aws data status`

## 0.3.25

- add `publisher-backend aws smoke` to verify deployed AWS publisher backend
  read-only routes in one command

## 0.3.24

- fix generated AWS publisher backend Lambda handlers so API Gateway stage
  prefixes such as `/prod` are stripped before route matching

## 0.3.23

- add `publisher-backend scaffold --template aws-lambda` for a publisher-owned
  AWS Lambda + API Gateway business API starter
- add `publisher-backend aws deploy|status|outputs|logs|destroy` using the
  configured AWS environment for region/profile/SAM bucket defaults
- write `.mini_program/publisher_backend.aws.json` with last deploy outputs and
  report AWS publisher backend state in `workflow status --json`
- keep AWS publisher backend separate from mini-program delivery; host apps only
  need the resulting `--backend-base-url`

## 0.3.22

- add `host endpoint add --backend-local-mock` and
  `--backend-local-mock-port` for local publisher backend host config
- write endpoint `backendMode` metadata for diagnostics and IDE workflows
- update generated host and preview dependency constraints to
  `mini_program_sdk: ^0.3.5`
- clarify mock backend URL guidance for Chrome, desktop, Android emulator, and
  real devices

## 0.3.21

- fix generated `mini_program_registry.dart` so `byAppId` uses literal string
  keys and analyzes cleanly in host apps
- fix mock publisher backend CORS headers so Chrome/web host apps can call the
  backend connector's default MiniProgram headers

## 0.3.20

- add opt-in mock publisher backend starter with
  `miniprogram create --with-backend mock`
- add `miniprogram publisher-backend scaffold|run|status|stop|urls` for local
  business API testing beside a mini-program
- generate backend-driven starter UI using `miniProgramBackendBuilder(...)`,
  list item bindings, mock auth/session data, and image URLs
- report publisher backend starter presence in `workflow status --json`

## 0.3.19

- generate `miniProgramBackendQueryAction(...)` and
  `miniProgramBackendBuilder(...)` helpers for publisher backend query, state,
  and simple `{{backend.*}}` / `{{item.*}}` bindings
- update generated mini-program README guidance with backend binding examples
  and batch/cache/relative-endpoint recommendations
- update generated host adapters and preview hosts to depend on
  `mini_program_sdk: ^0.3.4`

## 0.3.18

- add publisher-owned backend endpoint metadata to host endpoint add/import and
  partner handoff packages with optional `--backend-base-url`
- generate `MiniProgramBackendEndpoint` config in host endpoint maps and wire
  generated runtime setup to the lazy endpoint-routing backend connector
- generate `miniProgramBackendAction(...)` in mini-program helper code and
  report backend configuration in workflow status without printing secrets

## 0.3.17

- fix standalone mini-program path resolution so commands run from a
  mini-program root prefer the current directory before an accidental nested
  `./<appId>` folder
- add a regression test for preview/build roots that contain a nested folder
  with the same mini-program id

## 0.3.16

- make `miniprogram host endpoint add/import` update both
  `mini_program_endpoints.dart` and `mini_program_registry.dart` so host apps
  can keep appId/title metadata in one generated place
- add optional `--title` to `host endpoint add`; partner imports reuse the
  title from the partner handoff file
- generate registry `values` and `byAppId` helpers for many-mini-program host
  apps
- include host registry appIds in `workflow status --json`

## 0.3.15

- add `miniprogram embed init --with-demo` to generate a public jsDelivr demo
  endpoint, mini-program registry, and README button snippet for first-run host
  app testing without AWS or access keys
- update generated host adapters and preview hosts to depend on
  `mini_program_sdk: ^0.3.2`

## 0.3.14

- add the MiniProgram Tools VS Code Marketplace link and install command to
  the README so CLI users can discover the sidebar workflow extension

## 0.3.13

- add `miniprogram publish --target static --clean` to safely remove generated
  static delivery output before writing a new public version
- generate `.nojekyll` for GitHub Pages static delivery exports
- add `.gitignore` to newly scaffolded mini-programs so local Dart/Stac build
  cache folders are not committed accidentally
- expand public GitHub Pages delivery docs with clean-repo guidance

## 0.3.12

- add `miniprogram publish --target static --output <folder>` for public
  GitHub Pages/CDN/static-hosting mini-program delivery
- add public endpoint support with `miniprogram host endpoint add --public`
  and schema v2 partner handoff packages using `accessMode`
- keep protected AWS/backend delivery unchanged while reporting public vs
  protected endpoint mode in workflow status

## 0.3.11

- make generated host runtime setup log endpoint routing when
  `buildMiniProgramConfig(endpoints: ...)` is used, instead of always printing
  the local fallback backend URL
- keep endpoint routing logs secret-safe by reporting only endpoint appIds and
  counts, not MiniProgram access-key values

## 0.3.10

- refresh generated host adapter README guidance with an optional typed
  `MiniProgramInfo`/`MiniPrograms` registry pattern for host apps that open
  many mini-programs
- document why keeping `appId` and title together helps avoid repeated string
  typos across buttons, menus, analytics, and tests

## 0.3.9

- add `miniprogram workflow status` with local-first workspace detection for
  mini-program and embedded host app projects
- add machine-readable `--json` output to workflow, doctor, env, backend,
  cloud status, and access-key list commands for future VS Code sidebar
  integration
- keep workflow status redacted by reporting access-key presence, IDs, and
  counts without printing endpoint or partner package secrets

## 0.3.8

- expand README host integration examples with a copy-paste
  `MiniProgramScope(config: buildMiniProgramConfig(endpoints: ...))`
  `MaterialApp` demo
- document how `MiniProgramScope` composes with app-owned Riverpod, Provider,
  and Bloc root wrappers without adding SDK dependencies on those packages
- refresh generated host adapter README guidance so state management and
  endpoint-map setup stay clear for new host app developers

## 0.3.7

- add `miniprogram partner package` to generate a portable JSON handoff file
  containing appId, title, API base URL, and a MiniProgram access key for a
  host company or partner
- add `miniprogram host endpoint import` so host teams can import a partner
  handoff package directly into the generated `mini_program_endpoints.dart`
  endpoint map
- document the partner handoff flow as the developer-friendly path for one
  host app that includes mini-programs from many publishers and cloud providers

## 0.3.6

- add `miniprogram access-key create|list|revoke|rotate` so teams can manage
  per-mini-program MiniProgram access keys without hand-editing S3 metadata
- add `miniprogram cloud app list|info|disable|delete` for inspecting active
  cloud catalogs, disabling a mini-program without deleting release artifacts,
  and safely dry-running destructive cleanup before `--yes`
- add `miniprogram host endpoint add` to generate/update a host-owned
  `mini_program_endpoints.dart` map for many publishers and cloud providers,
  keeping UI launch code appId-only
- document the multi-publisher flow where each endpoint is protected by a
  MiniProgram access key and host apps call `openAppMiniProgram` with only the
  appId

## 0.3.5

- fix generated AWS delivery handlers so async route failures, including
  MiniProgram access-key rejections, are converted into structured HTTP
  responses instead of escaping as Lambda 500s
- fix generated managed preview hosts to keep hosted package constraints in
  `dependencies` and use repo-local `dependency_overrides` only when a local
  platform repo is available

## 0.3.4

- update generated host adapters to accept an optional
  `Map<String, MiniProgramEndpoint>` for multi-publisher endpoint routing
- update the AWS delivery backend template to validate per-mini-program
  MiniProgram access keys from `metadata/access_keys/<appId>.json`
- add `miniprogram env configure --require-access-keys` for strict AWS
  delivery deployments
- bump generated host dependencies to `mini_program_sdk: ^0.3.0` and
  `mini_program_contracts: ^0.1.1`

## 0.3.3

- make `miniprogram embed init` generate a lean default host adapter without
  native route alias files or sample native pages
- keep native route opening available as an app-owned optional
  `buildMiniProgramConfig(openNativeRoute: ...)` hook

## 0.3.2

- make `miniprogram create <id>` default to the minimal `analytics` capability
  so the generated mini-program opens in a simple `MiniProgramScope` host
  without native-route wiring
- keep `native_navigation` available as an explicit opt-in through
  `--capabilities analytics,native_navigation`

## 0.3.1

- export `mini_program_sdk` from the generated mini-program adapter barrel so
  `MiniProgramScope` is available from `mini_program/mini_program.dart`
- add an explicit `package:mini_program_sdk/mini_program_sdk.dart` import to
  generated host app examples for clearer IDE completion and diagnostics

## 0.3.0

- update `miniprogram embed init` to generate `MiniProgramScope` integration
  helpers instead of `MiniProgramAppShell`
- generate `buildMiniProgramConfig(...)` and scope-based launcher helpers while
  leaving `MaterialApp`, routes, navigator keys, themes, and routers app-owned
- bump generated host and preview app dependencies to `mini_program_sdk: ^0.2.0`

## 0.2.33

- add Android release `INTERNET` permission to generated embedded host apps so
  release APKs can load cloud-delivered mini-programs through API Gateway
- expand `miniprogram --help` and group-level `--help` output to show current
  cloud, host-run, embed-cloud, and publish target options
- refresh root and tooling README guidance for AWS cloud delivery, multi
  mini-program buckets, host app connection, and Android release networking

## 0.2.32

- disable Flutter hot reload for the managed preview host because
  `miniprogram preview` already owns watch/rebuild/refresh; this avoids a
  Windows Flutter tool crash where locked `build/*.dill` cache files can make
  Chrome preview fail on startup

## 0.2.31

- update the bundled AWS SAM backend template from Lambda `nodejs20.x` to
  `nodejs24.x` so new `miniprogram cloud deploy` stacks avoid the Node.js 20
  runtime deprecation window
- update generated host and preview app dependencies to
  `mini_program_sdk: ^0.1.3`
- expand host-app documentation with a complete `main.dart` example, generated
  adapter structure, AWS API-backed APK build command, and guidance for where
  `BackendApiBaseUrl`, API base URLs, and optional CloudFront domains come from
- refresh the generated `lib/mini_program/README.md` so embedded host apps show
  the same cloud run and release APK guidance after `miniprogram embed init`

## 0.2.30

- fix AWS cloud commands on Windows by launching `sam` with shell resolution,
  which avoids false "sam not found" failures when `sam --version` already
  works in PowerShell
- rewrite the AWS setup guidance in the root README and tooling README around
  the full developer path:
  - account bootstrap
  - CLI credential setup
  - S3 bucket creation and versioning
  - `miniprogram publish --target cloud`
  - `miniprogram cloud deploy`
  - embedded host app connection with `embed cloud configure` and `host run`
- remove repo-`infra` focused wording from the main developer entry-point docs
  so published-package users see the bundled AWS cloud workflow first

## 0.2.29

- add `miniprogram cloud outputs --format dart-define` for copy-paste host
  runtime configuration
- add `miniprogram embed cloud configure --env <env-name>` to bind an embedded
  Flutter host app to a named cloud environment through
  `.mini_program/host_cloud.json`
- add `miniprogram host run -d <device> --env <env-name>` to wrap
  `flutter run` with the resolved `MINI_PROGRAM_BACKEND_BASE_URL`
- add the new host-cloud state model and CLI regression coverage for the AWS
  embedded-host workflow

## 0.2.28

- add named cloud environment management with:
  - `miniprogram env configure <env-name> --provider aws`
  - `miniprogram env list`
  - `miniprogram env use <local|env-name>`
- implement the first cloud publish path with:
  - `miniprogram publish --target cloud`
  - `miniprogram publish --target cloud --env <env-name>`
- add AWS cloud publish support that:
  - builds the mini-program with the managed Stac builder
  - requires S3 bucket versioning to be enabled
  - uploads immutable release artifacts to S3
  - uploads release and catalog metadata JSON records for later discovery and
    rollout services
- add the shared cloud publisher abstraction so `gcp` and
  `custom-s3-compatible` can plug into the same CLI model later
- update root and tooling docs for the named cloud-environment workflow and
  record the completed preview milestone in `nextWorkAgents.md`

## 0.2.27

- add managed preview support for Microsoft Edge with
  `miniprogram preview -d edge`
- add managed preview support for Linux desktop with
  `miniprogram preview -d linux`
- add managed preview support for macOS desktop with
  `miniprogram preview -d macos`
- add managed preview support for iOS simulator workflows on macOS with
  `miniprogram preview -d ios`
- extend the hidden managed preview host generator and regression coverage for
  the new Edge, Linux, macOS, and iOS preview targets

## 0.2.26

- prefer `adb reverse tcp:<port> tcp:<port>` for Android emulator preview and
  fall back to `10.0.2.2` only when reverse cannot be applied
- add managed preview support for Android Wi-Fi physical-device targets such as
  `miniprogram preview -d 192.168.1.25:5555`
- resolve a reachable LAN host for Android Wi-Fi preview sessions and allow
  overriding it with `MINI_PROGRAM_PREVIEW_LAN_HOST`
- widen the generated Android preview-host debug cleartext config so LAN-based
  preview transport works across emulator, USB, and Wi-Fi device flows
- add regression coverage for emulator reverse fallback and Android Wi-Fi
  preview launch behavior

## 0.2.25

- add managed preview support for Android emulator targets such as
  `miniprogram preview -d emulator-5554`
- add managed preview support for Android USB physical-device targets with
  automatic `adb reverse` setup and `127.0.0.1` preview transport
- extend the hidden managed preview host to generate Android platform files and
  Android debug cleartext/network security config when needed
- add regression coverage for Android emulator and Android USB preview launch
  flows

## 0.2.24

- clear transient managed preview-host build output before every
  `miniprogram preview` launch so repeated Chrome preview sessions do not
  reuse stale shader artifacts and crash on startup
- remove stale preview-host crash logs as part of the same launch reset
- add regression coverage for preview-host reuse with pre-existing build files

## 0.2.23

- replace the route-heavy starter scaffold with a cleaner two-screen
  profile/settings default built around `home` and `details`
- remove the generated `..._route_demo.dart` screen from new mini-program
  scaffolds
- keep advanced portable routing helpers available in
  `lib/host_action_helpers.dart`, but move their usage into commented examples
  and README guidance instead of visible starter buttons
- add regression coverage for the new realistic default scaffold flow

## 0.2.22

- replace the default scaffold's host-native demo actions with a safer
  portable routing starter flow built around three mini-program screens
- demonstrate the shared mini-program navigation actions by default:
  `openMiniProgramScreen`, `replaceMiniProgramScreen`,
  `resetMiniProgramStack`, `popMiniProgramScreen`,
  `popToMiniProgramRoot`, and `popToMiniProgramScreen`
- keep `native_navigation` and `secure_api` as capability notes in the starter
  scaffold instead of generating fake production route and backend calls
- add regression coverage for the new three-screen portable starter flow

## 0.2.21

- reduce the generated starter-screen body top spacing by switching scaffolded
  body padding from `StacEdgeInsets.all(24)` to horizontal-only padding
- replace the raw JSON dump in the preview native placeholder with a clearer
  structured inspector for route, expect-result, and argument details
- add regression coverage for the updated starter-screen layout and preview
  placeholder output

## 0.2.20

- remove the extra scaffolded `StacSafeArea` wrapper from generated starter
  screens so mini-program bodies do not render with confusing blank space
  below the app bar
- add regression coverage to keep new generated screens on the direct
  `StacSingleChildScrollView` body layout

## 0.2.19

- fix preview watch mode so build output updates under `stac/.build` do not
  trigger repeated follow-up rebuilds after a single save
- add regression coverage for exact ignored preview-build directory events in
  the watcher path filter

## 0.2.18

- remove the extra preview-shell app bar so `miniprogram preview` shows the
  mini-program UI directly instead of wrapping it in a second host header
- stop the preview status poll from rebuilding the UI every second when
  nothing changed, which fixes the visible jumping and repeated refresh effect
- keep the preview status banner overlaid on top of the page instead of
  shifting layout during preview status changes

## 0.2.17

- add `miniprogram preview -d <chrome|windows>` as the new developer-first
  preview loop for standalone mini-program authoring
- generate and manage a hidden project-local preview host under
  `.mini_program/preview_host`
- serve preview manifests, screens, and assets through an internal
  session-scoped preview server instead of the real local backend workspace
- watch mini-program source files, rebuild on save, and trigger full preview
  refresh while keeping the last good UI visible on rebuild failures
- document the preview flow, its capability limits, and how it differs from
  the real `publish` plus `backend start` delivery path

## 0.2.16

- fix local Chrome and web host-app development by making the generated local
  backend workspace respond correctly to browser CORS preflights and private
  network access checks for `127.0.0.1:8080`
- make `miniprogram backend start` and `miniprogram backend status` print the
  target-specific local backend URLs for Android emulator, desktop or Chrome,
  and Android USB `adb reverse` workflows
- make generated host runtime setup log the resolved backend base URL and its
  resolution source during startup for faster local debugging

## 0.2.15

- make generated host adapters use the shared SDK local-backend resolver with
  target-aware defaults instead of hardcoded per-file backend URL logic
- add generated support for `MINI_PROGRAM_BACKEND_BASE_URL`,
  `MINI_PROGRAM_BACKEND_HOST`, and `MINI_PROGRAM_BACKEND_PORT`
- bump generated host app dependencies to `mini_program_sdk: ^0.1.2`
- document the local backend conditions for emulator, desktop, Chrome, USB
  `adb reverse`, and physical-device Wi-Fi workflows

## 0.2.14

- fix `miniprogram embed init` so generated host app `pubspec.yaml` files pin
  `mini_program_sdk: ^0.1.1` instead of the stale `^0.1.0` constraint
- refresh the embedding docs and regression tests around the generated hosted
  SDK dependency version

## 0.2.13

- make local backend start attempt `adb reverse tcp:<port> tcp:<port>` for
  connected Android devices and emulators so local host apps can keep using
  `127.0.0.1` when emulator routing to `10.0.2.2` is broken
- report successful `adb reverse` setup in backend start output
- add regression coverage for the new local Android reverse-port setup

## 0.2.12

- make `embed init` generate Android debug-only cleartext/network security
  config so the default local emulator backend URL can work without manual
  manifest edits
- refresh the tooling docs around the generated Android local-backend setup and
  align the public CLI surface with the optional in-folder
  `build`/`validate`/`publish` flow

## 0.2.11

- fix backend workspace resolution so `validate`, `publish`, backend commands,
  and `doctor` fall back to the valid global backend workspace when a stale
  parent `.mini_program/backend_workspace.json` is present
- add regression coverage for stale local backend workspace state masking the
  initialized global backend workspace

## 0.2.10

- let `miniprogram build`, `miniprogram validate`, and `miniprogram publish`
  infer the mini-program id from the current working directory when the user is
  already inside the mini-program root
- keep the explicit forms such as `miniprogram build <id>` and
  `miniprogram publish <id>` for scripted and multi-project workflows
- refresh docs and tests around the simpler in-folder authoring workflow

## 0.2.9

- make `miniprogram backend init` default to the per-user global backend
  workspace on Windows at `%LOCALAPPDATA%\mini_program\backend\`
- keep `miniprogram backend init --root <path>` as the explicit override for a
  custom backend workspace
- document the generated local backend URL defaults so Android emulator
  workflows can usually run with plain `flutter run -d emulator-5554` when the
  backend is already running on port `8080`
- refresh the generated embed README, public docs, and tests around the local
  backend URL defaults and `MINI_PROGRAM_BACKEND_BASE_URL` override

## 0.2.8

- let `miniprogram embed init` default to the current working directory when
  `--project-root` is omitted
- keep `miniprogram embed init --project-root <path>` for explicit and scripted
  workflows
- refresh docs, tests, and installed-CLI smoke coverage for the simpler embed
  flow

## 0.2.7

- manage a pinned Stac builder internally inside `mini_program_tooling`
- expose the managed pinned Stac builder status and version through
  `miniprogram doctor`
- keep `--stac-cli-script` as the escape hatch while removing the normal need
  for a separate visible `stac` install

## 0.2.6

- let `miniprogram env init` succeed without a saved platform repo root for the
  standalone workflow
- let standalone `validate` and `publish` run against `backend init`
  workspaces without any platform repo path
- update `embed init` to patch host app `pubspec.yaml` with hosted
  `mini_program_sdk` and `mini_program_contracts` dependencies
- refresh docs and the installed-CLI smoke flow around the fully standalone
  local workflow

## 0.2.5

- add `miniprogram backend init` to scaffold a standalone backend workspace
- add tracked backend workspace state in `.mini_program/backend_workspace.json`
  and `~/.mini_program/global_backend_workspace.json`
- let backend lifecycle commands resolve either a standalone backend workspace
  or the platform repo layout
- make `miniprogram publish` write manifests and screens into the initialized
  standalone backend workspace when `miniprogram backend init` has been used
- keep tracked local publish state attached to that backend workspace so
  `backend reset-local --yes` cleans the correct local backend
- update validation and installed-CLI smoke coverage for the standalone backend
  publish flow

## 0.2.2

- add `miniprogram doctor` for machine, env, repo, and backend diagnostics

## 0.2.1

- refresh the pub.dev release metadata for the current env-based workflow
- ship the saved global repo-root fallback used by `embed init` and backend
  commands when running from unrelated working directories

## 0.2.0

- add `miniprogram env init`, `miniprogram env use`, and
  `miniprogram env status`
- add `.mini_program/env.json` as saved CLI environment state for standalone
  mini-program workspaces
- add a user-level fallback config in `~/.mini_program/global_env.json` so
  `embed init` and backend commands can reuse the saved repo root from
  unrelated working directories
- let `build`, `validate`, `publish`, and `backend ...` reuse saved repo-root
  configuration instead of requiring repeated `--repo-root`
- update the installed CLI smoke flow and docs around the new env workflow

## 0.1.0

- add the global `miniprogram` executable
- add `create`, `build`, `validate`, `publish`, and `embed init` commands
- add repo-local backend lifecycle commands for `start`, `status`, `stop`, and
  `reset-local`
- add repo-local CLI state tracking under `.mini_program/`
