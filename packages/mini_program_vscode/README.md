# MiniProgram Tools

Native VS Code sidebar for MiniProgram CLI workflows.

This extension is a thin UI over the installed `miniprogram` CLI. It does not
reimplement create, build, validate, publish, preview, AWS, access-key, partner
package, host endpoint, or backend logic.

## Marketplace install

Requires `mini_program_tooling` 0.3.49 or newer for endpoint/registry sync,
public demo generation, public/static endpoint support, publisher backend
endpoint metadata, backend query/state diagnostics, mock publisher backend
starter commands, AWS Lambda/DynamoDB publisher backend workflows, Firebase
Functions/Firestore publisher backend workflows, Firebase Firestore production
data management, Firebase write smoke, Firebase host integration, Firebase
host handoff packages, Firebase protected handoff access keys, Firebase Hosting
publish with browser CORS headers, Firebase auth readiness diagnostics, and
Firebase production starter UI generation with paged backend routes through
`miniprogram capabilities --json`.

Use `mini_program_tooling` 0.3.49 or newer when testing real Firebase auth and
protected handoff workflows so the extension can report backend auth readiness,
host SDK auth-controller readiness, Firebase publisher access-key status, and
generate protected host endpoints that forward access keys to publisher backend
routes. Tooling 0.3.47 also makes Firebase smoke tests more tolerant of
transient VPN/TLS connection drops and generates `mini_program_sdk: ^0.3.6` for
new host apps. Tooling 0.3.49 adds Firebase and AWS paged backend routes for
large coupon/data lists, with starter UI examples that use
`miniProgramPagedBackendBuilder` and `miniProgramLoadMore`.

Install or upgrade the CLI first:

```bash
dart pub global activate mini_program_tooling
```

Then install the extension from VS Code Marketplace:

- Marketplace: https://marketplace.visualstudio.com/items?itemName=MiniProgramTools.mini-program-tools

```bash
code --install-extension MiniProgramTools.mini-program-tools
```

You can also install it from the VS Code Extensions view by searching for
`MiniProgram Tools`.

For a complete first-time Firebase workflow with Firebase Console setup,
publisher steps, protected handoff, host import, and troubleshooting, see:

- [Firebase end-to-end guide](../../docs/firebase_end_to_end_guide.md)

## Local VSIX install

Use this only when testing an unreleased extension build locally.

