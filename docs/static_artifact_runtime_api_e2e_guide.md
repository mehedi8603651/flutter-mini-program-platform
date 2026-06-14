# Static Artifact And Runtime API E2E Guide

This guide verifies the MVP boundary:

- mini-program UI opens from public static artifacts using `appId` and `artifactBaseUrl`
- business data is optional runtime API behavior through a publisher-owned middle-server
- the host app does not need provider credentials, database config, payment config, secrets, or runtime API config to open the mini-program

## 1. Create And Build

```powershell
miniprogram create mp_static_e2e --output-root D:\mp_static_e2e --screen-format mp
miniprogram build --mini-program-root D:\mp_static_e2e
miniprogram validate --mini-program-root D:\mp_static_e2e
```

## 2. Optional Runtime API

Use the local mock Publisher API only when the mini-program needs dynamic data during preview or host testing:

```powershell
miniprogram publisher-api scaffold --template mock --mini-program-root D:\mp_static_e2e
miniprogram publisher-api run --mini-program-root D:\mp_static_e2e --port 9090
miniprogram publisher-api contract init --mini-program-root D:\mp_static_e2e --backend-base-url http://127.0.0.1:9090 --allow-local-http
miniprogram publisher-api contract validate --mini-program-root D:\mp_static_e2e --allow-local-http
miniprogram publisher-api contract smoke --mini-program-root D:\mp_static_e2e --allow-local-http
```

Publisher API Contract V1 is a runtime API standard only. It is not required for static artifact opening.

## 3. Publish Static Artifacts

```powershell
miniprogram publish --target static --mini-program-root D:\mp_static_e2e --output D:\mp_static_e2e\public_mini_program --clean
```

Serve `D:\mp_static_e2e\public_mini_program` from any simple public static file host. For local tests, any static HTTP server is enough.

## 4. Create Partner Package

```powershell
miniprogram partner package mp_static_e2e `
  --artifact-base-url https://static.example.com/mp_static_e2e/ `
  --output D:\mp_static_e2e\mp_static_e2e.partner.json
```

The package should contain only the operational opening fields: `appId`, `title`, and `artifactBaseUrl`, plus metadata.

## 5. Import Into Host

```powershell
flutter create D:\mp_static_host
miniprogram embed init --project-root D:\mp_static_host
miniprogram host endpoint import D:\mp_static_e2e\mp_static_e2e.partner.json --project-root D:\mp_static_host
miniprogram host run -d chrome --project-root D:\mp_static_host
```

Add an optional runtime API URL only when the mini-program uses `Mp.backend.call`, `Mp.backend.query`, `Mp.lazy.chunk`, search/load-more, form submit, or another runtime action that needs server data.

## 6. Status Checks

```powershell
miniprogram workflow status --workspace D:\mp_static_e2e --json
miniprogram workflow status --workspace D:\mp_static_host --json
```
