# mini_program_tooling

Developer tooling for the portable Flutter mini-program platform.

This package exposes the global `miniprogram` CLI used to create mini-programs,
build and validate authored flows, preview with watch/rebuild/refresh, publish
to local, public static, Firebase Hosting, or AWS cloud delivery, deploy managed AWS and Firebase
publisher backends, initialize embedding adapters for existing Flutter apps,
bind host apps to cloud environments, manage MiniProgram access keys, generate
host endpoint maps, exchange partner handoff packages between publishers and
host app teams, and manage the local backend lifecycle.

## Install

Released package:

```bash
dart pub global activate mini_program_tooling
```

Repo-local contributor install:

```bash
dart pub global activate --source path <repo-root>/packages/mini_program_tooling
```

## VS Code extension

If you prefer buttons, status panels, diagnostics, and guided workflows instead
of typing every command, install **MiniProgram Tools** from the VS Code
Marketplace:

- Marketplace: https://marketplace.visualstudio.com/items?itemName=MiniProgramTools.mini-program-tools
- Install command:

```bash
code --install-extension MiniProgramTools.mini-program-tools
```

The extension is a thin UI over this same `miniprogram` CLI. Keep
`mini_program_tooling` installed globally because the extension calls the CLI as
the source of truth.

## CLI surface

```text
miniprogram create <mini-program-id> [--with-backend mock]
miniprogram capabilities [--json]
miniprogram doctor [--json]
miniprogram backend init
miniprogram env init
miniprogram env configure <env-name> --provider aws --bucket <unique-bucket-name> --region <aws-region> [--aws-profile <aws-profile>] [--require-access-keys]
miniprogram env configure <env-name> --provider firebase --project-id <firebase-project-id> [--region us-central1] [--function-name publisherBackend] [--function-url <url>]
miniprogram env list
miniprogram env use <local|env-name>
miniprogram env status [--json]
miniprogram build [mini-program-id]
miniprogram preview -d <chrome|edge|ios|linux|macos|windows|emulator-5554|android-device-id|android-wifi-device-id> [mini-program-id]
miniprogram validate [mini-program-id]
miniprogram publish [mini-program-id] [--target local|cloud|static|firebase-hosting] [--env <env-name>] [--output <folder>] [--clean] [--site <firebase-hosting-site>] [--dry-run] [--json]
miniprogram access-key create <mini-program-id> --key-id <id> [--env <env-name>]
miniprogram access-key list <mini-program-id> [--env <env-name>] [--json]
miniprogram access-key revoke <mini-program-id> --key-id <id> [--env <env-name>]
miniprogram access-key rotate <mini-program-id> --key-id <id> [--new-key-id <id>] [--env <env-name>]
miniprogram cloud deploy [--env <env-name>]
miniprogram cloud status [--env <env-name>] [--json]
miniprogram cloud outputs [--env <env-name>] [--format text|dart-define]
miniprogram cloud logs [--env <env-name>]
miniprogram cloud destroy [--env <env-name>]
miniprogram cloud doctor [--env <env-name>]
miniprogram cloud rollback <version> [mini-program-id] [--env <env-name>]
miniprogram cloud app list [--env <env-name>]
miniprogram cloud app info <mini-program-id> [--env <env-name>]
miniprogram cloud app disable <mini-program-id> [--yes] [--env <env-name>]
miniprogram cloud app delete <mini-program-id> [--yes] [--env <env-name>]
miniprogram workflow status [--workspace <path>] [--env <env-name>] [--remote] [--json]
miniprogram publisher-backend scaffold --template mock|aws-lambda|firebase-functions [--storage bundled|dynamodb|firestore] [--mini-program-root <path>] [--force]
miniprogram publisher-backend run [--mini-program-root <path>] [--port 9090]
miniprogram publisher-backend status [--mini-program-root <path>] [--json]
miniprogram publisher-backend stop [--mini-program-root <path>]
miniprogram publisher-backend urls [--port 9090]
miniprogram publisher-backend aws deploy --env <env-name> [--mini-program-root <path>]
miniprogram publisher-backend aws status --env <env-name> [--mini-program-root <path>] [--json]
miniprogram publisher-backend aws outputs --env <env-name> [--mini-program-root <path>] [--json]
miniprogram publisher-backend aws smoke --env <env-name> [--mini-program-root <path>] [--json] [--include-write]
miniprogram publisher-backend aws seed --env <env-name> [--mini-program-root <path>] [--json]
miniprogram publisher-backend aws data status --env <env-name> [--mini-program-root <path>] [--json]
miniprogram publisher-backend aws data export --env <env-name> [--mini-program-root <path>] [--output <file>] [--include-redemptions] [--json]
miniprogram publisher-backend aws data import --env <env-name> [--mini-program-root <path>] --input <file> [--include-redemptions] [--dry-run] [--json]
miniprogram publisher-backend aws data redemptions --env <env-name> [--mini-program-root <path>] [--coupon-id <id>] [--user-id <id>] [--limit 50] [--json]
miniprogram publisher-backend aws logs --env <env-name> [--mini-program-root <path>] [--since 1h]
miniprogram publisher-backend aws destroy --env <env-name> [--mini-program-root <path>] --yes [--confirm-data-loss]
miniprogram publisher-backend firebase deploy --env <env-name> [--mini-program-root <path>] [--json]
miniprogram publisher-backend firebase status --env <env-name> [--mini-program-root <path>] [--json]
miniprogram publisher-backend firebase outputs --env <env-name> [--mini-program-root <path>] [--json]
miniprogram publisher-backend firebase host-command --env <env-name> --api-base-url <delivery-url> (--access-key <key>|--public) [--mini-program-root <path>] [--host-project-root <path>] [--json]
miniprogram publisher-backend firebase handoff --env <env-name> --delivery-url <delivery-url> (--access-key <key>|--public) [--mini-program-root <path>] [--output <file>] [--json]
miniprogram publisher-backend firebase smoke --env <env-name> [--mini-program-root <path>] [--json] [--include-write] [--write-coupon-id <id>] [--write-user-id <id>]
miniprogram publisher-backend firebase seed --env <env-name> [--mini-program-root <path>] [--json]
miniprogram publisher-backend firebase data status --env <env-name> [--mini-program-root <path>] [--json]
miniprogram publisher-backend firebase data export --env <env-name> [--mini-program-root <path>] [--output <file>] [--include-redemptions] [--json]
miniprogram publisher-backend firebase data import --env <env-name> [--mini-program-root <path>] --input <file> [--include-redemptions] [--dry-run] [--json]
miniprogram publisher-backend firebase data redemptions --env <env-name> [--mini-program-root <path>] [--coupon-id <id>] [--user-id <id>] [--limit 50] [--json]
miniprogram publisher-backend firebase destroy --env <env-name> [--mini-program-root <path>] --yes [--confirm-data-loss] [--json]
miniprogram partner package <mini-program-id> (--access-key <key>|--public) [--api-base-url <url>|--env <env-name>] [--backend-base-url <url>] [--output <file>]
miniprogram host run -d <device> [--env <env-name>]
miniprogram host endpoint add <mini-program-id> --title <title> --api-base-url <url> (--access-key <key>|--public) [--backend-base-url <url>|--backend-local-mock]
miniprogram host endpoint import <partner-package.json>
miniprogram embed init [--project-root <path>] [--force] [--with-demo]
miniprogram embed cloud configure [--env <env-name>]
miniprogram backend start --port 8080
miniprogram backend stop
miniprogram backend status [--json]
miniprogram backend reset-local --yes
```

