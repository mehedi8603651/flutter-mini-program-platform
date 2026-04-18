# mini_program_cloud_api

AWS SAM app that exposes the mini-program backend contract through:

- API Gateway HTTP API
- Lambda
- S3-backed published artifacts and metadata

This stack is designed to sit on top of the S3 layout produced by:

```powershell
miniprogram publish --target cloud
```

It does not replace cloud publish. It consumes the `artifacts/` and
`metadata/` objects that the CLI already uploads.

## What It Serves

The Lambda exposes the same backend-style routes the current Flutter hosts
already expect:

- `GET /health`
- `GET /api/discovery/mini-programs.json`
- `GET /api/manifests/<miniProgramId>/latest.json`
- `GET /api/manifests/<miniProgramId>/versions/<version>.json`
- `GET /api/screens/<miniProgramId>/<version>/<screenId>.json`
- `GET /api/debug/manifests/<miniProgramId>/decision.json`
- `POST /api/secure/...`
  - currently returns `501 not_implemented`

The route contract is intentionally aligned with the local backend so Flutter
hosts can switch between local and AWS using only
`MINI_PROGRAM_BACKEND_BASE_URL`.

## Current Scope

Implemented in this phase:

- S3-backed discovery catalog
- latest-manifest resolution from published catalog and release metadata
- versioned manifest and screen loading
- debug decision inspection
- backend-style error bodies, trace ids, and response headers

Not implemented yet in this stack:

- rollout rules
- capability filtering
- tenant-aware selection
- secure API execution
- CloudFront provisioning
- CLI-driven deployment of this SAM app

## Prerequisites

- AWS CLI configured for the target account
- AWS SAM CLI installed
- an S3 bucket with versioning enabled
- mini-programs already published into that bucket through
  `miniprogram publish --target cloud`

## Deploy

Example bucket and region:

- bucket: `mehed-mini-program-prod-ap-south-1-20260418`
- region: `ap-south-1`

Build:

```powershell
cd D:\flutter-mini-program-platform\infra\aws\mini_program_cloud_api
sam build
```

Deploy with explicit parameters:

```powershell
sam deploy --stack-name mini-program-cloud-api-prod --region ap-south-1 --capabilities CAPABILITY_IAM --parameter-overrides ArtifactBucketName=mehed-mini-program-prod-ap-south-1-20260418 ArtifactsPrefix=artifacts MetadataPrefix=metadata StageName=prod
```

You can also use guided deploy once:

```powershell
sam deploy --guided
```

Important parameters:

- `ArtifactBucketName`
  - S3 bucket that stores `artifacts/` and `metadata/`
- `ArtifactsPrefix`
  - default `artifacts`
- `MetadataPrefix`
  - default `metadata`
- `StageName`
  - default `prod`

## Outputs

The stack returns these useful outputs:

- `HttpApiStageUrl`
- `BackendApiBaseUrl`
- `HealthUrl`

`BackendApiBaseUrl` is the one your Flutter hosts should use, for example:

```text
https://abc123.execute-api.ap-south-1.amazonaws.com/prod/api/
```

## Test The Deployed API

Health:

```powershell
curl https://abc123.execute-api.ap-south-1.amazonaws.com/prod/health
```

Discovery:

```powershell
curl https://abc123.execute-api.ap-south-1.amazonaws.com/prod/api/discovery/mini-programs.json
```

Latest manifest:

```powershell
curl https://abc123.execute-api.ap-south-1.amazonaws.com/prod/api/manifests/my_coupon_app/latest.json
```

Screen:

```powershell
curl https://abc123.execute-api.ap-south-1.amazonaws.com/prod/api/screens/my_coupon_app/1.0.0/my_coupon_app_home.json
```

## Connect A Flutter Host

If you already embedded the runtime into a Flutter app:

```powershell
cd D:\my_mini_host
flutter run -d chrome --dart-define=MINI_PROGRAM_BACKEND_BASE_URL=https://abc123.execute-api.ap-south-1.amazonaws.com/prod/api/
```

Or on Windows desktop:

```powershell
flutter run -d windows --dart-define=MINI_PROGRAM_BACKEND_BASE_URL=https://abc123.execute-api.ap-south-1.amazonaws.com/prod/api/
```

## Recommended End-To-End Flow

1. Create and preview the mini-program locally.
2. Publish it with `miniprogram publish --target cloud`.
3. Deploy or update this SAM stack.
4. Copy `BackendApiBaseUrl` from the stack outputs.
5. Run the Flutter host app with `MINI_PROGRAM_BACKEND_BASE_URL=<output>`.

## Notes

- CloudFront is still the right long-term place for immutable public artifacts.
- This API currently reads directly from S3 because the host runtime already
  speaks the backend `/api/...` contract.
- If you later introduce rollout rules or secure routes, extend the Lambda
  contract instead of changing the Flutter host wire format.
