# MiniProgram Tools

VS Code extension for MiniProgram CLI workflows.

The extension is a UI wrapper around the installed `miniprogram` CLI. It does
not replace the CLI. It prompts for common inputs, runs the matching CLI command,
shows output in the `MiniProgram` output channel, and refreshes workspace status.

Current platform boundary:

- mini-program UI is published as public static artifacts
- host apps open mini-programs with `appId + artifactBaseUrl`
- runtime middle-server API config is optional
- auth, database, payments, storage, secrets, and business rules belong behind a publisher-owned API

For the beginner static-only workflow, start here:
[Quickstart: static mini-program to host app](../../docs/quickstart_static_miniprogram_to_host.md).

## Requirements

Install the CLI first:

```powershell
dart pub global activate mini_program_tooling
miniprogram doctor
```

On Windows, make sure the Dart pub global bin folder is on `PATH`:

```powershell
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
```

Open a mini-program folder or Flutter host app folder in VS Code before running
workspace commands.

## Settings

Use VS Code settings to change extension behavior:

| Setting | Default | Use when |
| --- | --- | --- |
| `miniProgram.cliPath` | `miniprogram` | The CLI is installed at a custom path or you want to test a local CLI build. |
| `miniProgram.defaultPreviewDevice` | `emulator-5554` | You usually preview on Chrome, Windows, or another device ID. |
| `miniProgram.status.autoRefresh` | `true` | You want the Status view to refresh when the extension activates or workspace changes. |

Common device values:

```text
chrome
edge
windows
emulator-5554
```

## How The Extension Works

Most commands follow this pattern:

1. Detect the current workspace.
2. Ask for missing values such as app ID, output folder, device, or URL.
3. Run the matching `miniprogram ...` command.
4. Write logs to the `MiniProgram` output channel.
5. Refresh the MiniProgram Status view.

Preview and host run commands open a VS Code terminal because they start
long-running Flutter processes.

## Activity Bar And Status View

Click the MiniProgram icon in the VS Code Activity Bar to open the Status view.

The Status view shows:

- `Workspace`: detected workspace type, readiness, severity, and path
- `Mini-program`: app ID, version, build output, validation, partner packages, and optional Publisher API usage
- `Host app`: generated runtime setup, endpoint map, static artifacts, runtime Publisher APIs, and routing state
- `Local environment`: legacy/local environment state
- `Artifact host`: local static artifact host status
- `Next actions`: the next recommended commands

Use `MiniProgram: Refresh Status` after editing files or running commands
outside VS Code.

## Title-Bar Icon Buttons

The Status view title bar has small icon buttons. Hover each icon in VS Code to
see its command name.

| Icon command | Use when | What it does |
| --- | --- | --- |
| `Refresh Status` | You changed files or ran CLI commands externally. | Runs `miniprogram workflow status --json`. |
| `Setup New MiniProgram` | You want the guided beginner create flow. | Creates, builds, validates, and can open the new folder. |
| `Diagnose Workspace` | Something is not working and you want a checklist. | Runs workflow status, doctor, and extension diagnostics. |
| `Add MiniProgram to Host` | You opened a host app and need to import/add an endpoint. | Guides partner package import or manual endpoint add. |
| `Run Host Smoke Test` | The host is wired and you want to run it. | Diagnoses the host, then starts `miniprogram host run`. |
| `Copy Demo Host Button` | You need a Flutter button snippet. | Copies `openAppMiniProgram(...)` code to the clipboard. |
| `Copy Workflow Commands` | You want terminal commands for the current workspace. | Copies publisher or host command templates. |
| `Check Host Endpoint` | You want to inspect an imported endpoint. | Runs host diagnostics for the selected endpoint. |
| `Copy Cleanup Commands` | You want local cleanup commands. | Copies local workspace cleanup commands; no provider cleanup is needed. |
| `Artifact Host Status` | You use the optional local static artifact host. | Runs `miniprogram artifact-host status --json`. |
| `Run Mock Publisher API` | You scaffolded a local mock API and want to run it. | Runs `miniprogram publisher-api run`. |
| `Mock Publisher API Status` | You need mock API state. | Runs `miniprogram publisher-api status --json`. |
| `Init Publisher API Contract` | You have a middle-server URL to register for runtime API smoke checks. | Creates `publisher_backend.json`. |
| `Validate Publisher API Contract` | You edited the runtime API contract. | Validates `publisher_backend.json`. |
| `Smoke Test Publisher API Contract` | You want to test the middle-server API. | Calls health/routes defined by the contract. |
| `Copy Mock Publisher API URLs` | You need local mock URLs. | Copies `publisher-api urls` output. |
| `Copy Mock Publisher API Host Command` | You want a terminal command to add a local mock runtime API to a host endpoint. | Copies `miniprogram host endpoint add ... --backend-local-mock ...`. |
| `Prepare Partner Handoff` | You are ready to publish and share a mini-program. | Builds, validates, publishes static artifacts, creates and validates a partner package. |
| `Publish Public Static MiniProgram` | You want GitHub Pages/CDN-ready files. | Runs static publish into a chosen output folder. |

