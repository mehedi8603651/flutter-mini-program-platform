# mini_program_tooling

Developer tooling for the portable Flutter mini-program platform.

This package exposes the global `miniprogram` CLI used to create mini-programs,
build and validate authored flows, preview with watch/rebuild/refresh, publish
to local, public static, or AWS cloud delivery, deploy the managed AWS backend, initialize
embedding adapters for existing Flutter apps, bind host apps to cloud
environments, manage MiniProgram access keys, generate host endpoint maps,
exchange partner handoff packages between publishers and host app teams, and
manage the local backend lifecycle.

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
miniprogram create <mini-program-id>
miniprogram doctor [--json]
miniprogram backend init
miniprogram env init
miniprogram env configure <env-name> --provider aws --bucket <unique-bucket-name> --region <aws-region> [--aws-profile <aws-profile>] [--require-access-keys]
miniprogram env list
miniprogram env use <local|env-name>
miniprogram env status [--json]
miniprogram build [mini-program-id]
miniprogram preview -d <chrome|edge|ios|linux|macos|windows|emulator-5554|android-device-id|android-wifi-device-id> [mini-program-id]
miniprogram validate [mini-program-id]
miniprogram publish [mini-program-id] [--target local|cloud|static] [--env <env-name>] [--output <folder>] [--clean]
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
miniprogram partner package <mini-program-id> (--access-key <key>|--public) [--api-base-url <url>|--env <env-name>] [--output <file>]
miniprogram host run -d <device> [--env <env-name>]
miniprogram host endpoint add <mini-program-id> --api-base-url <url> (--access-key <key>|--public)
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

Use `--remote` only when you want AWS/backend checks:

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
miniprogram host endpoint add public_coupon_demo --api-base-url https://user.github.io/repo/public_mini_program/ --public
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

For partner handoff, the publisher can package the appId, title, API base URL,
and one MiniProgram access key into a JSON file for protected delivery:

```bash
miniprogram partner package aws_coupon_demo --title "AWS Coupon Demo" --access-key mpk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx --env my-aws-prod --output aws_coupon_demo.partner.json
```

For public/static delivery, create a public handoff package without a key:

```bash
miniprogram partner package public_coupon_demo --title "Public Coupon Demo" --public --api-base-url https://user.github.io/repo/public_mini_program/ --output public_coupon_demo.partner.json
```

The host app team imports that package from the Flutter app root:

```bash
cd my_mini_host
miniprogram host endpoint import ../aws_coupon_demo.partner.json
```

Generate or update a host-owned endpoint file:

```bash
cd my_mini_host
miniprogram host endpoint add aws_coupon_demo --api-base-url https://aws.example.com/prod/api/ --access-key mpk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
miniprogram host endpoint add public_coupon_demo --api-base-url https://user.github.io/repo/public_mini_program/ --public
```

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
`miniprogram host endpoint add` has created `mini_program_endpoints.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'mini_program/mini_program_endpoints.dart';
import 'mini_program/mini_program_launcher.dart';
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
              appId: 'aws_coupon_demo',
              title: 'AWS Coupon Demo',
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
