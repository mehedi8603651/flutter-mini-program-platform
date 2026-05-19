# MiniProgram Tools

Native VS Code sidebar for MiniProgram CLI workflows.

This extension is a thin UI over the installed `miniprogram` CLI. It does not
reimplement create, build, validate, publish, preview, AWS, access-key, partner
package, host endpoint, or backend logic.

## Marketplace install

Requires `mini_program_tooling` 0.3.13 or newer for public/static endpoint
support and `miniprogram workflow status --json`.

Install or upgrade the CLI first:

```bash
dart pub global activate mini_program_tooling
```

Then install the extension from VS Code Marketplace:

```bash
code --install-extension MiniProgramTools.mini-program-tools
```

You can also install it from the VS Code Extensions view by searching for
`MiniProgram Tools`.

## Local VSIX install

Use this only when testing an unreleased extension build locally.

```bash
cd packages/mini_program_vscode
npm install
npm run compile
npm run package:vsix
code --install-extension mini-program-tools-0.1.12.vsix
```

## Features

- Activity Bar view named `MiniProgram`.
- Local workflow status from `miniprogram workflow status --json`.
- Manual remote status from `miniprogram workflow status --remote --json`.
- Core workflow commands:
  - `MiniProgram: Create MiniProgram`
  - `MiniProgram: Build`
  - `MiniProgram: Validate`
  - `MiniProgram: Preview`
  - `MiniProgram: Publish`
  - `MiniProgram: Publish Public Static MiniProgram`
  - `MiniProgram: Embed Init`
  - `MiniProgram: Configure Host Cloud`
  - `MiniProgram: Import Host Endpoint`
  - `MiniProgram: Add Host Endpoint`
  - `MiniProgram: Run Host App`
  - `MiniProgram: Env Init`
  - `MiniProgram: Configure AWS Environment`
  - `MiniProgram: Use Environment`
  - `MiniProgram: Environment Status`
  - `MiniProgram: Cloud Deploy`
  - `MiniProgram: Cloud Status`
  - `MiniProgram: Cloud Outputs`
  - `MiniProgram: Backend Init`
  - `MiniProgram: Backend Start`
  - `MiniProgram: Backend Stop`
  - `MiniProgram: Backend Status`
  - `MiniProgram: Create Access Key`
  - `MiniProgram: List Access Keys`
  - `MiniProgram: Revoke Access Key`
  - `MiniProgram: Rotate Access Key`
  - `MiniProgram: Create Partner Package`
  - `MiniProgram: Validate Partner Package`
  - `MiniProgram: Open Partner Package`
  - `MiniProgram: Diagnose Workspace`
  - `MiniProgram: Diagnose MiniProgram`
  - `MiniProgram: Diagnose Host App`
  - `MiniProgram: Diagnose Cloud Delivery`
  - `MiniProgram: Setup New MiniProgram`
  - `MiniProgram: Publish MiniProgram to AWS`
  - `MiniProgram: Prepare Partner Handoff`
  - `MiniProgram: Setup Host App`
  - `MiniProgram: Add MiniProgram to Host`
  - `MiniProgram: Run Host Smoke Test`
  - `MiniProgram: Generate Host Registry`
  - `MiniProgram: Add MiniProgram to Registry`
  - `MiniProgram: Copy Demo Host Button`
  - `MiniProgram: Copy Workflow Commands`
  - `MiniProgram: Check Host Endpoint Remote`
  - `MiniProgram: Copy Cleanup Commands`
  - `MiniProgram: Refresh Status`
  - `MiniProgram: Refresh Remote Status`

`MiniProgram: Publish` supports cloud, local, and public/static export targets.
`MiniProgram: Publish Public Static MiniProgram` opens the static export flow
directly and can pass `--clean` to remove generated static output before writing
the new version. The static target writes a folder that can be uploaded to
GitHub Pages or a CDN and then used from a public endpoint.

## Settings

- `miniProgram.cliPath`: command or path for the installed CLI. Defaults to
  `miniprogram`.
- `miniProgram.defaultPreviewDevice`: default preview device. Defaults to
  `emulator-5554`.
- `miniProgram.status.autoRefresh`: refresh local status on activation and
  workspace changes. Defaults to `true`.

Remote status checks are never automatic. Use `MiniProgram: Refresh Remote
Status` when you want cloud/backend checks.

## Environment and backend workflow

Use `MiniProgram: Env Init` in a mini-program or host workspace before
configuring cloud delivery. `MiniProgram: Configure AWS Environment` prompts for
the environment name, S3 bucket, region, optional AWS profile, stack/stage names,
and access-key enforcement. `MiniProgram: Cloud Deploy` deploys the AWS backend,
and `MiniProgram: Cloud Outputs` prints the backend API URL or a Flutter
`--dart-define` snippet.

Local backend commands are also available for development: initialize the backend
workspace, start/stop the local backend, and inspect backend status without
leaving VS Code.

## Partner handoff workflow