## Static Mini-Program Workflow

Use this for Track 1: no backend, no runtime API.

### 1. Create

Command Palette:

```text
MiniProgram: Create MiniProgram
```

When to use it:

- starting a new mini-program
- creating a simple static demo
- creating a project you will later edit by hand

What it asks:

- parent folder
- app ID
- title
- optional mock Publisher API starter
- overwrite mode if the target folder already exists

CLI equivalent:

```powershell
miniprogram create my_profile --screen-format mp --output-root D:\ --title "My Profile"
```

After create, the extension offers to open the new folder.

### 2. Edit

Edit these files in the generated mini-program:

```text
mp/program.dart
mp/screens/*.dart
manifest.json
```

Do not edit generated build output under `mp/.build`.

### 3. Preview

Command Palette:

```text
MiniProgram: Preview
```

When to use it:

- checking UI while editing
- testing navigation between screens
- testing static data

What it asks:

- device ID, defaulting to `miniProgram.defaultPreviewDevice`

CLI equivalent:

```powershell
miniprogram preview -d chrome --mini-program-root <workspace>
```

The command opens a VS Code terminal named `MiniProgram Preview`.

### 4. Build

Command Palette:

```text
MiniProgram: Build
```

When to use it:

- before validation
- before static publish
- after changing `mp/program.dart` or screen files

CLI equivalent:

```powershell
miniprogram build --mini-program-root <workspace>
```

Build writes screen JSON under `mp/.build/screens/`.

### 5. Validate

Command Palette:

```text
MiniProgram: Validate
```

When to use it:

- before publishing
- after changing manifest or screen structure
- when host opening fails and you want to check artifact input

CLI equivalent:

```powershell
miniprogram validate --mini-program-root <workspace>
```

### 6. Publish Public Static MiniProgram

Command Palette:

```text
MiniProgram: Publish Public Static MiniProgram
```

When to use it:

- generating `public_mini_program`
- publishing to GitHub Pages, CDN, object storage, or any HTTPS static file host

What it asks:

- output folder, normally `public_mini_program`
- whether to clean generated output first

CLI equivalent:

```powershell
miniprogram publish --target static `
  --mini-program-root <workspace> `
  --output <workspace>\public_mini_program `
  --clean
```

Upload the contents of `public_mini_program` to a public static host.

For GitHub Pages, the final `artifactBaseUrl` is usually:

```text
https://<github-user>.github.io/<repo-name>/
```

### 7. Create Partner Package

Command Palette:

```text
MiniProgram: Create Partner Package
```

When to use it:

- after static artifacts are already hosted
- when a host app developer needs a small JSON handoff

What it asks:

- app ID
- display title
- public static artifact base URL
- output file path

CLI equivalent:

```powershell
miniprogram partner package my_profile `
  --artifact-base-url https://<github-user>.github.io/my_profile_static/ `
  --output <workspace>\my_profile.partner.json
```

The partner package is static-opening config only. It does not require backend
credentials.

### 8. Validate Or Open Partner Package

Command Palette:

```text
MiniProgram: Validate Partner Package
MiniProgram: Open Partner Package
```

Use `Validate Partner Package` before sharing the file with a host developer.
It checks the JSON shape and confirms the app ID, title, and artifact base URL.

Use `Open Partner Package` when you want to inspect the file or reveal its
folder.

## Guided Publisher Buttons

These commands combine multiple steps:

| Command | Use when | Steps |
| --- | --- | --- |
| `MiniProgram: Setup New MiniProgram` | You want a guided create flow. | Create, build, validate. |
| `MiniProgram: Prepare Partner Handoff` | You are ready to publish and share. | Build, validate, publish static, create partner package, validate partner package. |
| `MiniProgram: Copy Workflow Commands` | You prefer running the rest in terminal. | Copies the matching command template to the clipboard. |
| `MiniProgram: Diagnose MiniProgram` | A mini-program build or publish path is broken. | Runs workspace status, doctor, and mini-program checks. |

## Host App Workflow

Use this in a Flutter host app workspace.

### 1. Embed Init

Command Palette:

```text
MiniProgram: Embed Init
```

When to use it:

- once per Flutter host app
- after `flutter create`
- when adding mini-program support to an existing app

What it asks:

- host project root
- normal or force mode

CLI equivalent:

```powershell
miniprogram embed init --project-root <host-project-root>
```

What it writes:

```text
lib/mini_program/
  app_host_bridge.dart
  mini_program.dart
  mini_program_launcher.dart
  mini_program_runtime_setup.dart
