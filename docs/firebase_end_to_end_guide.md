# Firebase End-To-End Guide

This guide is for a new mini-program publisher who wants to use Firebase for:

- Firebase Functions publisher backend
- Firestore business data
- publisher-owned email/password auth
- Firebase Hosting static mini-program delivery
- protected host handoff with MiniProgram access keys

It also shows what the host app developer receives and how they connect the
mini-program without Firebase project access.

New Mp JSON projects should also use the
[Mp engine cloud end-to-end guide](mp_engine_cloud_e2e_guide.md). The commands
remain provider-neutral, but Mp source lives under `mp/` instead of `stac/`.

## Team Split

The mini-program publisher owns:

- Firebase project and Firebase CLI login
- Functions deploys
- Firestore seed/data
- Firebase Auth setup
- Firebase Hosting static delivery
- MiniProgram access keys
- `.partner.json` handoff packages

The host app developer owns:

- Flutter host app
- `mini_program_sdk` dependency
- MiniProgram endpoint import
- native host app UI that opens the mini-program

The host app developer does not need Firebase CLI login, Firebase console
access, Firebase SDK setup, Firebase Web API keys, service accounts, or
publisher backend secrets.

## Required Versions

Install current tooling and extension:

```powershell
dart pub global activate mini_program_tooling
code --install-extension MiniProgramTools.mini-program-tools
```

Recommended minimum versions:

- `mini_program_tooling` 0.3.49 or newer
- `mini_program_vscode` 0.1.38 or newer
- `mini_program_sdk` 0.3.7 or newer in host apps

Check the CLI:

```powershell
miniprogram capabilities --json
```

Confirm it reports `publisher_backend.firebase.starter_ui`.
For paged backend starter routes, also confirm it reports
`publisher_backend.firebase.paged_routes`.

## Firebase Console Setup

Create or open a Firebase project.

Required Firebase project setup:

1. Upgrade to Blaze. Cloud Functions deploy requires Blaze.
2. Open **Firestore Database** and create a database.
3. Open **Authentication -> Sign-in method** and enable **Email/Password**.
4. Open **Hosting and serverless -> Functions** to see deployed Functions.
5. Open **Hosting and serverless -> Hosting** to see Hosting releases/domains.

Firebase Hosting usually gives two default domains:

```text
https://<project-id>.web.app/
https://<project-id>.firebaseapp.com/
```

Use the `.web.app` URL as the normal MiniProgram delivery URL.

Get the Firebase Web API key from:

```text
Project settings -> General -> Your apps -> Web app -> apiKey
```

This key is used by the publisher backend to call Firebase Auth REST APIs. CLI
output redacts it, and handoff packages do not include it.

## Publisher Flow In VS Code

Open a mini-program workspace, for example:

```powershell
code D:\firebase_full_demo
```

If you do not have one yet, run:

```text
MiniProgram: Create MiniProgram
```

Choose **Mp JSON** for a new mini-program.

### 1. Generate Firebase Backend And Starter UI

Run:

```text
MiniProgram: Setup Publisher Backend
```

Choose:

```text
Firebase Functions + Firestore
Add Firebase starter UI
Normal
```

This creates:

```text
backend/firebase_functions/
backend/firebase_functions/functions/data/home_bootstrap.json
backend/firebase_functions/functions/data/coupons_list.json
backend/firebase_functions/functions/data/session.json
mp/program.dart
mp/screens/<appId>_home.dart
tool/build_mp.dart
```

For an existing Firebase backend, run:

```text
MiniProgram: Add Firebase Starter UI
```

Choose **Add safely** unless you intentionally want to overwrite generated
starter files.

### 2. Configure Firebase Environment

Run:

```text
MiniProgram: Configure Firebase Environment
```

Use values like:

```text
Environment: my-firebase-prod
Project ID: <firebase-project-id>
Region: us-central1
Function name: publisherBackend
Auth Web API key: <firebase-web-api-key>
```

Terminal equivalent:

```powershell
miniprogram env configure my-firebase-prod `
  --provider firebase `
  --project-id <firebase-project-id> `
  --region us-central1 `
  --function-name publisherBackend `
  --auth-web-api-key "<firebase-web-api-key>"
