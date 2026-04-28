# flutter-mini-program-platform

Portable mini-program platform built around:

- shared contracts
- a shared Flutter runtime SDK
- Stac-authored portable UI
- local and AWS cloud delivery
- controlled host-native bridges

The project goal is simple:

> one mini-program should be able to run inside multiple host apps without
> rewriting the whole business flow for every host

## What This Platform Is

This is a **platform repo**, not a normal single Flutter app.

It has five main layers:

1. `mini_program_contracts`
2. `mini_program_sdk`
3. mini-program source
4. host apps
5. backend delivery

The key design rule is:

> keep portable UI declarative, keep sensitive and host-specific power behind
> the host bridge

## Current Shipped System

Already shipped:

- published packages:
  - `mini_program_contracts`
  - `mini_program_sdk`
  - `mini_program_tooling`
- global `miniprogram` CLI
- standalone local backend workspace
- standalone local authoring flow
- host-app embedding flow for Flutter apps
- AWS cloud publishing through S3
- AWS API Gateway + Lambda cloud backend deployment
- host-app cloud binding and `host run`
- target-aware local runtime defaults for:
  - Android emulator
  - Windows desktop
  - Chrome on the same machine
  - Edge on the same machine
  - Linux desktop
  - macOS desktop
  - iOS simulators
  - Android USB with `adb reverse`
  - Android Wi-Fi over LAN

The current system is strongest for **local developer workflows**,
**AWS-backed cloud delivery**, and **portable Flutter-hosted mini-programs**.

Future-only roadmap is tracked in:

- [nextWorkAgents.md](D:/flutter-mini-program-platform/nextWorkAgents.md)

## What This Platform Is Good For

This platform is a good fit for:

- forms
- onboarding
- profile and settings flows
- recharge or top-up flows
- campaign pages
- dashboards
- account flows
- subscription and plan-selection flows
- feedback and support flows
- modular business workflows
- tenant-specific or host-specific presentation differences

It is especially suitable for:

- super-app style products
- company apps
- enterprise apps
- partner-hosted apps

## What Should Stay Native

Do not force everything into a mini-program.

Keep these native:

- payment SDK execution
- banking-grade secure auth
- biometric and OTP/PIN flows
- login bootstrap
- camera-heavy flows
- map-heavy real-time flows
- advanced editors
- highly custom animation-heavy experiences
- actual TV/player playback UI core
- hardware- or device-permission-heavy flows

Use mini-programs for the **portable business UI around those features**, not
for the sensitive or platform-heavy core execution.

## Current Technical Shape

### Contracts
`packages/mini_program_contracts`

This package defines the shared wire language:

- manifest shape
- capability names
- action names
- result payloads
- version rules
- stable error codes

### Runtime SDK
`packages/mini_program_sdk`

This package renders portable mini-program UI inside Flutter host apps.

It is responsible for:

- loading manifests and screens
- validating SDK compatibility
- enforcing declared capabilities
- rendering Stac JSON safely
- dispatching approved actions through the host bridge

### Tooling CLI
`packages/mini_program_tooling`

This package exposes the global `miniprogram` command used for:

- create
- doctor
- env
- build
- preview
- validate
- publish to local or cloud
- cloud
- embed init
- embed cloud configure
- host run
- backend init/start/stop/status/reset-local

### Mini-Program Authoring
Mini-programs are authored in Stac DSL and built into JSON.

Safe assumption:

```text
Stac DSL / StacWidget-style Dart -> stac build -> JSON
```

Unsafe assumption:

```text
any arbitrary Flutter widget tree -> automatic portable JSON
```

That is not the model.

## How The Platform Works

At a high level:

1. developer writes Stac DSL mini-program screens
2. `miniprogram build` runs the managed Stac builder
3. JSON screens and manifest artifacts are produced
4. developers either preview them directly, publish them into the local backend
   workspace, or publish immutable artifacts to cloud storage
5. host app loads manifest and screen JSON through `mini_program_sdk`
6. host bridge handles approved native operations

High-level flow:

```text
author -> build -> preview
                    or
author -> build -> validate -> publish -> backend delivery -> SDK load ->
render -> action dispatch -> host-native execution when needed
                    or
author -> build -> validate -> publish --target cloud -> cloud backend ->
SDK load -> render -> action dispatch -> host-native execution when needed
```