Mini-program publishers can create protected or public host handoff files from
VS Code:

1. Run `MiniProgram: Create Access Key` and copy the generated key.
2. Run `MiniProgram: Create Partner Package`.
3. Choose protected delivery with an access key, or public/static delivery with
   no access key.
4. Enter the appId, title, and either a configured env or direct API base URL.
5. Send the generated `.partner.json` file to the host app developer.

The host developer then runs `MiniProgram: Import Host Endpoint` and selects the
partner package. Protected partner packages contain an access key, so treat them
as secret files and do not commit them. Public partner packages have
`accessMode: "public"` and do not contain an access key.

`MiniProgram: Add Host Endpoint` also supports both modes. Use protected mode
for AWS/GCP/backend delivery that requires a MiniProgram access key. Use
public/static mode for GitHub Pages, CDN, S3 public hosting, Cloudflare Pages,
Netlify, Vercel static hosting, or other public content. Public mode has no
delivery access control.

Host diagnostics check public endpoints by loading:

- `manifests/<appId>/latest.json`
- `screens/<appId>/<version>/<entry>.json`

They also verify public endpoint metadata does not require a MiniProgram access
key. These checks run only when you manually run diagnostics.

## Host registry and demo buttons

Host apps with many mini-programs can generate
`lib/mini_program/mini_program_registry.dart` from the endpoint map:

- `MiniProgram: Generate Host Registry` creates or refreshes registry entries
  for configured endpoint appIds.
- `MiniProgram: Add MiniProgram to Registry` adds one typed entry with appId and
  title kept together.
- `MiniProgram: Copy Demo Host Button` copies a button snippet that calls
  `openAppMiniProgram(...)` and includes the imports to add.

The registry keeps button code, menus, analytics, and tests from repeating raw
strings:

```dart
openAppMiniProgram(
  context,
  appId: MiniPrograms.profile.appId,
  title: MiniPrograms.profile.title,
);
```

Diagnostics also warn when `mini_program_endpoints.dart` contains an endpoint
but no likely host UI launcher opens that appId.
The extension does not edit `main.dart`; paste copied snippets into your
host-owned UI so Provider, Riverpod, GetX, GoRouter, and custom app structures
stay under your control.

Use `MiniProgram: Check Host Endpoint Remote` from a host app to pick one
configured endpoint appId and inspect cloud health, published app metadata, and
active access-key status. This is useful because normal host workspace status
does not assume which appId you want to inspect remotely.

## Diagnostics

Use `MiniProgram: Diagnose Workspace` for local checks that are safe to run often.
It combines workflow status, `miniprogram doctor --json`, and lightweight project
file checks. Use the focused commands when debugging a specific area:

- `MiniProgram: Diagnose MiniProgram`
- `MiniProgram: Diagnose Host App`
- `MiniProgram: Diagnose Cloud Delivery`

Cloud delivery diagnostics are manual and may call remote AWS/backend status.
Diagnostic output includes fix suggestions and redacts MiniProgram access keys.

## Guided workflows

Guided workflows run the common commands in the right order and stop when a step
fails:

- `MiniProgram: Setup New MiniProgram`: create, build, and validate a new
  mini-program.
- `MiniProgram: Publish MiniProgram to AWS`: build, validate, publish, and run
  cloud diagnostics.
- `MiniProgram: Prepare Partner Handoff`: build, validate, publish, create an
  access key, create a `.partner.json`, and validate it.
- `MiniProgram: Setup Host App`: run embed init, optionally configure cloud, and
  diagnose the host.
- `MiniProgram: Add MiniProgram to Host`: import a partner package or add an
  endpoint manually, then diagnose the host.
- `MiniProgram: Run Host Smoke Test`: diagnose the host and start a host run
  terminal.

## Secret handling

The sidebar renders only the redacted workflow status fields. It does not show
raw MiniProgram access-key values from endpoint maps or partner packages.
Commands that accept secret command-line inputs redact those values in the
MiniProgram output channel. Create/rotate access-key commands still show the
newly generated key returned by the CLI so you can copy it into a partner
package or host endpoint.
Endpoint setup prompts stay open when you switch windows, so you can copy API
URLs or access keys and paste them without restarting the command.

MiniProgram access keys protect mini-program delivery access only. They are
revocable partner/app credentials, not user-auth tokens or server secrets. Use
JWT/OAuth/session tokens through host-owned `callSecureApi` logic for protected
user APIs.

## Troubleshooting notes

Flutter may print an advisory warning like
`Failed to decode advisories for shared_preferences_android` when using a pub
mirror. If the command also says `Got dependencies!`, dependency resolution
completed and the warning is mirror metadata noise.

On Windows, release APK builds can print Kotlin daemon cache warnings after a
successful `Built build\app\outputs\flutter-apk\app-release.apk` line. If the
APK exists, the build succeeded. If the warning keeps returning, run:

```powershell
flutter clean
flutter pub get
cd android
.\gradlew --stop
cd ..
flutter build apk --release
```