```

### 3. Edit UI And Backend Seed Data

Edit portable UI:

```text
mp/screens/<appId>_home.dart
```

Edit Firestore seed source data:

```text
backend/firebase_functions/functions/data/home_bootstrap.json
backend/firebase_functions/functions/data/coupons_list.json
backend/firebase_functions/functions/data/session.json
```

Use the generated starter as the production-shaped example:

- `Mp.backendBuilder(...)` loads publisher backend data.
- `Mp.pagedBackendBuilder(...)` loads large backend lists from `coupons/page`
  and uses `Mp.backend.loadMore(...)` for manual paging.
- `Mp.authBuilder(...)` renders signed-out, signed-in, loading, and error
  states.
- `Mp.auth.*` actions open the SDK email/password sheet, restore cached login,
  refresh sessions, and sign out.

Do not edit `mp/.build`; it is generated.

### 4. Deploy Backend

Before deploy, make sure Firebase CLI login is valid:

```powershell
firebase login:list
```

If deploy says credentials are invalid:

```powershell
firebase login --reauth
```

Then run:

```text
MiniProgram: Deploy Publisher Backend to Firebase
```

Expected deploy indicators:

```text
Healthy: true
Health status: 200
PublisherBackendFirebaseAuthEmail: configured
```

### 5. Seed Firestore

Run:

```text
MiniProgram: Seed Firebase Publisher Firestore
```

Expected output includes records like:

```text
Seeded: true
Home records: 1
Coupons: 3
Items written: 5
```

### 6. Smoke Test

Run:

```text
MiniProgram: Smoke Test Firebase Publisher Backend
```

Before you create access keys, choose:

```text
Run without access key
```

Expected public smoke:

```text
GET /health: 200 OK
GET /home/bootstrap: 200 OK
GET /coupons/list: 200 OK
GET /auth/session: 401 OK (auth_required)
Passed: true
```

`/auth/session` returning `401 auth_required` is correct when no user is signed
in.

For auth verification, run auth smoke from terminal with a test user:

```powershell
miniprogram publisher-backend firebase smoke `
  --env my-firebase-prod `
  --mini-program-root D:\firebase_full_demo `
  --include-auth `
  --auth-email test@example.com `
  --auth-password "test-password" `
  --auth-create-user
```

### 7. Check Auth Readiness

Run:

```text
MiniProgram: Firebase Publisher Auth Status
```

Use this when login UI appears but auth calls fail. It checks:

- env auth Web API key
- generated auth routes
- CORS `Authorization` header
- Functions `.env`
- Firebase Admin dependency
- host auth controller readiness when a host root is provided

### 8. Publish Static Delivery To Firebase Hosting

Run:

```text
MiniProgram: Publish MiniProgram to Firebase Hosting
```

When asked for output folder, use:

```text
backend/firebase_hosting/public
```

Choose deploy.

Expected output includes:

```text
Delivery API base URL: https://<project-id>.web.app/
Firebase Hosting manifest reachable: yes
Firebase Hosting CORS ready: yes
```

That `Delivery API base URL` is the URL to use in handoff packages.

### 9. Create Protected Handoff Package

Run:

```text
MiniProgram: Create Firebase Host Handoff Package
```

For real partner/host app work, choose protected mode and create a new access
key. Use a key id that names the host company or integration:

```text
company-a
company-b
```

The extension creates a Firebase publisher access key, copies the raw key once,
and writes a handoff file like:

```text
<appId>-my-firebase-prod-company-a.partner.json
```

Send this `.partner.json` file to the host app developer. It contains:

- app id
- title
- Firebase Hosting delivery URL
- Firebase Functions backend URL
- access mode
- MiniProgram access key for protected publisher backend calls

It does not contain Firebase credentials, Firebase Web API keys, Firebase
service accounts, or publisher backend secrets.

## Host App Flow In VS Code

Open or create the Flutter host app:

```powershell
flutter create D:\firebase_full_host
code D:\firebase_full_host
```

Run:

```text
MiniProgram: Embed Init
```

Choose:

```text
Clean adapter only
```

Then run:

```text
MiniProgram: Import Host Endpoint
```

Select the `.partner.json` file from the publisher.

For a new host app, tooling adds the configured SDK/contracts versions and the
runtime setup files. If needed, run:

```powershell
flutter pub get
```

In `main.dart`, wrap the app with the generated endpoint config:

```dart
MiniProgramScope(
  config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),
  child: const MyApp(),
)
```

Open by app id from host UI:

```dart
openAppMiniProgram(
  context,
  appId: '<appId>',
  title: '<MiniProgram title>',
);
```

Run:

```text
MiniProgram: Diagnose Host App
MiniProgram: Run Host App
```

Or terminal:

```powershell
flutter run -d chrome
flutter run -d emulator-5554
```

The host app should load the Firebase Hosting manifest/screens, call the
Firebase Functions publisher backend, send the access key on protected backend
calls, and show SDK email/password auth UI when the mini-program asks for it.

## CLI-Only Command Sequence

Publisher:

```powershell
miniprogram create firebase_full_demo --output-root D:\firebase_full_demo --title "Firebase Full Demo"