Use `miniprogram <command> --help`, `miniprogram <group> --help`, or
`miniprogram <group> <command> --help` for command-specific options.

Use `miniprogram capabilities --json` when an editor extension, script, or CI
job needs to detect supported CLI features without parsing multiple help
screens.

## Workflow status

Use workflow status when you want the CLI to tell you what is ready, what is
missing, and what command to run next:

```bash
miniprogram workflow status
miniprogram workflow status --json
```

By default the command is local-first, so it is safe for frequent IDE refresh.
It detects whether the current folder is a mini-program, a generated Flutter
host app, or an unknown folder. It checks local build output, generated host
endpoint maps, local env configuration, backend workspace state, and nearby
partner packages.

Use `--remote` only when you want AWS/Firebase/backend checks:

```bash
miniprogram workflow status --remote --json
```

JSON output is intended for a future VS Code Activity Bar/sidebar extension.
It is redacted: endpoint and partner package access-key values are never
printed, only key IDs, counts, app IDs, URLs, and `hasAccessKey` flags.

## Examples

Check your machine and saved CLI state first:

```bash
miniprogram doctor
```

Create a standalone mini-program in the current directory:

```bash
miniprogram create coupon_center
```

Create a mini-program with a local mock publisher backend and backend-driven
starter UI:

```bash
miniprogram create coupon_center --title "Coupon Center" --with-backend mock
cd coupon_center
miniprogram publisher-backend run --port 9090
miniprogram publisher-backend urls --port 9090
```

The default scaffold uses only `analytics`, so it opens in a minimal generated
host app without native-route wiring. Add `native_navigation` only when your
host app has a real native route callback.

Use managed preview for the fastest authoring loop:

```bash
cd coupon_center
miniprogram preview -d chrome
```

Preview v1 currently supports:

- `chrome`
- `edge`
- `ios` on macOS with Xcode
- `linux`
- `macos`
- `windows`
- Android emulator ids such as `emulator-5554`
- Android USB device ids such as `R58M123ABC`
- Android Wi-Fi device ids such as `192.168.1.25:5555`

`preview` is a developer-only loop. It does not require `backend init` or
`backend start`, does not publish into `backend/api/`, and keeps a managed
hidden host app under `.mini_program/preview_host`.

During preview, the CLI:

- builds the mini-program before launch
- starts a tiny session-scoped localhost preview server when needed
- watches `manifest.json`, `stac/**`, `assets/**`, and
  `lib/default_stac_options.dart`
- rebuilds on save and triggers a full preview refresh
- prefers `adb reverse tcp:<port> tcp:<port>` for Android emulator preview and
  uses `http://127.0.0.1:<port>/preview/` when reverse is available
- falls back to `http://10.0.2.2:<port>/preview/` for emulator sessions when
  reverse is unavailable
- auto-applies `adb reverse tcp:<port> tcp:<port>` for Android USB preview and
  uses `http://127.0.0.1:<port>/preview/` inside the device session
- uses a resolved LAN host such as `http://192.168.1.10:<port>/preview/` for
  Android Wi-Fi preview sessions

For Android Wi-Fi preview, the device must be able to reach your dev machine on
the same LAN. If auto-detection picks the wrong host IP, set
`MINI_PROGRAM_PREVIEW_LAN_HOST=<your-lan-ip>` before running preview.

Preview capability behavior in v1:

- `analytics` logs through the preview host and returns success
- `native_navigation` opens a preview-native placeholder page
- `secure_api` returns an explicit preview-only failure

Initialize a standalone backend workspace once:

```bash
miniprogram backend init
```

