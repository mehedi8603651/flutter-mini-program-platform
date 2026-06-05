# Mp Engine Cloud End-To-End Guide

This guide verifies an Mp JSON mini-program through protected Firebase and AWS
delivery, publisher backends, partner handoff, and a real Flutter host.

Use it from the release branch before publishing the Mp packages.

## Architecture

Each cloud-hosted mini-program has two URLs:

- delivery API base URL: serves manifest, screen JSON, and assets
- publisher backend base URL: serves business data, auth, paging, and writes

A protected `.partner.json` handoff contains both URLs and one MiniProgram
access key. The host imports the package and sends the key with delivery and
publisher-backend requests. AWS can enforce the key on both services. Firebase
Hosting remains public static delivery, while the Firebase Functions publisher
backend enforces the key. Firebase credentials, AWS credentials, database
credentials, and publisher secrets never go to the host app.

## Local Branch Setup

Activate the branch tooling:

```powershell
dart pub global activate --source path D:\flutter-mini-program-platform-mp-engine\packages\mini_program_tooling
miniprogram capabilities --json
```

Confirm the CLI reports:

```text
mini_program_tooling 0.4.0
publisher_backend.aws.access_key_enforcement
```

New hosts use plain `embed init`; the generated runtime is Mp-only.

## Common Mp Publisher Checks

Run these before either cloud flow:

```powershell
miniprogram build --mini-program-root <mini-program-root>
miniprogram validate --mini-program-root <mini-program-root>
miniprogram workflow status --workspace <mini-program-root> --json
```

Expected workflow status:

```text
screenFormat: mp
screenSchemaVersion: 1
entryScreenExists: true
```

For a paged backend mini-program, also confirm backend/auth/paged usage is
reported and the source uses `Mp.pagedBackendBuilder(...)` with
`Mp.backend.loadMore(...)`.

## Firebase Flow With Protected Publisher Backend

For Firebase Console setup and Firebase-owned email auth, also read
[Firebase end-to-end guide](firebase_end_to_end_guide.md).

### 1. Scaffold And Configure

```powershell
miniprogram publisher-backend scaffold `
  --template firebase-functions `
  --storage firestore `
  --with-starter-ui `
  --mini-program-root <mini-program-root>

miniprogram env configure my-firebase-prod `
  --provider firebase `
  --project-id <firebase-project-id> `
  --region us-central1 `
  --function-name publisherBackend `
  --auth-web-api-key "<firebase-web-api-key>"
```

### 2. Deploy, Seed, And Publish

```powershell
miniprogram publisher-backend firebase deploy `
  --env my-firebase-prod `
  --mini-program-root <mini-program-root>

miniprogram publisher-backend firebase seed `
  --env my-firebase-prod `
  --mini-program-root <mini-program-root>

miniprogram publish `
  --target firebase-hosting `
  --env my-firebase-prod `
  --mini-program-root <mini-program-root> `
  --clean `
  --json
```

Use the reported `.web.app` URL as the delivery URL.

### 3. Create A Protected Handoff

Create one key per host company or integration. Save the raw key securely when
it is shown; it cannot be recovered later.

```powershell
miniprogram publisher-backend firebase access-key create `
  --env my-firebase-prod `
  --mini-program-root <mini-program-root> `
  --key-id company-a

miniprogram publisher-backend firebase smoke `
  --env my-firebase-prod `
  --mini-program-root <mini-program-root> `
  --access-key "<access-key-shown-once>"

miniprogram publisher-backend firebase handoff `
  --env my-firebase-prod `
  --mini-program-root <mini-program-root> `
  --delivery-url https://<firebase-project-id>.web.app/ `
  --access-key "<access-key-shown-once>" `
  --output <mini-program-root>\<app-id>.company-a.partner.json
```

Expected protected backend behavior:

```text
GET /health without key: 200
Protected route without key: 401
Protected route with invalid key: 403
Protected route with valid key: 200
```

## Protected AWS Flow

AWS uses:

- S3 plus the delivery API Gateway/Lambda stack for mini-program delivery
- a separate API Gateway/Lambda publisher backend for business data
- one S3 access-key policy shared by protected delivery and publisher backend

### 1. Configure Protected AWS Delivery

```powershell
miniprogram env configure my-aws-prod `
  --provider aws `
  --bucket <globally-unique-s3-bucket> `
  --region <aws-region> `
  --aws-profile <aws-profile> `
  --require-access-keys

miniprogram env use my-aws-prod
miniprogram cloud doctor --env my-aws-prod
```

### 2. Publish Delivery And Deploy Publisher Backend

```powershell
miniprogram publish `
  --target cloud `
  --env my-aws-prod `
  --mini-program-root <mini-program-root>

miniprogram cloud deploy --env my-aws-prod
miniprogram cloud outputs --env my-aws-prod

miniprogram publisher-backend scaffold `
  --template aws-lambda `
  --storage dynamodb `
  --mini-program-root <mini-program-root>

miniprogram publisher-backend aws deploy `
  --env my-aws-prod `
  --mini-program-root <mini-program-root>

miniprogram publisher-backend aws seed `
  --env my-aws-prod `
  --mini-program-root <mini-program-root>

miniprogram publisher-backend aws outputs `
  --env my-aws-prod `
  --mini-program-root <mini-program-root> `
  --json
```

The generated AWS publisher backend reads the exact access-key policy object
for the mini-program. `GET /health` remains public. Other publisher backend
routes enforce the key when the policy exists.

### 3. Create A Protected AWS Handoff

```powershell
miniprogram access-key create <app-id> `
  --key-id company-a `
  --env my-aws-prod

miniprogram publisher-backend aws smoke `
  --env my-aws-prod `
  --mini-program-root <mini-program-root> `
  --access-key "<access-key-shown-once>" `
  --json

miniprogram partner package <app-id> `
  --title "<title>" `
  --api-base-url "<delivery-api-base-url>" `
  --backend-base-url "<publisher-backend-base-url>" `
  --access-key "<access-key-shown-once>" `
  --env my-aws-prod `
  --output <mini-program-root>\<app-id>.company-a.partner.json
```

The AWS smoke JSON reports only `accessKeyProvided: true`; it must never print
the raw key.

Expected security matrix:

```text
GET /health without key: 200
GET /home/bootstrap without key: 401
GET /home/bootstrap with invalid key: 403
GET /home/bootstrap with valid key: 200
```

## Provider-Neutral Host Flow

The host developer receives only the `.partner.json` package:

```powershell
flutter create <host-root>

miniprogram embed init --project-root <host-root>

miniprogram host endpoint import `
  <partner-package.json> `
  --project-root <host-root>

cd <host-root>
flutter pub get
flutter analyze
flutter test
```

The host app must wrap its app with the generated endpoint configuration:

```dart
MiniProgramScope(
  config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),
  child: const MyApp(),
)
```

Open the mini-program by app id:

```dart
openAppMiniProgram(
  context,
  appId: '<app-id>',
  title: '<title>',
);
```

Run the same imported handoff on each required platform:

```powershell
flutter run -d chrome
flutter run -d windows
flutter devices
flutter run -d <physical-android-device-id>
```

Verify:

- entry screen renders
- protected publisher backend data loads
- image assets load
- auth UI works when used
- every Load more page appends without replacing earlier items
- no access key or auth token appears in logs

## Secret Handling

- Never commit `.partner.json` files containing protected access keys.
- Never paste raw access keys into issues, logs, screenshots, or test output.
- Use one key per partner.
- Rotate or revoke a partner key without changing the app id.
- Keep Firebase Web API keys, AWS credentials, and database credentials out of
  mini-program JSON and host source.

## Release Verification

Run the repository verification script:

```powershell
powershell -ExecutionPolicy Bypass -File tools\verify_mp_engine_release.ps1
```

Then complete the live provider and platform gates in
[Mp engine release checklist](mp_engine_release_checklist.md).