```

After importing or adding an endpoint, it also writes:

```text
lib/mini_program/
  mini_program_endpoints.dart
  mini_program_registry.dart
```

### 2. Import Host Endpoint

Command Palette:

```text
MiniProgram: Import Host Endpoint
```

When to use it:

- recommended path for host developers
- the publisher gave you a `.partner.json` file

What it asks:

- host project root
- partner package JSON file
- normal or force mode

CLI equivalent:

```powershell
miniprogram host endpoint import <mini-program>.partner.json --project-root <host-project-root>
```

### 3. Add Host Endpoint

Command Palette:

```text
MiniProgram: Add Host Endpoint
```

When to use it:

- you do not have a partner package
- you know the `appId` and public `artifactBaseUrl`
- you optionally need a runtime middle-server URL

What it asks:

- app ID
- display title
- static artifact base URL
- Publisher API mode: no backend, local mock, or remote API
- normal or force mode

CLI equivalent without runtime API:

```powershell
miniprogram host endpoint add my_profile `
  --artifact-base-url https://<github-user>.github.io/my_profile_static/ `
  --title "My Profile" `
  --project-root <host-project-root>
```

CLI equivalent with optional runtime API:

```powershell
miniprogram host endpoint add my_profile `
  --artifact-base-url https://<github-user>.github.io/my_profile_static/ `
  --backend-base-url https://publisher.example.com/api/ `
  --project-root <host-project-root>