## Preferred Developer Entry Point

Install the published CLI once:

```powershell
dart pub global activate mini_program_tooling
```

Then use:

```powershell
miniprogram --help
```

The CLI is the source of truth for developers.

Older wrappers may still exist, but `miniprogram ...` is the preferred path.

Current command map:

```powershell
miniprogram create <mini-program-id>
miniprogram doctor
miniprogram env init
miniprogram env configure <env-name> --provider aws --bucket <bucket> --region <region> [--aws-profile <profile>]
miniprogram env list
miniprogram env use <local|env-name>
miniprogram env status
miniprogram build [mini-program-id]
miniprogram preview -d <device> [mini-program-id]
miniprogram validate [mini-program-id]
miniprogram publish [mini-program-id] [--target local|cloud] [--env <env-name>]
miniprogram cloud doctor|deploy|status|outputs|logs|destroy
miniprogram cloud outputs --format dart-define
miniprogram cloud rollback <version> [mini-program-id]
miniprogram embed init
miniprogram embed cloud configure --env <env-name>
miniprogram host run -d <device> --env <env-name>
miniprogram backend init
miniprogram backend start --port 8080
miniprogram backend stop
miniprogram backend status
miniprogram backend reset-local --yes
```

Use `miniprogram <command> --help`, `miniprogram <group> --help`, or
`miniprogram <group> <command> --help` for command-specific options.

## Local Developer Workflow

### 1. Create a mini-program

```powershell
cd D:\
miniprogram create my_coupon_app
```

The default scaffold uses only `analytics`, so it opens in a minimal generated
host app without native-route wiring. Add `native_navigation` only when your
host app has a real native route callback.

### 2. Fast preview loop

For the normal authoring loop, use managed preview first:

```powershell
cd D:\my_coupon_app
miniprogram preview -d chrome
```

V1 preview targets:

- `chrome`
- `edge`
- `ios` on macOS with Xcode
- `linux`
- `macos`
- `windows`
- `emulator-5554` and other Android emulator ids
- Android USB device ids such as `R58M123ABC`
- Android Wi-Fi device ids such as `192.168.1.25:5555`

Preview behavior:

- builds the current mini-program
- generates a hidden managed host under `.mini_program/preview_host`
- starts a tiny internal localhost preview transport when needed
- watches `manifest.json`, `stac/**`, `assets/**`, and `lib/default_stac_options.dart`
- rebuilds and fully refreshes the preview after a successful save

Preview mode rules:

- not the real local backend
- not `backend/api/`
- no manual `backend start`
- keeps the last successful UI visible if a rebuild fails
- Android emulator preview prefers `adb reverse tcp:<port> tcp:<port>` and
  uses `http://127.0.0.1:<port>/preview/` when reverse is available
- if emulator reverse cannot be applied, preview falls back to
  `http://10.0.2.2:<port>/preview/`
- Android USB preview auto-applies `adb reverse tcp:<port> tcp:<port>` and
  uses `http://127.0.0.1:<port>/preview/` inside the device session
- Android Wi-Fi preview uses a resolved LAN host such as
  `http://192.168.1.10:<port>/preview/`
- if auto-detected LAN routing is wrong, set `MINI_PROGRAM_PREVIEW_LAN_HOST`
  to your dev machine IP before running preview

Preview capability limits in v1:

- `analytics` logs inside the preview host and succeeds
- `native_navigation` opens a preview-only placeholder screen
- `secure_api` returns an explicit preview-only failure

### 3. Initialize local backend workspace for real delivery testing

```powershell
miniprogram backend init
```

On Windows the default backend workspace is:

```text
%LOCALAPPDATA%\mini_program\backend\
```

### 4. Initialize local env inside the mini-program

```powershell
cd D:\my_coupon_app
miniprogram env init
```

### 5. Build, validate, publish

Inside the mini-program folder:

```powershell
miniprogram build
miniprogram validate
miniprogram publish
```

Or from outside:

```powershell
miniprogram build my_coupon_app
miniprogram validate my_coupon_app
miniprogram publish my_coupon_app
```