miniprogram publisher-backend scaffold `
  --template firebase-functions `
  --storage firestore `
  --with-starter-ui `
  --mini-program-root D:\firebase_full_demo

miniprogram env configure my-firebase-prod `
  --provider firebase `
  --project-id <firebase-project-id> `
  --region us-central1 `
  --function-name publisherBackend `
  --auth-web-api-key "<firebase-web-api-key>"

miniprogram build --mini-program-root D:\firebase_full_demo
miniprogram publisher-backend firebase deploy --env my-firebase-prod --mini-program-root D:\firebase_full_demo
miniprogram publisher-backend firebase seed --env my-firebase-prod --mini-program-root D:\firebase_full_demo
miniprogram publisher-backend firebase smoke --env my-firebase-prod --mini-program-root D:\firebase_full_demo
miniprogram publisher-backend firebase auth status --env my-firebase-prod --mini-program-root D:\firebase_full_demo

miniprogram publish `
  --target firebase-hosting `
  --env my-firebase-prod `
  --mini-program-root D:\firebase_full_demo `
  --output D:\firebase_full_demo\backend\firebase_hosting\public `
  --clean

miniprogram publisher-backend firebase access-key create `
  --env my-firebase-prod `
  --mini-program-root D:\firebase_full_demo `
  --key-id company-a

miniprogram publisher-backend firebase handoff `
  --env my-firebase-prod `
  --mini-program-root D:\firebase_full_demo `
  --delivery-url https://<firebase-project-id>.web.app/ `
  --access-key "<access-key-shown-once>" `
  --output D:\firebase_full_demo\firebase_full_demo-my-firebase-prod-company-a.partner.json
```

Host:

```powershell
flutter create D:\firebase_full_host
cd D:\firebase_full_host
miniprogram embed init
miniprogram host endpoint import D:\firebase_full_demo\firebase_full_demo-my-firebase-prod-company-a.partner.json --project-root D:\firebase_full_host
flutter pub get
flutter run -d chrome
```

## Troubleshooting

### VS Code does not show "Add Firebase starter UI"

Check extension version:

```powershell
code --list-extensions --show-versions | Select-String mini-program-tools
```

Install the latest extension and reload VS Code:

```powershell
code --install-extension MiniProgramTools.mini-program-tools --force
```

Also confirm CLI support:

```powershell
miniprogram capabilities --json
```

### Firebase deploy says credentials are invalid

Run:

```powershell
firebase login --reauth
```

If browser login fails:

```powershell
firebase logout
firebase login --no-localhost
```

### Firebase Hosting shows two domains

Both work:

```text
https://<project-id>.web.app/
https://<project-id>.firebaseapp.com/
```

Use `.web.app` consistently in handoff packages.

### Smoke test fails after creating access keys

When active Firebase publisher access keys exist, protected publisher backend
routes require the access key. In VS Code smoke, choose:

```text
Enter Firebase access key
```

For terminal smoke:

```powershell
miniprogram publisher-backend firebase smoke `
  --env my-firebase-prod `
  --mini-program-root D:\firebase_full_demo `
  --access-key "<access-key>"
```

### Host app says access key is required

The host imported a public endpoint while the publisher backend has active
access keys, or the endpoint is not configured to send the access key to the
backend. Create a protected handoff package and import that package again.

### Static files are public

Firebase Hosting static mini-program files are public by design. The protected
data boundary is the Firebase Functions publisher backend, enforced by
MiniProgram access keys and user auth. For production, set Firebase budget
alerts and consider custom rate limiting or Firebase/App Check style hardening
for high-risk public endpoints.