```

`--backend-base-url` is the current CLI flag for the optional runtime
`middleServerApiUrl`. Static opening does not need it.

### 4. Copy Demo Host Button

Command Palette:

```text
MiniProgram: Copy Demo Host Button
```

When to use it:

- after importing or adding an endpoint
- when you want a quick button snippet for `lib/main.dart`

What it does:

- lets you choose an endpoint
- optionally writes a registry entry
- copies imports and an `openAppMiniProgram(...)` button snippet to the clipboard

Paste the snippet into host-owned UI.

### 5. Run Host App

Command Palette:

```text
MiniProgram: Run Host App
```

When to use it:

- after `Embed Init`
- after importing/adding an endpoint
- after adding a host button or menu item

What it asks:

- Flutter device ID

CLI equivalent:

```powershell
miniprogram host run -d chrome --project-root <host-project-root>
```

The command opens a VS Code terminal named `MiniProgram Host`.

## Guided Host Buttons

| Command | Use when | Steps |
| --- | --- | --- |
| `MiniProgram: Setup Host App` | You want the guided host setup path. | Runs `embed init`, then host diagnostics. |
| `MiniProgram: Add MiniProgram to Host` | You want the guided endpoint path. | Imports partner package or adds endpoint manually, then diagnoses the host. |
| `MiniProgram: Run Host Smoke Test` | You want a quick run check. | Diagnoses the host, then starts `host run`. |
| `MiniProgram: Generate Host Registry` | You imported endpoints and want a registry file. | Reads endpoints and writes `mini_program_registry.dart`. |
| `MiniProgram: Add MiniProgram to Registry` | You want to add/update one registry entry. | Prompts for endpoint and title, then updates the registry. |
| `MiniProgram: Check Host Endpoint` | Host endpoint is not opening. | Runs host diagnostics for the selected endpoint. |

## Optional Local Static Artifact Host

Most developers can use `Publish Public Static MiniProgram` and GitHub Pages.
Use these commands only when you want a local static artifact host workspace.

| Command | CLI equivalent | Use when |
| --- | --- | --- |
| `MiniProgram: Artifact Host Init` | `miniprogram artifact-host init` | Create local artifact host files. |
| `MiniProgram: Artifact Host Start` | `miniprogram artifact-host start --port 8080` | Serve local static artifacts. |
| `MiniProgram: Artifact Host Stop` | `miniprogram artifact-host stop` | Stop the local server. |
| `MiniProgram: Artifact Host Status` | `miniprogram artifact-host status --json` | Check if the local server is alive. |
| `MiniProgram: Publish` | `miniprogram publish --target static|local` | Choose static output or local artifact host publish. |

For beginner docs, prefer:

```text
MiniProgram: Publish Public Static MiniProgram
```

## Optional Publisher API Workflow

Use Publisher API commands only when the mini-program has runtime API actions
such as `Mp.backend.call`, `Mp.backend.query`, search/load-more, form submit, or
`Mp.lazy.chunk`.

Static mini-program opening does not require Publisher API setup.

For a concrete AWS Lambda/DynamoDB/JWT example, see
[Track 2: middle-server API with Lambda, DynamoDB, and JWT](../../docs/middle_server_api_lambda_dynamodb.md).

### Mock API Commands

| Command | CLI equivalent | Use when |
| --- | --- | --- |
| `MiniProgram: Setup Mock Publisher API` | `miniprogram publisher-api scaffold --template mock` | Create a local mock API starter. |
| `MiniProgram: Run Mock Publisher API` | `miniprogram publisher-api run --port 9090` | Start the local mock server. |
| `MiniProgram: Stop Mock Publisher API` | `miniprogram publisher-api stop` | Stop the local mock server. |
| `MiniProgram: Mock Publisher API Status` | `miniprogram publisher-api status --json` | Check mock server status. |
| `MiniProgram: Copy Mock Publisher API URLs` | `miniprogram publisher-api urls --port 9090` | Copy local URLs for preview/host testing. |
| `MiniProgram: Copy Mock Publisher API Host Command` | `miniprogram host endpoint add ... --backend-local-mock` | Copy a host endpoint command using the local mock API. |

### Contract Commands

| Command | CLI equivalent | Use when |
| --- | --- | --- |
| `MiniProgram: Init Publisher API Contract` | `miniprogram publisher-api contract init` | Create `publisher_backend.json` for a middle-server URL. |
| `MiniProgram: Validate Publisher API Contract` | `miniprogram publisher-api contract validate` | Check contract structure and URL policy. |
| `MiniProgram: Smoke Test Publisher API Contract` | `miniprogram publisher-api contract smoke` | Test the middle-server health/routes. |

The contract file is a runtime API standard. It is not host-opening config.

## Environment And Diagnostics Commands

| Command | Use when |
| --- | --- |
| `MiniProgram: Refresh Status` | Refresh the Status tree. |
| `MiniProgram: Diagnose Workspace` | Check whatever workspace is open. |
| `MiniProgram: Diagnose MiniProgram` | Check mini-program build, validation, partner package, and optional API usage. |
| `MiniProgram: Diagnose Host App` | Check generated host files, endpoints, routing, and Android basics. |
| `MiniProgram: Env Init` | Initialize legacy/local environment state. Most GitHub Pages workflows do not need this. |
| `MiniProgram: Use Environment` | Select the local environment. |
| `MiniProgram: Environment Status` | Print local environment JSON status. |
| `MiniProgram: Open Output` | Open the `MiniProgram` output channel. |

## Recommended Beginner Flow

Publisher mini-program workspace:

1. `MiniProgram: Create MiniProgram`
2. edit `mp/program.dart` and `mp/screens/*.dart`
3. `MiniProgram: Preview`
4. `MiniProgram: Build`
5. `MiniProgram: Validate`
6. `MiniProgram: Publish Public Static MiniProgram`
7. upload `public_mini_program` contents to GitHub Pages
8. `MiniProgram: Create Partner Package`

Host app workspace:

1. `MiniProgram: Embed Init`
2. `MiniProgram: Import Host Endpoint`
3. `MiniProgram: Copy Demo Host Button`
4. paste the snippet into host UI
5. `MiniProgram: Run Host App`

## Common Problems

- Command fails with `miniprogram` not found: install the CLI and fix `PATH`, or set `miniProgram.cliPath`.
- Status view says no workspace: open the mini-program folder or Flutter host app folder, not only a single file.
- Preview opens the wrong device: change `miniProgram.defaultPreviewDevice` or enter `chrome` when prompted.
- Host cannot open the mini-program: verify the `artifactBaseUrl` and open `manifests/<appId>/latest.json` in a browser.
- Runtime API fails but static opening works: check the optional Publisher API URL/contract; host opening does not require it.
- Android build fails after embedding: run `flutter pub get`, check Android manifest/network setup, then use diagnostics.