On Windows, this defaults to `%LOCALAPPDATA%\mini_program\backend\`. Use
`miniprogram backend init --root <custom-path>` only when you intentionally
want a different workspace location.

Initialize local CLI env once from a standalone mini-program workspace:

```bash
cd <workspace>/coupon_center
miniprogram env init
```

That writes both a workspace-local `.mini_program/env.json` and a user-level
fallback env file, so later commands can run from this workspace or from
unrelated directories without repeating setup.

Then build, validate, and publish without any platform repo path:

```bash
cd coupon_center
miniprogram build
miniprogram validate
miniprogram publish
```

If a standalone backend workspace was initialized earlier with
`miniprogram backend init`, `publish` writes manifests and screens into that
workspace instead of the platform repo backend.

From outside the mini-program folder, the explicit form still works:

```bash
miniprogram build coupon_center
miniprogram validate coupon_center
miniprogram publish coupon_center
```

Configure a named AWS cloud environment:

```bash
miniprogram env init
miniprogram env configure <env-name> --provider aws --bucket <unique-bucket-name> --region <aws-region> [--aws-profile <aws-profile>] [--cloudfront-base-url https://<cloudfront-domain>] [--api-base-url https://<api-domain>] [--require-access-keys]
miniprogram env use <env-name>
miniprogram env list
miniprogram env status
```

Replace the placeholder values before running that command. In particular:

- `<env-name>` should be something like `my-aws-prod`
- `<unique-bucket-name>` must be globally unique in S3
- `<aws-region>` should be a real AWS region such as `ap-south-1`
- `--cloudfront-base-url` and `--api-base-url` are optional and should only be
  supplied when you already have those URLs
- `--require-access-keys` makes the AWS delivery backend reject manifest and
  screen requests unless the mini-program has valid access-key metadata

Where those optional URLs come from:

- `--api-base-url` is usually the `BackendApiBaseUrl` printed by
  `miniprogram cloud deploy` or `miniprogram cloud outputs`, for example
  `https://<api-id>.execute-api.<aws-region>.amazonaws.com/prod/api/`
- if you use `miniprogram cloud deploy`, you normally do not need to pass
  `--api-base-url` during `env configure`; the CLI can read the deployed stack
  output later
- `--cloudfront-base-url` is the CloudFront distribution domain name, visible
  in the AWS CloudFront console as the distribution domain, for example
  `https://<distribution-id>.cloudfront.net`
- CloudFront is optional in the current AWS CLI flow; API Gateway + Lambda is
  enough for host-app testing

Configure a named Firebase environment when you use the Firebase Functions
publisher backend:

```bash
miniprogram env configure <env-name> --provider firebase --project-id <firebase-project-id> [--region us-central1] [--function-name publisherBackend] [--function-url https://<function-url>]
```

Use `--function-url` only when the derived Cloud Functions v2 HTTPS URL does
not match your deployed function URL.

Cloud publish then uses the active named cloud environment by default:

```bash
cd coupon_center
miniprogram publish --target cloud
```

Or use an explicit env override:

```bash
miniprogram publish --target cloud --env my-aws-prod
```

One bucket can store many mini-programs for the same environment. Artifacts are
keyed by mini-program ID and version:

```text
artifacts/<mini-program-id>/<version>/manifest.json
artifacts/<mini-program-id>/<version>/screens/<screen-id>.json
metadata/catalog/<mini-program-id>.json
metadata/releases/<mini-program-id>/<version>.json
```

Host apps should use the API Gateway base URL printed by
`miniprogram cloud outputs`, not the S3 bucket URL.

### Public static publish

For demos, open-source samples, testing, fun apps, or other content that can be
fully public, export a static delivery folder:

```bash
cd coupon_center
miniprogram publish --target static --output public_mini_program
```

Use `--clean` when you want the CLI to remove older generated static output
before writing the new version. The cleanup is conservative: it removes only
generated static delivery folders/files, not your README or unrelated files.

```bash
miniprogram publish --target static --output public_mini_program --clean
```

The output folder is ready for GitHub Pages, CDN, S3 public hosting,
Cloudflare Pages, Netlify, Vercel static hosting, or similar:

```text
public_mini_program/
  manifests/<mini-program-id>/latest.json
  manifests/<mini-program-id>/versions/<version>.json
  screens/<mini-program-id>/<version>/<screen-id>.json
  assets/<mini-program-id>/<version>/
  metadata/catalog/<mini-program-id>.json
  metadata/releases/<mini-program-id>/<version>.json
  PUBLISH_INSTRUCTIONS.md
  .nojekyll
```

Public static delivery is unauthenticated. Do not publish private data or
business-only mini-programs this way. Prefer GitHub Pages or a CDN over
`raw.githubusercontent.com` for real usage.

### Firebase Hosting static delivery

Firebase publishers can host the same public static delivery layout on Firebase
Hosting while keeping Firebase Functions and Firestore as the publisher-owned
business backend.

Configure Firebase once:

```bash
miniprogram env configure my-firebase-prod --provider firebase --project-id <firebase-project-id> --region us-central1 --function-name publisherBackend
```

Then publish static delivery to Firebase Hosting:

```bash
miniprogram publish --target firebase-hosting \
  --env my-firebase-prod \
  --clean
```

The default public folder is:

```text
backend/firebase_hosting/public
```

The command builds static artifacts, writes `backend/firebase_hosting/firebase.json`,
runs `firebase deploy --only hosting`, and prints the delivery API base URL,
usually:

```text
https://<firebase-project-id>.web.app/
```

Use `--dry-run` to generate the files without deploying, and `--site <site-id>`
when the Firebase project uses a non-default Hosting site.

After publish, create the provider-neutral package for the host developer:

```bash
miniprogram publisher-backend firebase handoff \
  --env my-firebase-prod \
  --delivery-url https://<firebase-project-id>.web.app/ \
  --public \
  --output <app>-my-firebase-prod.partner.json
```

The host imports the `.partner.json` package with `miniprogram host endpoint
import`; the host does not need Firebase CLI login, Firebase project access, or
Firebase SDKs for this delivery path.

### Public GitHub Pages delivery

For a clean public GitHub Pages repo, commit only the generated delivery folder
and simple repo metadata:

```text
.gitignore
.nojekyll
README.md
public_mini_program/
```

The generated `.nojekyll` file should be kept so GitHub Pages serves generated
paths normally. If you commit `public_mini_program/` inside a larger GitHub
Pages repo, also keep a `.nojekyll` file at the repo root. A public delivery
repo should not contain development folders like `.dart_tool/`, `stac/.build/`,
or local build output.

Recommended flow:

```bash
miniprogram publish --target static --output public_mini_program --clean
git add public_mini_program .nojekyll README.md
git commit -m "Publish public mini-program"
git push
```

After GitHub Pages is enabled, verify these URLs in a browser:

```text
https://<user>.github.io/<repo>/public_mini_program/manifests/<appId>/latest.json
https://<user>.github.io/<repo>/public_mini_program/screens/<appId>/<version>/<entry>.json
```

Host apps add public static endpoints without access keys:

```bash
miniprogram host endpoint add public_coupon_demo --title "Public Coupon Demo" --api-base-url https://user.github.io/repo/public_mini_program/ --public
```

Generated Dart uses:

```dart
MiniProgramEndpoint.public(
  apiBaseUri: Uri.parse('https://user.github.io/repo/public_mini_program/'),
)
```

### MiniProgram access keys

When an environment was configured with `--require-access-keys`, create one
MiniProgram access key per host company, partner, or integration:

```bash
miniprogram access-key create aws_coupon_demo --key-id company-a --env my-aws-prod
miniprogram access-key create aws_coupon_demo --key-id company-b --env my-aws-prod
miniprogram access-key list aws_coupon_demo --env my-aws-prod
```

The CLI prints the access key once. Give that key only to the host app team
that should use it. The backend stores only a SHA-256 hash in:

```text
metadata/access_keys/<mini-program-id>.json
```

If one company should lose access, revoke only that company's key:

```bash
miniprogram access-key revoke aws_coupon_demo --key-id company-b --env my-aws-prod
```

To replace a leaked or old key:

```bash
miniprogram access-key rotate aws_coupon_demo --key-id company-a --new-key-id company-a-2026-05 --env my-aws-prod
```

### Manage published cloud apps

Use `cloud app` commands to inspect or clean old mini-program API metadata:

```bash
miniprogram cloud app list --env my-aws-prod
miniprogram cloud app info aws_coupon_demo --env my-aws-prod
```

Disable removes the active catalog pointer, so normal latest-version opens stop
working, but immutable release artifacts remain available for inspection:

```bash
miniprogram cloud app disable aws_coupon_demo --env my-aws-prod
miniprogram cloud app disable aws_coupon_demo --env my-aws-prod --yes
```

Delete is destructive and dry-runs unless you pass `--yes`:

```bash
miniprogram cloud app delete old_coupon_demo --env my-aws-prod
miniprogram cloud app delete old_coupon_demo --env my-aws-prod --yes
```

### Host endpoint map

One host app can include many mini-programs from many publishers and cloud
providers. Keep button code appId-only, and keep API base URLs plus public or
protected delivery mode in host runtime config.

The publisher and host app developer can be different teams:

- the mini-program publisher owns AWS/Firebase/custom backend deployment,
  storage, data, logs, and secrets
- the host app developer owns Flutter host code and endpoint registration
- the host app should receive only delivery metadata, an optional MiniProgram
  access key, and an optional publisher backend URL
- the host app should not need Firebase CLI login, Firebase project access,
  AWS credentials, Firebase Admin SDKs, or publisher backend secrets

For partner handoff, the publisher can package the appId, title, API base URL,
and one MiniProgram access key into a JSON file for protected delivery:

```bash
miniprogram partner package aws_coupon_demo --title "AWS Coupon Demo" --access-key mpk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx --env my-aws-prod --output aws_coupon_demo.partner.json
```

For public/static delivery, create a public handoff package without a key:

```bash
miniprogram partner package public_coupon_demo --title "Public Coupon Demo" --public --api-base-url https://user.github.io/repo/public_mini_program/ --output public_coupon_demo.partner.json
```

If the mini-program also calls its publisher-owned business backend, include a
separate backend base URL. This is not the delivery API URL and it should not
contain backend secrets:

```bash
miniprogram partner package aws_coupon_demo --title "AWS Coupon Demo" --access-key mpk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx --env my-aws-prod --backend-base-url https://publisher.example.com/api/ --output aws_coupon_demo.partner.json
```

The host app team imports that package from the Flutter app root:

```bash
cd my_mini_host
miniprogram host endpoint import ../aws_coupon_demo.partner.json
```

Generate or update a host-owned endpoint file:

```bash
cd my_mini_host
miniprogram host endpoint add aws_coupon_demo --title "AWS Coupon Demo" --api-base-url https://aws.example.com/prod/api/ --access-key mpk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
miniprogram host endpoint add public_coupon_demo --title "Public Coupon Demo" --api-base-url https://user.github.io/repo/public_mini_program/ --public
miniprogram host endpoint add rewards --title "Rewards" --api-base-url https://aws.example.com/prod/api/ --access-key mpk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx --backend-base-url https://publisher.example.com/api/
```

The generated host runtime wires publisher backend endpoints lazily. No
publisher backend HTTP client or request is created at app startup.

For Firebase publisher backends, publishers can create a host handoff package
without giving the host team Firebase project access:

```bash
miniprogram publisher-backend firebase handoff --env my-firebase-prod --delivery-url https://user.github.io/repo/public_mini_program/ --public --output firebase_coupon.partner.json
```

The package uses the same `.partner.json` format as `miniprogram partner
package`, includes the Firebase Functions backend URL, and imports through
`miniprogram host endpoint import`. Use
`miniprogram publisher-backend firebase host-command` only when a full-stack
developer wants to generate or verify an exact `host endpoint add` command
against a local host app.

Then wire it once:

```dart
import 'mini_program/mini_program_endpoints.dart';
import 'mini_program/mini_program_runtime_setup.dart';

MiniProgramScope(
  config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),
  child: const MyApp(),
);
```

Buttons remain clean:

```dart
openAppMiniProgram(context, appId: 'aws_coupon_demo', title: 'AWS Coupon Demo');
openAppMiniProgram(context, appId: 'public_coupon_demo', title: 'Public Coupon Demo');
```

### Publisher backend starter

Use the publisher backend starter when you want mini-program UI that already
loads mock backend JSON, binds images and list data, and shows fake session/auth
data during local development:

```bash
miniprogram create coupon_app --title "Coupon App" --with-backend mock
cd coupon_app
miniprogram publisher-backend run --port 9090
```

This creates:

```text
backend/
  mock/
    pubspec.yaml
    README.md
    bin/server.dart
    data/home_bootstrap.json
    data/coupons_list.json
    data/session.json
```

The mock backend serves:

- `GET /health`
- `GET /home/bootstrap`
- `GET /coupons/list`
- `GET /auth/session`
- `POST /coupon/redeem`
- `OPTIONS *` for browser CORS

Print the target URLs with:

```bash
miniprogram publisher-backend urls --port 9090
```

Use `http://127.0.0.1:9090/` in generated host config for local mock backend
testing. With `mini_program_sdk` 0.3.5 or newer, the SDK can fall back between
`127.0.0.1` / `localhost` and Android emulator `10.0.2.2`, so one host config
works for Chrome, desktop, and Android emulator. Real devices may need your
computer LAN IP or `adb reverse`.

Host endpoint setup still has two URLs:

- `--api-base-url` is delivery: manifest and screen JSON
- `--backend-base-url` is publisher business data: coupons, session, lists, and
  other JSON API calls

Example for a public static delivery mini-program with a local mock business
backend:

```bash
miniprogram host endpoint add coupon_app --title "Coupon App" --api-base-url https://user.github.io/repo/public_mini_program/ --public --backend-base-url http://127.0.0.1:9090/
```

Preferred local mock shortcut:

```bash
miniprogram host endpoint add coupon_app --title "Coupon App" --api-base-url https://user.github.io/repo/public_mini_program/ --public --backend-local-mock
```

Use a custom mock port with:

```bash
miniprogram host endpoint add coupon_app --title "Coupon App" --api-base-url https://user.github.io/repo/public_mini_program/ --public --backend-local-mock --backend-local-mock-port 9091
```

The mock backend is local development only. Production backends can later be
AWS Lambda, Firebase Functions, GCP, or any HTTP JSON server with the same route
shape. Firebase/AWS/custom SDKs belong on the publisher server, not in
`mini_program_sdk` or the host app. Keep backend secrets on the publisher
server.

#### AWS Lambda publisher backend

When the mock routes are working locally, scaffold the AWS Lambda starter:

```bash
miniprogram publisher-backend scaffold --template aws-lambda
```

This creates `backend/aws_lambda/` with a SAM template, Node.js Lambda handler,
and the same sample JSON routes as the mock backend. By default the Lambda reads
bundled JSON from `src/data/` so simple demos do not create a database.

For persistent AWS storage, opt in to DynamoDB:

```bash
miniprogram publisher-backend scaffold --template aws-lambda --storage dynamodb
```

The DynamoDB scaffold adds a stack-owned table, Lambda environment variables,
and a least-scope DynamoDB policy for the generated function.

- `GET /health`
- `GET /home/bootstrap`
- `GET /coupons/list`
- `GET /auth/session`
- `POST /coupon/redeem`

Deploy it with an existing AWS environment:

```bash
miniprogram publisher-backend aws deploy --env my-aws-prod
```

The deploy output includes `PublisherBackendBaseUrl`. Connect that URL to a
host endpoint:

```bash
miniprogram host endpoint add coupon_app --title "Coupon App" --api-base-url https://user.github.io/repo/public_mini_program/ --public --backend-base-url https://abc.execute-api.ap-south-1.amazonaws.com/prod/
```

Useful AWS backend commands:

```bash
miniprogram publisher-backend aws status --env my-aws-prod --json
miniprogram publisher-backend aws outputs --env my-aws-prod --json
miniprogram publisher-backend aws smoke --env my-aws-prod
miniprogram publisher-backend aws smoke --env my-aws-prod --include-write --write-coupon-id coupon-10 --write-user-id smoke-user
miniprogram publisher-backend aws seed --env my-aws-prod
miniprogram publisher-backend aws data status --env my-aws-prod --json
miniprogram publisher-backend aws data export --env my-aws-prod --include-redemptions
miniprogram publisher-backend aws data import --env my-aws-prod --input backend/aws_lambda/exports/coupon_app-my-aws-prod-data-export-20260523T120000Z.json --dry-run --include-redemptions
miniprogram publisher-backend aws data redemptions --env my-aws-prod --coupon-id coupon-10
miniprogram publisher-backend aws logs --env my-aws-prod --since 1h
miniprogram publisher-backend aws destroy --env my-aws-prod --yes --confirm-data-loss
```

Deploy waits for API Gateway/Lambda health with cold-start-aware retries before
reporting failure. Use `smoke` for a read-only check of `/health`,
`/home/bootstrap`, `/coupons/list`, and `/auth/session` after deploy. Add
`--include-write` only when you want to verify `POST /coupon/redeem`; this
mutates backend data by writing or reusing a redemption record.

Use `aws seed` after deploying a `--storage dynamodb` backend to upsert the
starter home, session, and coupon records into the generated DynamoDB table.
Seed retries unprocessed DynamoDB batch writes. Use `aws data status` to check
the table status, app record count, and redemption count across paginated query
results. Use `aws data export` before production changes or stack cleanup; by
default exports exclude redemptions, and `--include-redemptions` explicitly
includes redemption history. `aws data import --dry-run` validates an export
before upserting records, and redemptions are skipped unless
`--include-redemptions` is set. Use `aws data redemptions` to inspect recent
redemption records with coupon/user filters.

`aws destroy --yes` now checks stack-owned DynamoDB data before deleting the
stack. If app records or redemptions exist, it stops until you export or migrate
the data and pass `--confirm-data-loss`.

This AWS backend is separate from the mini-program delivery AWS stack. It is for
publisher business APIs only. AWS credentials, Firebase Admin credentials,
database secrets, and payment secrets belong in Lambda/server configuration, not
in mini-program JSON, host app source, APK, IPA, or web JavaScript.

#### Firebase Functions publisher backend

To start a Firebase publisher-owned backend, scaffold the Firebase Functions
starter:

```bash
miniprogram publisher-backend scaffold --template firebase-functions --storage firestore
```

This creates `backend/firebase_functions/` with Firebase Cloud Functions v2,
Firestore store wiring, sample data, and the same publisher backend routes as
the mock and AWS starters:

- `GET /health`
- `GET /home/bootstrap`
- `GET /coupons/list`
- `GET /auth/session`
- `POST /coupon/redeem`

The generated Firestore model is:

- `miniPrograms/<appId>/home/bootstrap`
- `miniPrograms/<appId>/sessions/demo`
- `miniPrograms/<appId>/coupons/<couponId>`
- `miniPrograms/<appId>/redemptions/<safeUserId_safeCouponId>`

Configure a Firebase environment, deploy the function, and smoke-test the
publisher routes:

```bash
miniprogram env configure my-firebase-prod --provider firebase --project-id my-firebase-project --region us-central1
miniprogram publisher-backend firebase deploy --env my-firebase-prod
miniprogram publisher-backend firebase seed --env my-firebase-prod
miniprogram publisher-backend firebase data status --env my-firebase-prod
miniprogram publisher-backend firebase status --env my-firebase-prod --json
miniprogram publisher-backend firebase outputs --env my-firebase-prod
miniprogram publisher-backend firebase smoke --env my-firebase-prod
miniprogram publisher-backend firebase smoke --env my-firebase-prod --include-write --write-coupon-id coupon-10 --write-user-id smoke-user
```

The deploy command runs `npm install` when `functions/node_modules` is missing,
writes `PUBLISHER_BACKEND_REGION` and `MINI_PROGRAM_ID` to `functions/.env`,
runs `firebase deploy --only functions:<functionName> --project <projectId>`,
tries to grant public Cloud Run Invoker for the HTTPS function, and records
`.mini_program/publisher_backend.firebase.json`. Use `--no-public-invoker` if
you want to manage Cloud Run invoker permissions yourself.

`firebase seed` upserts the generated starter JSON into Firestore:

- `functions/data/home_bootstrap.json` -> `home/bootstrap`
- `functions/data/session.json` -> `sessions/demo`
- `functions/data/coupons_list.json` -> `coupons/<couponId>`

`firebase data status` counts home, session, coupon, and redemption documents so
you can confirm that Firestore has the records needed for smoke tests. These
Firestore data commands use your Firebase CLI login token, so run
`firebase login` first or provide `FIREBASE_TOKEN` in CI.
If Firestore rejects a stale Firebase CLI access token, tooling exchanges the
stored refresh token for a fresh OAuth token and retries the REST request once.

Use export/import and redemption inspection before risky changes:

```bash
miniprogram publisher-backend firebase data export --env my-firebase-prod --include-redemptions
miniprogram publisher-backend firebase data import --env my-firebase-prod --input firebase-export.json --dry-run --include-redemptions
miniprogram publisher-backend firebase data redemptions --env my-firebase-prod --coupon-id coupon-10
```

`firebase destroy --yes` deletes the Cloud Function only. It first checks
Firestore and blocks when app records or redemptions exist unless
`--confirm-data-loss` is passed.

By default, the backend URL is derived as
`https://<region>-<projectId>.cloudfunctions.net/<functionName>/`. If your
Firebase project uses a different HTTPS function URL shape, pass
`--function-url <url>` during `env configure`.

Firebase smoke checks `GET /health`, `GET /home/bootstrap`,
`GET /coupons/list`, and `GET /auth/session` by default. Add
`--include-write` to also call `POST /coupon/redeem` and verify that the
expected Firestore redemption document exists.

After the mini-program delivery URL is public or otherwise reachable, generate
the publisher-to-host handoff package:

```bash
miniprogram publisher-backend firebase handoff \
  --env my-firebase-prod \
  --delivery-url https://user.github.io/repo/public_mini_program/ \
  --public \
  --output firebase_coupon.partner.json
```

Give the `.partner.json` file to the host app developer. They import it with
`miniprogram host endpoint import`; they do not need Firebase CLI login,
Firebase project access, Firebase SDKs, or publisher backend secrets.

For local full-stack testing, generate the exact host endpoint command:

```bash
miniprogram publisher-backend firebase host-command \
  --env my-firebase-prod \
  --api-base-url https://user.github.io/repo/public_mini_program/ \
  --public
```

To check whether a Flutter host app is already wired to the same Firebase
publisher backend, pass the host project root:

```bash
miniprogram publisher-backend firebase host-command \
  --env my-firebase-prod \
  --api-base-url https://user.github.io/repo/public_mini_program/ \
  --public \
  --host-project-root ../host_app
```

The command is read-only. It prints the `miniprogram host endpoint add ...`
command with `--backend-base-url <Firebase Functions URL>` and reports whether
the host endpoint map already matches the app id, delivery URL, remote backend
URL, and access mode.

Firebase Admin SDK dependencies are generated only inside the publisher backend.
The Flutter host app and `mini_program_sdk` do not need Firebase SDKs unless the
host app itself chooses to use Firebase features such as Firebase Auth.

### Publisher-owned backend

Use publisher backend endpoints when the mini-program company owns its Firebase,
AWS, or custom server. Delivery still comes from `--api-base-url`; business API
calls use `--backend-base-url` and the generated backend helpers in
`lib/host_action_helpers.dart`.

```dart
miniProgramBackendBuilder(
  requestId: 'home',
  endpoint: 'home/bootstrap',
  cacheTtl: const Duration(seconds: 60),
  loading: StacText(data: 'Loading...'),
  error: StacText(data: '{{backend.home.message}}'),
  child: StacColumn(
    children: [
      StacText(data: '{{backend.home.data.title}}'),
    ],
  ),
)
```

Refresh the same state from a button:

```dart
miniProgramBackendQueryAction(
  requestId: 'home',
  endpoint: 'home/bootstrap',
  forceRefresh: true,
)
```

Use `miniProgramBackendAction(...)` when you need a backend call result without
storing state for `{{backend.*}}` bindings.

Rules:

- backend action endpoints must be relative, such as `home/bootstrap`
- default cache is off; cache is only for explicit `GET` TTLs
- MiniProgram access keys protect delivery, not user identity
- backend secrets must stay on the publisher server, not in JSON, source, APK,
  IPA, or web JavaScript
- use batch APIs, short timeouts, paginated responses, and CDN image URLs
- use `itemsPath` + `itemTemplate` for simple repeated backend lists with
  `{{item.*}}` bindings

Current cloud support in this phase:

- provider implementation shipped: `aws`
- planned next providers: `gcp`, `custom-s3-compatible`
- AWS deploy support in `mini_program_tooling` assumes:
  - Windows + PowerShell
  - region `ap-south-1`
  - fastest working path first
  - normal developers use the published CLI only; they do not need to manually
    use the repo `infra/` folder

Important rule:

- if you signed in with the AWS **root account**, you can create IAM users,
  buckets, and everything else
- if you signed in with an **IAM user/role** and cannot create those things,
  you do not have enough permissions and need an admin to grant them

### 1. One-time AWS account setup

Best practice:

- use the root account only for:
  - enabling MFA
  - creating an admin identity
- do not use root for daily work

Fastest practical setup for your own standalone AWS account:

1. sign in as **root**
2. enable **MFA** on root
3. open **IAM**
4. create a user like `mini-admin`
5. give it `AdministratorAccess`
6. create:
   - console access
   - access key for CLI use
7. sign out of root
8. sign in as `mini-admin`

For first setup, `AdministratorAccess` is the easiest path. Later you can
replace it with a narrower deploy policy.

### 2. Install tools on your computer

Install:

- AWS CLI
- AWS SAM CLI
- Node.js 24 or newer
- Flutter
- Dart

Then verify:

```powershell
aws --version
sam --version
node --version
flutter --version
dart --version
```

`miniprogram cloud deploy` uses an AWS Lambda `nodejs24.x` backend template.
Keep AWS SAM CLI up to date enough to deploy `nodejs24.x` functions.

### 3. Connect your computer to AWS

Option A: access key profile

```powershell
aws configure --profile my-aws
aws sts get-caller-identity --profile my-aws
```

Enter:

- Access key ID
- Secret access key
- Region: `ap-south-1`
- Output format: `json`

If that works, your computer is connected to AWS.

Option B: AWS SSO

```powershell
aws configure sso --profile my-sso
aws sso login --profile my-sso
aws sts get-caller-identity --profile my-sso
```

For a new standalone personal account, the access-key profile path is usually
simpler.

### 4. Create the S3 bucket

Bucket names must be globally unique.

Example:

```powershell
aws s3api create-bucket --bucket my-mini-program-prod-ap-south-1-001 --region ap-south-1 --create-bucket-configuration LocationConstraint=ap-south-1 --profile my-aws
```

Enable versioning:

```powershell
aws s3api put-bucket-versioning --bucket my-mini-program-prod-ap-south-1-001 --versioning-configuration Status=Enabled --region ap-south-1 --profile my-aws
aws s3api get-bucket-versioning --bucket my-mini-program-prod-ap-south-1-001 --region ap-south-1 --profile my-aws
```

Expected result:

```json
{
  "Status": "Enabled"
}
```

### 5. Create your mini-program

```powershell
cd D:\
miniprogram create my_coupon_app
cd my_coupon_app
miniprogram preview -d chrome
```

Use preview first so you confirm the mini-program works before cloud deploy.

### 6. Configure `miniprogram` for AWS

Initialize env:

```powershell
miniprogram env init
```

Configure the AWS environment:

```powershell
miniprogram env configure my-aws-prod --provider aws --bucket my-mini-program-prod-ap-south-1-001 --region ap-south-1 --aws-profile my-aws
```

Select it:

```powershell
miniprogram env use my-aws-prod
miniprogram env status
```

### 7. Publish and deploy to AWS

Publish the mini-program artifacts to S3:

```powershell
miniprogram publish --target cloud
```

Check cloud prerequisites:

```powershell
miniprogram cloud doctor
```

Deploy the API Gateway + Lambda backend:

```powershell
miniprogram cloud deploy
```

Inspect outputs:

```powershell
miniprogram cloud outputs
miniprogram cloud outputs --format dart-define
```

What the CLI does here:

- uploads artifacts to S3
- generates a managed SAM project locally
- runs `sam build`
- runs `sam deploy`
- creates or updates:
  - API Gateway
  - Lambda
  - Lambda IAM role

You do not manually create API Gateway routes.

### 8. Connect a Flutter host app

If you do not have a host app yet:

```powershell
cd D:\
flutter create my_mini_host
cd my_mini_host
miniprogram embed init
flutter pub get
```

For first-run testing without AWS, access keys, or your own published
mini-program yet, generate a public jsDelivr demo endpoint:

```powershell
miniprogram embed init --with-demo
flutter pub get
```

That also creates:

- `lib/mini_program/mini_program_endpoints.dart`
- `lib/mini_program/mini_program_registry.dart`
- a README button snippet using `MiniPrograms.publicDemo`

The generated demo endpoint is public and uses:

```text
https://cdn.jsdelivr.net/gh/mehedi8603651/miniprogram-public@main/
```

When publishing your own public static mini-program, replace it with your repo:

```text
https://cdn.jsdelivr.net/gh/mehedi8603651/<repo>@main/
```

Bind that host app to your AWS env:

```powershell
miniprogram embed cloud configure --env my-aws-prod
```

Run it:

```powershell
miniprogram host run -d chrome --env my-aws-prod
```

Or Windows desktop:

```powershell
miniprogram host run -d windows --env my-aws-prod
```

That wraps `flutter run` and passes the deployed backend URL automatically.

For release APK builds, use the backend define from the cloud outputs:

```powershell
miniprogram cloud outputs --format dart-define
cd D:\my_mini_host
flutter build apk --release --dart-define=MINI_PROGRAM_BACKEND_BASE_URL=https://<api-id>.execute-api.<aws-region>.amazonaws.com/prod/api/
```

Use the `BackendApiBaseUrl` shown by `miniprogram cloud outputs`; do not use
the S3 bucket URL directly. The host app loads through API Gateway + Lambda.

Demo `lib/main.dart` after `miniprogram host endpoint import` or
`miniprogram host endpoint add --title <title>` has created
`mini_program_endpoints.dart` and `mini_program_registry.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'mini_program/mini_program_endpoints.dart';
import 'mini_program/mini_program_launcher.dart';
import 'mini_program/mini_program_registry.dart';
import 'mini_program/mini_program_runtime_setup.dart';

void main() {
  runApp(
    MiniProgramScope(
      config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiniProgram Host',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MiniProgram Host')),
      body: Center(
        child: FilledButton(
          onPressed: () {
            openAppMiniProgram(
              context,
              appId: MiniPrograms.awsCouponDemo.appId,
              title: MiniPrograms.awsCouponDemo.title,
            );
          },
          child: const Text('Open Coupon MiniProgram'),
        ),
      ),
    );
  }
}
```

If the host app uses state management, keep using it normally. `MiniProgramScope`
is only a mini-program service scope, so it can sit inside or outside your
state-management root.

Riverpod:

```dart
void main() {
  runApp(
    ProviderScope(
      child: MiniProgramScope(
        config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),
        child: const MyApp(),
      ),
    ),
  );
}
```

Provider:

```dart
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: MiniProgramScope(
        config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),
        child: const MyApp(),
      ),
    ),
  );
}
```

Bloc:

```dart
void main() {
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc()),
      ],
      child: MiniProgramScope(
        config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),
        child: const MyApp(),
      ),
    ),
  );
}
```

`MiniProgramScope` does not require Riverpod, Provider, Bloc, GetX, or GoRouter;
these examples are only composition patterns for host apps that already use
those packages.

Generated host-app structure:

- `pubspec.yaml` is updated with `mini_program_sdk` and
  `mini_program_contracts`
- `lib/mini_program/mini_program.dart` is an optional generated barrel export
  if you prefer one app-local import
- `lib/mini_program/mini_program_launcher.dart` exposes
  `openAppMiniProgram(...)` and `AppMiniProgramLauncher`
- `lib/mini_program/mini_program_runtime_setup.dart` resolves
  `MINI_PROGRAM_BACKEND_BASE_URL`, accepts optional
  `Map<String, MiniProgramEndpoint>` endpoint routing, and builds
  `MiniProgramConfig`
- `lib/mini_program/app_host_bridge.dart` is where developers wire real
  analytics, optional native screens, and secure API behavior
- `lib/main.dart` stays app-owned; edit it to add buttons, tabs, or menu items
  that call `openAppMiniProgram(...)`
- `MiniProgramScope` does not create or control `MaterialApp`,
  `MaterialApp.router`, GetX, GoRouter, Provider, Bloc, Riverpod, themes,
  localization, routes, or navigator setup
- for multi-publisher apps, register
  `appId -> API base URL + MiniProgram access key` in
  `buildMiniProgramConfig(endpoints: ...)`; screens still call
  `openAppMiniProgram(context, appId: ...)`
- protected cloud backends should validate `X-Mini-Program-Access-Key` against
  per-mini-program access-key metadata so one partner key can be revoked
  without changing the appId or breaking other partners
- Android release builds need internet access to load cloud mini-programs.
  `miniprogram embed init` writes
  `android.permission.INTERNET` into `android/app/src/main/AndroidManifest.xml`.
  Debug builds also get cleartext/network config for local HTTP backend access.

### 9. Minimum policies you need

Easiest first setup:

- use `AdministratorAccess` on your admin user

That is the shortest path to get working.

Narrower deploy user later needs at least:

- S3 bucket access
  - `s3:ListBucket`
  - `s3:GetBucketLocation`
  - `s3:GetBucketVersioning`
  - `s3:GetObject`
  - `s3:PutObject`
  - `s3:DeleteObject`
  - `s3:AbortMultipartUpload`
- CloudFormation
  - `cloudformation:CreateStack`
  - `cloudformation:UpdateStack`
  - `cloudformation:DeleteStack`
  - `cloudformation:DescribeStacks`
  - `cloudformation:DescribeStackEvents`
  - `cloudformation:DescribeStackResources`
  - `cloudformation:ListStackResources`
  - `cloudformation:CreateChangeSet`
  - `cloudformation:ExecuteChangeSet`
  - `cloudformation:DeleteChangeSet`
  - `cloudformation:DescribeChangeSet`
  - `cloudformation:GetTemplate`
  - `cloudformation:GetTemplateSummary`
  - `cloudformation:ValidateTemplate`
- Lambda
  - `lambda:CreateFunction`
  - `lambda:UpdateFunctionCode`
  - `lambda:UpdateFunctionConfiguration`
  - `lambda:DeleteFunction`
  - `lambda:GetFunction`
  - `lambda:GetFunctionConfiguration`
  - `lambda:GetPolicy`
  - `lambda:AddPermission`
  - `lambda:RemovePermission`
  - `lambda:TagResource`
  - `lambda:UntagResource`
  - `lambda:ListTags`
- API Gateway
  - `apigateway:GET`
  - `apigateway:POST`
  - `apigateway:PUT`
  - `apigateway:PATCH`
  - `apigateway:DELETE`
  - `apigateway:TagResource`
  - `apigateway:UntagResource`
- IAM role management for the Lambda execution role
  - `iam:CreateRole`
  - `iam:DeleteRole`
  - `iam:GetRole`
  - `iam:PassRole`
  - `iam:TagRole`
  - `iam:UntagRole`
  - `iam:AttachRolePolicy`
  - `iam:DetachRolePolicy`
  - `iam:PutRolePolicy`
  - `iam:DeleteRolePolicy`
  - `iam:GetRolePolicy`
  - `iam:ListRolePolicies`
  - `iam:ListAttachedRolePolicies`
- If your bucket uses KMS encryption, also:
  - `kms:Encrypt`
  - `kms:Decrypt`
  - `kms:GenerateDataKey`
  - `kms:DescribeKey`

### 10. If you still cannot create IAM users or buckets

Then one of these is true:

- you are not signed in as root or admin
- your IAM user/role is restricted
- your AWS account is inside an AWS Organization with SCP restrictions

In that case, ask the account admin for either:

- `AdministratorAccess` temporarily for setup
- or a dedicated deploy user/role with the permissions above

### Exact end-to-end command sequence

```powershell
# 1. configure aws cli
aws configure --profile my-aws
aws sts get-caller-identity --profile my-aws

# 2. create bucket
aws s3api create-bucket --bucket my-mini-program-prod-ap-south-1-001 --region ap-south-1 --create-bucket-configuration LocationConstraint=ap-south-1 --profile my-aws
aws s3api put-bucket-versioning --bucket my-mini-program-prod-ap-south-1-001 --versioning-configuration Status=Enabled --region ap-south-1 --profile my-aws

# 3. create and test mini-program locally
cd D:\
miniprogram create my_coupon_app
cd my_coupon_app
miniprogram preview -d chrome

# 4. configure miniprogram aws env
miniprogram env init
miniprogram env configure my-aws-prod --provider aws --bucket my-mini-program-prod-ap-south-1-001 --region ap-south-1 --aws-profile my-aws
miniprogram env use my-aws-prod
miniprogram cloud doctor

# 5. publish and deploy
miniprogram publish --target cloud
miniprogram cloud deploy
miniprogram cloud outputs

# 6. host app
cd D:\
flutter create my_mini_host
cd my_mini_host
miniprogram embed init
flutter pub get
miniprogram embed cloud configure --env my-aws-prod
miniprogram host run -d chrome --env my-aws-prod
```

Official AWS docs:

- Root user best practices: https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html
- Create an administrative user: https://docs.aws.amazon.com/accounts/latest/reference/getting-started-step4.html
- Create an IAM user: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html
- Install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- Configure AWS CLI SSO: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html
- Install AWS SAM CLI: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html
- `sam deploy` capabilities: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-cli-command-reference-sam-deploy.html
- Create S3 bucket with CLI: https://docs.aws.amazon.com/cli/v1/reference/s3api/create-bucket.html
- Enable S3 versioning: https://docs.aws.amazon.com/AmazonS3/latest/userguide/manage-versioning-examples.html
- `put-bucket-versioning` CLI: https://docs.aws.amazon.com/cli/v1/reference/s3api/put-bucket-versioning.html

Initialize the embedding adapter for an existing Flutter app:

```bash
cd <existing-flutter-app>
miniprogram embed init
```

`embed init` updates the host app `pubspec.yaml` to use the published
`mini_program_sdk` and `mini_program_contracts` packages.

When the local backend is already running on port `8080`, the generated
runtime setup uses target-aware defaults:

- Android local default: `http://10.0.2.2:8080/api/`
- desktop, Chrome on the same machine, and iOS simulators:
  `http://127.0.0.1:8080/api/`
- Android USB `adb reverse` flows keep using `127.0.0.1`, and the shared SDK
  retries local loopback between `10.0.2.2` and `127.0.0.1` on transport
  failures

Conditions:

- the local backend should already be running on port `8080`
- Android USB or emulator loopback may still depend on an active `adb reverse`
  session when the device cannot route to `10.0.2.2`
- if the Android device or emulator connects after backend start, rerun
  `miniprogram backend start --port 8080` or reapply `adb reverse`
- physical devices over Wi-Fi should override
  `MINI_PROGRAM_BACKEND_HOST=<computer-lan-ip>`

So Android emulator development should usually work with:

```bash
flutter run -d emulator-5554
```

`miniprogram embed init` also writes Android release `INTERNET` permission and
debug-only cleartext/network configuration so cloud release APKs can call the
API Gateway backend and the generated emulator default can reach
`http://10.0.2.2:8080/api/` without manual manifest edits.

For physical-device Wi-Fi or cloud testing, override either the full base URL
or just the host/port:

```bash
flutter run -d chrome --dart-define=MINI_PROGRAM_BACKEND_HOST=192.168.1.25
flutter run -d windows --dart-define=MINI_PROGRAM_BACKEND_BASE_URL=https://mini.example.com/api/
```

If you need to target an app from another directory, use:

```bash
miniprogram embed init --project-root <existing-flutter-app>
```

Start and inspect the local backend:

```bash
miniprogram backend start --port 8080
miniprogram backend status
miniprogram backend stop
```

When `adb` is available, `miniprogram backend start` also tries
`adb reverse tcp:<port> tcp:<port>` for connected Android emulators and
devices. That keeps the common local Android flow on plain `flutter run`
instead of requiring a manual reverse step every time.

For local debugging, `miniprogram backend start` and `miniprogram backend
status` print the target-specific URLs the generated host adapter expects:

- Android emulator: `http://10.0.2.2:<port>/api/`
- desktop and Chrome on the same machine: `http://127.0.0.1:<port>/api/`
- Android USB with `adb reverse`: `http://127.0.0.1:<port>/api/`

The generated host runtime also logs the resolved backend base URL and whether
it came from:

- `MINI_PROGRAM_BACKEND_BASE_URL`
- `MINI_PROGRAM_BACKEND_HOST` and `MINI_PROGRAM_BACKEND_PORT`
- target-aware defaults

For Chrome and other web targets, the generated local backend workspace now
includes browser-friendly CORS and localhost private-network headers, so plain
local web runs can reach `http://127.0.0.1:8080/api/` without manual backend
service patching.

`miniprogram doctor` reports:

- Dart runtime availability
- `flutter` on PATH
- managed pinned Stac builder status and pinned version
- saved env configuration
- optional platform repo root
- local backend workspace layout
- current backend health/state

## Local CLI state

The CLI keeps repo-local state in:

- `.mini_program/env.json`
- `.mini_program/backend_workspace.json`
- `.mini_program/backend.local.json`
- `.mini_program/published_local_artifacts.json`

It also keeps a user-level fallback file in:

- `~/.mini_program/global_env.json`
- `~/.mini_program/global_backend_workspace.json`

Project-local preview also manages:

- `.mini_program/preview_host/`

`backend reset-local --yes` only removes tracked local publish outputs. It does
not wipe all of `backend/api/` or remove rollout, capability, or secure API
policy files that were not created by the CLI publish flow.

## Notes

- `env use` now selects either `local` or a configured named cloud environment.
- `env configure` stores named cloud environments such as `my-aws-prod` or
  `my-gcp-staging`.
- `publish --target cloud` is implemented for `aws` in this phase.
- `cloud deploy|status|outputs|logs|destroy|doctor|rollback` are implemented for
  `aws` in this phase.
- `gcp` and `custom-s3-compatible` are the planned next cloud providers.
- Standalone build/publish/validate no longer require a platform repo root.
- `preview` is the fastest local authoring loop; `publish` plus
  `backend start` remains the real local delivery simulation.
- Normal builds use the managed pinned Stac builder bundled inside
  `mini_program_tooling`.
- `--stac-cli-script` remains the escape hatch when you intentionally need to
  override that managed builder.
- Local backend lifecycle commands can work from either:
  - the default per-user `miniprogram backend init` workspace
  - the platform repo layout with `backend/local_backend_service/` and
    `backend/api/`
- `publish` follows the same backend workspace resolution, so local publish
  outputs and `backend reset-local --yes` stay attached to the initialized
  backend workspace.
- Existing low-level Dart bins remain in the repo for compatibility.
- The repo PowerShell wrappers now delegate to the installed `miniprogram`
  command for the standard text workflow and only fall back to legacy Dart
  entrypoints for compatibility-only modes such as `-Output json`.
- `miniprogram ...` is the preferred workflow.