```bash
cd packages/mini_program_vscode
npm install
npm run compile
npm run package:vsix
code --install-extension mini-program-tools-0.1.39.vsix
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
  - `MiniProgram: Publish MiniProgram to Firebase Hosting`
  - `MiniProgram: Embed Init`
  - `MiniProgram: Configure Host Cloud`
  - `MiniProgram: Import Host Endpoint`
  - `MiniProgram: Add Host Endpoint`
  - `MiniProgram: Run Host App`
  - `MiniProgram: Env Init`
  - `MiniProgram: Configure AWS Environment`
  - `MiniProgram: Configure Firebase Environment`
  - `MiniProgram: Use Environment`
  - `MiniProgram: Environment Status`
  - `MiniProgram: Cloud Deploy`
  - `MiniProgram: Cloud Status`
  - `MiniProgram: Cloud Outputs`
  - `MiniProgram: Backend Init`
  - `MiniProgram: Backend Start`
  - `MiniProgram: Backend Stop`
  - `MiniProgram: Backend Status`
  - `MiniProgram: Setup Publisher Backend`
  - `MiniProgram: Run Publisher Backend`
  - `MiniProgram: Stop Publisher Backend`
  - `MiniProgram: Publisher Backend Status`
  - `MiniProgram: Deploy Publisher Backend to AWS`
  - `MiniProgram: Publisher Backend AWS Status`
  - `MiniProgram: Publisher Backend AWS Outputs`
  - `MiniProgram: Smoke Test AWS Publisher Backend`
  - `MiniProgram: Smoke Test AWS Publisher Backend With Write`
  - `MiniProgram: Seed AWS Publisher DynamoDB`
  - `MiniProgram: AWS Publisher DynamoDB Data Status`
  - `MiniProgram: Export AWS Publisher DynamoDB Data`
  - `MiniProgram: Dry Run AWS Publisher DynamoDB Import`
  - `MiniProgram: List AWS Publisher DynamoDB Redemptions`
  - `MiniProgram: Publisher Backend AWS Logs`
  - `MiniProgram: Destroy AWS Publisher Backend Stack`
  - `MiniProgram: Copy AWS Backend Host Command`
  - `MiniProgram: Deploy Publisher Backend to Firebase`
  - `MiniProgram: Publisher Backend Firebase Status`
  - `MiniProgram: Publisher Backend Firebase Outputs`
  - `MiniProgram: Wire Firebase Publisher Backend Into Host App`
  - `MiniProgram: Create Firebase Host Handoff Package`
  - `MiniProgram: Add Firebase Starter UI`
  - `MiniProgram: Create Firebase Publisher Access Key`
  - `MiniProgram: List Firebase Publisher Access Keys`
  - `MiniProgram: Revoke Firebase Publisher Access Key`
  - `MiniProgram: Rotate Firebase Publisher Access Key`
  - `MiniProgram: Smoke Test Firebase Publisher Backend`
  - `MiniProgram: Smoke Test Firebase Publisher Backend With Write`
  - `MiniProgram: Seed Firebase Publisher Firestore`
  - `MiniProgram: Firebase Publisher Firestore Data Status`
  - `MiniProgram: Export Firebase Publisher Firestore Data`
  - `MiniProgram: Dry Run Firebase Publisher Firestore Import`
  - `MiniProgram: List Firebase Publisher Firestore Redemptions`
  - `MiniProgram: Destroy Firebase Publisher Backend Function`
  - `MiniProgram: Copy Publisher Backend URLs`
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

`MiniProgram: Publish MiniProgram to Firebase Hosting` wraps
`miniprogram publish --target firebase-hosting` from tooling 0.3.42. It asks for
the Firebase env, Hosting public folder, optional site ID, cleanup preference,
and deploy/dry-run mode. After publish it shows the Hosting delivery URL and can
start `MiniProgram: Create Firebase Host Handoff Package` with that URL. The
0.3.42 tooling requirement matters because generated Firebase Hosting configs
include CORS headers required by browser-based host apps.

For protected Firebase publisher backends, use
`MiniProgram: Create Firebase Host Handoff Package` and choose **Protected
endpoint**. The extension can create a new Firebase publisher access key through
tooling 0.3.45, copy the one-time key to the clipboard, embed it into the
`.partner.json` handoff package, and show active/revoked key counts in the
sidebar. Host developers still import only the provider-neutral handoff package;
they do not need Firebase login or project access.

## Firebase full system walkthrough

Use this flow when the mini-program publisher and Flutter host developer are
different teams.

This section is the short VS Code checklist. For the full new-developer guide,
including Firebase Console setup and common failures, see
[Firebase end-to-end guide](../../docs/firebase_end_to_end_guide.md).

Publisher workspace:

1. Open or create the mini-program folder with `MiniProgram: Create
   MiniProgram`. Choose **Normal mini-program**.
2. Run `MiniProgram: Setup Publisher Backend` and choose **Firebase Functions +
   Firestore**. When prompted, choose **Add Firebase starter UI** to generate
   the matching frontend auth/data/image starter, paged coupon list, and
   backend seed JSON.
3. Run `MiniProgram: Configure Firebase Environment`. Enter the Firebase
   project id, region, function name, and Firebase Web API key when
   email/password auth should be enabled.
4. Edit UI in `stac/screens/<appId>_home.dart`. For an existing Firebase
   scaffold that does not have the generated UI, run
   `MiniProgram: Add Firebase Starter UI`; choose **Add safely** to skip
   existing screen/seed files or **Replace starter files** to pass `--force`.
   Edit Firestore seed data in
   `backend/firebase_functions/functions/data/home_bootstrap.json`,
   `coupons_list.json`, and `session.json`.
5. Run `MiniProgram: Deploy Publisher Backend to Firebase`.
6. Run `MiniProgram: Seed Firebase Publisher Firestore`.
7. Run `MiniProgram: Smoke Test Firebase Publisher Backend`. Before creating
   access keys, choose **Run without access key**. After protected keys exist,
   choose **Enter Firebase access key**.
8. Run `MiniProgram: Firebase Publisher Auth Status` to confirm the auth key,
   generated routes, CORS, Firebase Admin dependency, and host auth readiness.
9. Run `MiniProgram: Publish MiniProgram to Firebase Hosting`. Use
   `backend/firebase_hosting/public` as the output folder and choose deploy.
10. Run `MiniProgram: Create Firebase Host Handoff Package`. For a real host
    partner choose protected mode and **Create new Firebase access key**. Use a
    key id like `company-a`; the default package filename becomes
    `<app>-<env>-company-a.partner.json`.

Send the generated `.partner.json` file to the host developer. It is the
contract between teams. It includes the delivery URL, publisher backend URL,
access mode, and MiniProgram access key, but it does not include Firebase
credentials, Firebase Web API keys, service accounts, or publisher secrets.

Host workspace:

1. Create/open a Flutter app.
2. Run `MiniProgram: Embed Init` and choose **Clean adapter only** for a real
   handoff.
3. Run `MiniProgram: Import Host Endpoint` and select the `.partner.json` file
   from the publisher.
4. Wrap the host app with:

   ```dart
   MiniProgramScope(
     config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),
     child: const MyApp(),
   )
   ```

5. Open the mini-program by app id:

   ```dart
   openAppMiniProgram(
     context,
     appId: 'firebase_full_demo',
     title: 'Firebase Full Demo',
   );
   ```

6. Run `MiniProgram: Diagnose Host App`, then `MiniProgram: Run Host App`.

The host developer does not need Firebase CLI login, Firebase console access,
Firebase SDK configuration, or publisher backend secrets.

`MiniProgram: Embed Init` can also generate a public first-run demo endpoint.
Choose **Add public demo endpoint** when prompted to create:

- `lib/mini_program/mini_program_endpoints.dart`
- `lib/mini_program/mini_program_registry.dart`
- README snippets using `MiniPrograms.publicDemo`

The demo uses this public jsDelivr endpoint:

```text
https://cdn.jsdelivr.net/gh/mehedi8603651/miniprogram-public@main/
```

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

## Publisher backend starter

The publisher backend starter is separate from the delivery backend. It can
create a local mock business API for development or an AWS Lambda + API Gateway
starter for production-style publisher APIs.

From VS Code:

1. Run `MiniProgram: Setup New MiniProgram`.
2. Choose **Mini-program with mock backend**.
3. Open the created mini-program folder.
4. Run `MiniProgram: Run Publisher Backend`.
5. Run `MiniProgram: Copy Publisher Backend URLs`.

For an existing mini-program, run `MiniProgram: Setup Publisher Backend` and
choose **Mock local**, **AWS Lambda bundled JSON**, **AWS Lambda + DynamoDB**,
or **Firebase Functions + Firestore**.

The generated mock server is local-only and lives under:

```text
backend/mock/
```

It serves:

- `GET /health`
- `GET /home/bootstrap`
- `GET /coupons/list`
- `GET /auth/session`
- `POST /coupon/redeem`

Use `MiniProgram: Add Host Endpoint` and choose **Local mock backend**. It
writes `--backend-local-mock`, which stores `http://127.0.0.1:9090/` in host
config. With `mini_program_sdk` 0.3.5 or newer, the SDK falls back between
`127.0.0.1` / `localhost` and Android emulator `10.0.2.2`, so the same host
config works for Chrome, desktop, and Android emulator. Real devices may need
a LAN IP URL or `adb reverse`.

