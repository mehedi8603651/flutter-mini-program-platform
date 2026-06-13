# Mp Engine Cloud E2E Guide

This guide verifies the active static artifact hosting + Publisher API model:

- AWS static artifact hosting for manifests, screens, assets, and access-key
  protected artifact access
- Firebase Hosting as static artifact hosting only
- provider-neutral Publisher API contract, smoke, and handoff
- Flutter host endpoint import and runtime smoke

It does not deploy AWS Lambda/DynamoDB or Firebase Functions/Firestore as
publisher business backends. Those provider choices belong behind the
publisher-owned HTTPS API.

## 1. Create And Validate A Mini-Program

```powershell
miniprogram create mp_cloud_e2e --output-root D:\mp_cloud_e2e --screen-format mp
miniprogram build --mini-program-root D:\mp_cloud_e2e
miniprogram validate --mini-program-root D:\mp_cloud_e2e
```

Use `Mp.lazy.chunk(...)` for repeated large backend data. Use normal static
widgets or detail builders for small/static/detail screens.

## 2. Run Local Mock Publisher API

```powershell
miniprogram publisher-backend scaffold --template mock --mini-program-root D:\mp_cloud_e2e
miniprogram publisher-backend run --mini-program-root D:\mp_cloud_e2e --port 9090
miniprogram publisher-backend urls --port 9090
```

The mock confirms local frontend-to-Publisher-API wiring. Production work
should use a real middle server.

## 3. Verify Publisher API Contract

For a local mock:

```powershell
miniprogram publisher-api contract init `
  --mini-program-root D:\mp_cloud_e2e `
  --backend-base-url http://127.0.0.1:9090 `
  --allow-local-http `
  --public

miniprogram publisher-api contract validate --mini-program-root D:\mp_cloud_e2e --allow-local-http
miniprogram publisher-api contract smoke --mini-program-root D:\mp_cloud_e2e --allow-local-http
```

For a real API, use HTTPS:

```powershell
miniprogram publisher-api contract init `
  --mini-program-root D:\mp_cloud_e2e `
  --backend-base-url https://api.publisher.example `
  --public
```

## 4. Static Or Firebase Artifact Hosting

```powershell
miniprogram publish --target static --mini-program-root D:\mp_cloud_e2e --output D:\mp_cloud_e2e\public_mini_program --clean
```

Firebase Hosting:

```powershell
miniprogram env configure firebase-prod --provider firebase --project-id <project-id>
miniprogram publish --target firebase-hosting --env firebase-prod --mini-program-root D:\mp_cloud_e2e --clean
```

## 5. AWS Static Artifact Hosting

```powershell
miniprogram env configure aws-prod `
  --provider aws `
  --bucket <unique-bucket> `
  --region <aws-region> `
  --require-access-keys

miniprogram cloud deploy --env aws-prod
miniprogram publish --target cloud --env aws-prod --mini-program-root D:\mp_cloud_e2e
miniprogram cloud outputs --env aws-prod
```

This AWS stack is static artifact hosting infrastructure. It is not the
publisher business backend.

## 6. Handoff And Host Smoke

```powershell
miniprogram publisher-api contract handoff `
  --mini-program-root D:\mp_cloud_e2e `
  --delivery-url https://cdn.example.com/mp_cloud_e2e/ `
  --public `
  --output D:\mp_cloud_e2e\mp_cloud_e2e.partner.json

flutter create D:\mp_cloud_host
miniprogram embed init --project-root D:\mp_cloud_host
miniprogram host endpoint import D:\mp_cloud_e2e\mp_cloud_e2e.partner.json --project-root D:\mp_cloud_host
miniprogram host run -d chrome --project-root D:\mp_cloud_host
```

## Verification

Run:

```powershell
miniprogram workflow status --workspace D:\mp_cloud_e2e --json
miniprogram workflow status --workspace D:\mp_cloud_host --json
```

Expected result:

- mini-program build and validation are ready
- host endpoint import is ready
- delivery URL points at the selected delivery target
- optional Publisher API base URL points at the middle server
- no provider credentials or backend secrets appear in mini-program JSON,
  endpoint maps, partner packages, or logs
