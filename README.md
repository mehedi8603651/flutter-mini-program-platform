# Flutter Mini Program Platform

The platform uses static frontend artifact delivery for mini-program UI bundles, and a separate provider-neutral Publisher API backend for business logic and dynamic data.

Mini-program frontend artifacts are public static files. A host opens a mini-program with:

- `appId`
- `artifactBaseUrl`

The host fetches the current manifest and screen/static artifacts from `artifactBaseUrl`. Version selection, if any, belongs to the artifact host or publisher process, not host backend config.

Runtime business behavior is optional. When a mini-program needs dynamic data or user actions, it calls a publisher-owned HTTPS middle-server through runtime APIs such as `Mp.backend.call`, `Mp.backend.query`, `Mp.lazy.chunk`, search/load-more, and form submit. That middle-server owns auth, database access, payments, files, secrets, external APIs, admin logic, and business rules.

## Packages

- `mini_program_ui`: pure Dart authoring API for Mp JSON screens.
- `mini_program_contracts`: shared manifests, action contracts, and Publisher API runtime contract models.
- `mini_program_sdk`: Flutter runtime renderer, artifact loading, optional runtime API connector, cache, auth/session helpers, and host integration APIs.
- `mini_program_tooling`: CLI for create/build/validate/preview/static publish, partner packages, host endpoint import, local mock Publisher API, and workflow status.
- `mini_program_vscode`: VS Code helper extension for the same workflows.

## Install

Install the published CLI:

```powershell
dart pub global activate mini_program_tooling
miniprogram doctor
miniprogram --help
```

On Windows, make sure the Dart pub global bin folder is available on `PATH`:

```powershell
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
```

The VS Code Marketplace extension uses the same CLI. Configure `miniProgram.cliPath` only when `miniprogram` is not available on `PATH`.

## Current Flow

For the beginner static-only path, start with
[Quickstart: static mini-program to host app](docs/quickstart_static_miniprogram_to_host.md).

```powershell
miniprogram create coupon_demo --screen-format mp
miniprogram build --mini-program-root .\coupon_demo
miniprogram validate --mini-program-root .\coupon_demo
miniprogram artifact build --mini-program-root .\coupon_demo
miniprogram artifact verify --mini-program-root .\coupon_demo
```

Copy `coupon_demo/artifacts` to any public static file host. Building the same
version with different content is rejected; update the manifest version for a
new release.

Create a partner package for a host app:

```powershell
miniprogram partner package coupon_demo `
  --artifact-base-url https://static.example.com/coupon_demo/ `
  --output .\coupon_demo\coupon_demo.partner.json
```

Import it into a Flutter host:

```powershell
flutter create .\coupon_host
miniprogram embed init --project-root .\coupon_host
miniprogram host endpoint import .\coupon_demo\coupon_demo.partner.json --project-root .\coupon_host
miniprogram host run -d chrome --project-root .\coupon_host
```

## Optional Runtime API

Publisher API Contract V1 is a runtime API standard only; host opening still uses `appId + artifactBaseUrl`.

For local runtime API testing:

```powershell
miniprogram publisher-api scaffold --template mock --mini-program-root .\coupon_demo
miniprogram publisher-api run --mini-program-root .\coupon_demo --port 9090
miniprogram publisher-api contract init --mini-program-root .\coupon_demo --publisher-api-url http://127.0.0.1:9090 --permission-reason "Load coupon offers." --allow-local-http
miniprogram publisher-api contract validate --mini-program-root .\coupon_demo --allow-local-http
miniprogram publisher-api contract smoke --mini-program-root .\coupon_demo --allow-local-http
miniprogram artifact build --mini-program-root .\coupon_demo
```

Use a real publisher middle-server in production. It can be written in any language or framework, as long as it exposes the agreed HTTPS API.

The contract is packaged inside the immutable artifact. A partner handoff made
from the mini-program root requests Publisher API permission, and the host can
accept it explicitly:

```powershell
miniprogram partner package coupon_demo `
  --artifact-base-url https://static.example.com/coupon_demo/ `
  --mini-program-root .\coupon_demo `
  --output .\coupon_demo\coupon_demo.partner.json

miniprogram host endpoint import .\coupon_demo\coupon_demo.partner.json `
  --project-root .\coupon_host `
  --accept-requested-policy
```

The host stores only the accepted `publisherApi.enabled` decision in
`lib/mini_program/mini_program_policies.json`. It does not duplicate or
override the publisher URL.

Recommended runtime response shapes:

```json
{ "data": { "ok": true }, "traceId": "trace-success" }
```

```json
{ "items": [], "nextCursor": null, "hasMore": false, "traceId": "trace-page" }
```

```json
{ "errorCode": "validation_failed", "message": "Validation failed", "traceId": "trace-error" }
```

## Architecture Rules

- Mini-program artifacts are public static UI bundles.
- Opening a mini-program must not require backend URLs, auth, database config, payment config, secrets, provider SDKs, or runtime API config.
- Runtime API URLs are optional and only used by runtime actions.
- Sensitive data and business logic stay behind the publisher middle-server.
- `mini_program_ui` remains core Dart only.
- `mini_program_sdk` remains provider-neutral.

## Docs

- [Quickstart: static mini-program to host app](docs/quickstart_static_miniprogram_to_host.md)
- [Track 2: middle-server API with Lambda, DynamoDB, and JWT](docs/middle_server_api_lambda_dynamodb.md)
- [Mini-program authoring](docs/mini_program_authoring.md)
- [Static artifact and runtime API E2E guide](docs/static_artifact_runtime_api_e2e_guide.md)
- [Publisher API runtime contract roadmap](docs/publisher_backend_https_api_roadmap.md)
- [Embedding an existing Flutter app](docs/embed_existing_flutter_app.md)