`MiniProgram: Copy Mock Backend Host Command` copies the equivalent CLI command
for developers who want to paste it into a terminal.

The mock backend is for local development only. Firebase, AWS, GCP, or custom
server SDKs belong on publisher backend servers, not in the Flutter host app or
`mini_program_sdk`.

### AWS Lambda publisher backend

Choose **AWS Lambda bundled JSON** in `MiniProgram: Setup Publisher Backend` to
scaffold `backend/aws_lambda/` with sample JSON files. Choose
**AWS Lambda + DynamoDB** when you want persistent publisher backend storage.
Both use the same route shape as the mock backend:

- `GET /health`
- `GET /home/bootstrap`
- `GET /coupons/list`
- `GET /auth/session`
- `POST /coupon/redeem`

Deploy with `MiniProgram: Deploy Publisher Backend to AWS`, then inspect it with
`MiniProgram: Publisher Backend AWS Status`,
`MiniProgram: Publisher Backend AWS Outputs`, or
`MiniProgram: Publisher Backend AWS Logs`.

For DynamoDB scaffolds, use:

- `MiniProgram: Seed AWS Publisher DynamoDB` to upsert starter records.
- `MiniProgram: AWS Publisher DynamoDB Data Status` to inspect table status,
  app records, and redemption count.