### 6. Start backend

```powershell
miniprogram backend start --port 8080
miniprogram backend status
```

Use the backend flow when you want to verify the real local delivery shape,
not for the fastest authoring loop.

## Embed Into A Flutter Host App

Create or open a Flutter app, then run:

```powershell
flutter create my_mini_host
cd my_mini_host
miniprogram embed init
flutter pub get
```

The generated embed layer adds:

- `mini_program_sdk`
- `mini_program_contracts`
- app-owned bridge files under `lib/mini_program/`
- local backend runtime defaults
- Android release `INTERNET` permission for cloud/API delivery
- Android debug cleartext config for local HTTP preview/backend development

## Local Run Targets

With the local backend running on port `8080`, the generated runtime uses
target-aware defaults.

### Android emulator

```powershell
flutter run -d emulator-5554
```

Default local backend:

```text
http://10.0.2.2:8080/api/
```

### Windows desktop

```powershell
flutter run -d windows
```

Default local backend:

```text
http://127.0.0.1:8080/api/
```

### Chrome

```powershell
flutter run -d chrome
```

Default local backend:

```text
http://127.0.0.1:8080/api/
```

### Android physical device over USB

Start backend first so `adb reverse` can be applied:

```powershell
miniprogram backend start --port 8080
flutter run -d <android-device-id>
```

### Android or iPhone over Wi-Fi

Override the backend host with your machine LAN IP:

```powershell
flutter run -d <device-id> --dart-define=MINI_PROGRAM_BACKEND_HOST=<your-lan-ip>
```

Override the full URL when needed:

```powershell
flutter run -d <device-id> --dart-define=MINI_PROGRAM_BACKEND_BASE_URL=http://<host>:8080/api/
```

## Current Capability Boundary

The platform can support advanced business domains, but only with the right
bridge boundary.

### Good current direction

- payment flow UI
- banking workflow UI
- recharge UI
- TV business flows
- account and subscription flows

### Required rule

- portable UI stays in the mini-program
- sensitive execution stays native

Examples:

- payment SDK execution should stay native
- secure banking operations should stay native
- video playback core should stay native
- mini-program can orchestrate the user flow around them

## Native Host Expansion

Future native Android or other non-Flutter hosts should follow this path first:

- host app remains mostly native
- mini-program area uses embedded Flutter runtime
- one embedded runtime can support many mini-programs

This means:

- first integration cost is the main cost
- mini-program 2 to 100 mostly reuse the same runtime foundation
- native app size and memory increase
- but the whole native app does not degrade by a simple fixed percentage

For this platform type, that tradeoff is usually acceptable.

## Cloud Direction

The current first shipped cloud path is AWS-backed named environments through
the CLI:

```powershell
miniprogram env init
miniprogram env configure <env-name> --provider aws --bucket <unique-bucket-name> --region <aws-region> [--aws-profile <aws-profile>] [--cloudfront-base-url https://<cloudfront-domain>] [--api-base-url https://<api-domain>]
miniprogram env use <env-name>
miniprogram publish --target cloud
```

Replace the placeholder values before running that command. In particular:

- `<env-name>` should be something like `my-aws-prod`
- `<unique-bucket-name>` must be globally unique in S3
- `<aws-region>` should be a real AWS region such as `ap-south-1`
- `--cloudfront-base-url` and `--api-base-url` are optional and should only be
  supplied when you already have those URLs

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

Current cloud support in this phase:

- provider implementation shipped: `aws`
- planned next providers: `gcp`
- planned next providers: `custom-s3-compatible`

One cloud environment can serve many mini-programs. The recommended layout is
one bucket per environment, for example one production bucket and one staging
bucket, with many mini-program IDs inside it:

```text
artifacts/<mini-program-id>/<version>/manifest.json
artifacts/<mini-program-id>/<version>/screens/<screen-id>.json
artifacts/<mini-program-id>/<version>/assets/...
metadata/catalog/<mini-program-id>.json
metadata/releases/<mini-program-id>/<version>.json
```

The host app does not load directly from S3. It calls the deployed API Gateway
base URL, and the Lambda backend resolves the requested mini-program ID and
version from the bucket metadata.

AWS cloud setup guide:

- assume Windows + PowerShell
- assume region `ap-south-1`
- assume the goal is the fastest working path first
- normal developers using `mini_program_tooling` do not manually use the repo
  `infra/` folder; `miniprogram cloud deploy` already uses the bundled AWS
  backend template

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

Demo `lib/main.dart` for a host app:

```dart
import 'package:flutter/material.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'mini_program/mini_program.dart';

void main() {
  runApp(
    MiniProgramScope(
      config: buildMiniProgramConfig(),
      child: const MyHostApp(),
    ),
  );
}

class MyHostApp extends StatelessWidget {
  const MyHostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Mini Host',
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
      appBar: AppBar(title: const Text('Host App Home')),
      body: Center(
        child: FilledButton(
          onPressed: () {
            openAppMiniProgram(
              context,
              appId: 'my_coupon_app',
              title: 'My Coupon App',
            );
          },
          child: const Text('Open My Coupon App'),
        ),
      ),
    );
  }
}
```

Generated host-app structure:

- `pubspec.yaml` is updated with `mini_program_sdk` and
  `mini_program_contracts`
- `lib/mini_program/mini_program.dart` is the barrel import for app code
- `lib/mini_program/mini_program_launcher.dart` exposes
  `openAppMiniProgram(...)` and `AppMiniProgramLauncher`
- `lib/mini_program/mini_program_runtime_setup.dart` resolves
  `MINI_PROGRAM_BACKEND_BASE_URL` and builds `MiniProgramConfig`
- `lib/mini_program/app_host_bridge.dart` is where developers wire real
  analytics, native screens, and secure API behavior
- `lib/mini_program/mini_program_routes.dart` holds host-native route aliases
- `lib/main.dart` stays app-owned; edit it to add buttons, tabs, or menu items
  that call `openAppMiniProgram(...)`
- This package does not own your Flutter app. It only provides mini-program
  capability through `MiniProgramScope`. Your `MaterialApp`,
  `GetMaterialApp`, `MaterialApp.router`, GoRouter, theme, localization, state
  management, routes, and navigator setup remain fully yours.
- `MiniProgramConfig.sdkVersion` is the runtime compatibility version checked
  against manifest `sdkVersionRange`, not the `mini_program_sdk` pub package
  version.
- `MiniProgramConfig` is immutable for a `MiniProgramScope` state. Recreate the
  scope with a new key when switching environments.
- Android release builds need internet access to load cloud mini-programs.
  `miniprogram embed init` writes
  `android.permission.INTERNET` into `android/app/src/main/AndroidManifest.xml`
  for generated host apps. Debug builds also get local cleartext config for
  `http://10.0.2.2` and localhost backend testing.

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

The best long-term cloud model remains:

- `S3 + CloudFront` for versioned artifacts
  - manifests
  - screens
  - themes
  - assets
- `API Gateway + Lambda` for dynamic and secure routes
  - discovery
  - rollout and host-aware selection
  - capability filtering
  - secure operations

Public GitHub JSON URLs are okay for a simple public prototype, but not the
recommended real cloud delivery model.

## What Is Not The Right Direction

These are intentionally not the main path:

- replacing the CLI with a VS Code-only workflow
- treating WebView or WASM-in-app as the primary host model
- letting mini-program JSON execute sensitive native behavior directly
- assuming any arbitrary Flutter widget tree can become portable JSON

## Repo Smoke And Verification

Run repo smoke checks with:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\smoke_repo.ps1
```

Verify the installed global CLI with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify_global_cli.ps1
```

Use `miniprogram doctor` before troubleshooting:

```powershell
miniprogram doctor
```

## Additional Docs

- [mini_program_authoring.md](D:/flutter-mini-program-platform/docs/mini_program_authoring.md)
- [embed_existing_flutter_app.md](D:/flutter-mini-program-platform/docs/embed_existing_flutter_app.md)
- [packages/mini_program_tooling/README.md](D:/flutter-mini-program-platform/packages/mini_program_tooling/README.md)
- [packages/mini_program_sdk/README.md](D:/flutter-mini-program-platform/packages/mini_program_sdk/README.md)
- [nextWorkAgents.md](D:/flutter-mini-program-platform/nextWorkAgents.md)