- `MiniProgram: Export AWS Publisher DynamoDB Data` before production changes
  or stack cleanup. It can export app records only or include redemptions.
- `MiniProgram: Dry Run AWS Publisher DynamoDB Import` to validate an export
  without writing data. Redemptions are skipped unless explicitly included.
- `MiniProgram: List AWS Publisher DynamoDB Redemptions` to inspect recent
  redemption records with optional coupon/user filters.
- `MiniProgram: Smoke Test AWS Publisher Backend` for a read-only route check.
- `MiniProgram: Smoke Test AWS Publisher Backend With Write` only when you want
  to verify `POST /coupon/redeem`; this may create or reuse a redemption record.
- `MiniProgram: Destroy AWS Publisher Backend Stack` for guarded stack cleanup.
  The guarded mode relies on the CLI data-loss check and blocks when DynamoDB
  records exist. The explicit data-loss mode requires typing `delete data`.

If the configured CLI is older than `mini_program_tooling` 0.3.45, the extension
warns before running newer publisher backend actions or when quiet capability
detection is unavailable. Version 0.1.35 calls `miniprogram capabilities --json`
once per workspace and only falls back to older AWS `--help` probes for older
CLI installs. Upgrade with:

```bash
dart pub global activate mini_program_tooling 0.3.45
```

`MiniProgram: Copy AWS Backend Host Command` reads the deployed
`PublisherBackendBaseUrl` and copies a host endpoint command that uses
`--backend-base-url`. The host app does not need AWS credentials or AWS SDKs.
AWS/Firebase/database secrets stay in Lambda/server configuration, never in
mini-program JSON, host source, APK, IPA, or web JavaScript.

### Firebase Functions publisher backend

Choose **Firebase Functions + Firestore** in `MiniProgram: Setup Publisher
Backend` to scaffold `backend/firebase_functions/`. The generated Cloud
Functions v2 backend uses Firestore on the publisher side and keeps Firebase
SDKs out of the Flutter host app, MiniProgram SDK, mini-program JSON, APK, IPA,
and web JavaScript.

Configure the project with `MiniProgram: Configure Firebase Environment`, then
deploy with `MiniProgram: Deploy Publisher Backend to Firebase`. The extension
prompts for the Firebase project ID, region, function name, and optional
function URL override.

After deploy, use:

- `MiniProgram: Publisher Backend Firebase Outputs` to print the backend and
  health URLs.
- `MiniProgram: Publisher Backend Firebase Status` to inspect deployment
  metadata.
- `MiniProgram: Seed Firebase Publisher Firestore` to upsert starter home,
  session, and coupon documents.
- `MiniProgram: Firebase Publisher Firestore Data Status` to count Firestore
  app records and redemptions.
- `MiniProgram: Export Firebase Publisher Firestore Data` to write a
  provider-neutral JSON export, with optional redemptions.
- `MiniProgram: Dry Run Firebase Publisher Firestore Import` to validate an
  export before any write.
- `MiniProgram: List Firebase Publisher Firestore Redemptions` to inspect
  redemption history with optional coupon/user filters.
- `MiniProgram: Destroy Firebase Publisher Backend Function` for guarded
  function cleanup. The CLI blocks when Firestore records exist unless the
  explicit data-loss guard override is confirmed; Firestore data is not deleted.
- `MiniProgram: Wire Firebase Publisher Backend Into Host App` to choose a host
  app, delivery URL, public/protected mode, preview the generated endpoint
  command, optionally run it, and show `hostEndpointReady` diagnostics.
- `MiniProgram: Create Firebase Host Handoff Package` to create a
  provider-neutral `.partner.json` package from the Firebase environment and a
  delivery URL. The host developer imports that package and does not need
  Firebase login or project access.
- `MiniProgram: Create/List/Revoke/Rotate Firebase Publisher Access Key` to
  manage protected Firebase handoff keys in Firestore. Raw keys are shown only
  after create/rotate and copied to the clipboard; list/sidebar views show only
  counts and key IDs.
- `MiniProgram: Firebase Publisher Auth Status` to check publisher-owned email
  auth readiness. It reports whether the Firebase auth Web API key, generated
  auth routes, CORS `Authorization` header, Functions `.env`, Firebase Admin
  dependency, and optional host SDK auth controller are ready.
- `MiniProgram: Smoke Test Firebase Publisher Backend` for the read-only route
  check.
- `MiniProgram: Smoke Test Firebase Publisher Backend With Write` only when you
  want to verify `POST /coupon/redeem`; it asks for a coupon/user ID and may
  create a Firestore redemption document.

Firebase deploy/status/smoke actions require `mini_program_tooling` 0.3.32 or
newer. Firebase Firestore export/import/redemptions and guarded destroy require
0.3.34 or newer. Firebase write smoke requires 0.3.35 or newer. Firebase host
integration requires 0.3.38 or newer. Firebase handoff packages require 0.3.39
or newer. Firebase Hosting publish requires 0.3.42 or newer for browser CORS
headers. Firebase auth status diagnostics require 0.3.44 or newer. Firebase
protected handoff access-key management requires 0.3.45 or newer. The extension uses
`miniprogram capabilities --json` once per workspace to detect support and warns
with an upgrade command if the configured CLI is too old.

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

For Firebase publisher backends, run
`MiniProgram: Create Firebase Host Handoff Package` instead of manually entering
the backend URL. It reads the Firebase Functions output from the selected env,
adds the publisher backend URL to the package, and keeps Firebase credentials
with the publisher. In protected mode, choose **Create new Firebase access key**
to create a one-time key and embed it in the handoff package, or choose
**Paste existing Firebase access key** when rotating or reusing a partner key.

`MiniProgram: Add Host Endpoint` also supports both modes. Use protected mode
for AWS/GCP/backend delivery that requires a MiniProgram access key. Use
public/static mode for GitHub Pages, CDN, S3 public hosting, Cloudflare Pages,
Netlify, Vercel static hosting, or other public content. Public mode has no
delivery access control. Manual endpoint add asks for a display title and the
CLI writes both `mini_program_endpoints.dart` and
`mini_program_registry.dart`, so host UI code can use
`MiniPrograms.<name>.appId` and `MiniPrograms.<name>.title`.

Endpoint add and partner package creation can also include an optional
publisher-owned backend base URL. That backend is for business API calls from
`miniProgramBackend`, `miniProgramBackendQuery`, and
`miniProgramBackendBuilder` usage, not for manifest/screen delivery. Backend
secrets must stay on the publisher server; the host app stores only the public
base URL and optional delivery access key. Diagnostics show whether a publisher
backend is configured and never print access-key values.

Backend query/state helpers support simple bindings such as:

```text
{{backend.home.data.title}}
{{backend.home.message}}
{{item.title}}
```

If diagnostics detects backend query or builder usage in a mini-program, it
prints a fix reminding you to include `--backend-base-url` when creating the
partner package or adding the endpoint to a host app.

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
but no likely host UI launcher opens that appId, or when endpoint appIds and
registry appIds no longer match.
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
