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
- optional per-mini-program access-key validation from S3 metadata
- backend-style error bodies, trace ids, and response headers

Not implemented yet in this stack:

- rollout rules
- capability filtering
- tenant-aware selection
- secure API execution
- CloudFront provisioning

## Prerequisites

- internet access from the developer machine to AWS endpoints
- AWS CLI installed and configured for the target account
- AWS SAM CLI installed
- Node.js 24 or newer installed
- an S3 bucket with versioning enabled
- mini-programs already published into that bucket through
  `miniprogram publish --target cloud`

The SAM template uses the AWS Lambda `nodejs24.x` runtime. Keep AWS SAM CLI
current enough to deploy `nodejs24.x` functions, and use Node.js 24 locally
when maintaining or testing this backend template.

If the developer machine cannot reach AWS at all, `miniprogram cloud deploy`
cannot work from that machine. In that case, keep using local preview/local
backend locally and run cloud deploy from another machine or CI runner that has
AWS network access and credentials.

## What The CLI Automates

For AWS, the normal workflow is now CLI-driven:

```powershell
miniprogram publish --target cloud
miniprogram cloud doctor
miniprogram cloud deploy
miniprogram cloud outputs
```

The CLI:

- publishes mini-program artifacts and metadata to S3
- generates a managed SAM project under `.mini_program/cloud/aws_backend`
- deploys or updates the API Gateway + Lambda stack
- persists the deployed `BackendApiBaseUrl` back into the configured named env

Developers do not normally need to open this `infra/` folder and run `sam`
manually. This folder is the source template that the CLI copies into the
managed project during deploy.

## What Still Stays Manual In AWS

These tasks still stay outside `miniprogram` and must be handled by the
developer or platform team:

- install and update `aws`, `sam`, and `node`
- connect the computer to AWS credentials
- create the S3 bucket
- enable S3 bucket versioning
- grant IAM permissions for S3 publish plus SAM/CloudFormation deploy
- optionally configure CloudFront, ACM, Route53, WAF, or custom domains

## Connect A Developer Computer To AWS

Recommended options:

### AWS SSO

```powershell
aws configure sso --profile my-sso
aws sso login --profile my-sso
aws sts get-caller-identity --profile my-sso
```

Then bind that profile into the miniprogram env:

```powershell
miniprogram env configure my-aws-prod --provider aws --bucket mehed-mini-program-prod-ap-south-1-20260418 --region ap-south-1 --aws-profile my-sso
```

### Access Key Profile

```powershell
aws configure --profile my-aws
aws sts get-caller-identity --profile my-aws
```

Then:

```powershell
miniprogram env configure my-aws-prod --provider aws --bucket mehed-mini-program-prod-ap-south-1-20260418 --region ap-south-1 --aws-profile my-aws
```

### Environment Variables

```powershell
$env:AWS_ACCESS_KEY_ID="..."
$env:AWS_SECRET_ACCESS_KEY="..."
$env:AWS_SESSION_TOKEN="..."   # only for temporary credentials
$env:AWS_REGION="ap-south-1"
aws sts get-caller-identity
```

When environment variables are used, `--aws-profile` is not required.

## One-Time AWS Setup

Create a globally unique bucket:

```powershell
aws s3api create-bucket --bucket mehed-mini-program-prod-ap-south-1-20260418 --region ap-south-1 --create-bucket-configuration LocationConstraint=ap-south-1
```

Enable versioning:

```powershell
aws s3api put-bucket-versioning --bucket mehed-mini-program-prod-ap-south-1-20260418 --versioning-configuration Status=Enabled --region ap-south-1
aws s3api get-bucket-versioning --bucket mehed-mini-program-prod-ap-south-1-20260418 --region ap-south-1
```

Initialize and select the named env:

```powershell
cd D:\my_coupon_app
miniprogram env init
miniprogram env configure my-aws-prod --provider aws --bucket mehed-mini-program-prod-ap-south-1-20260418 --region ap-south-1 --aws-profile my-sso
miniprogram env use my-aws-prod
```

## Minimum IAM Permissions

The developer or CI identity used for `miniprogram publish --target cloud` and
`miniprogram cloud deploy` needs, at minimum:

- S3 permissions for the publish bucket
  - `s3:ListBucket`
  - `s3:GetBucketLocation`
  - `s3:GetBucketVersioning`
  - `s3:GetObject`
  - `s3:PutObject`
  - `s3:DeleteObject`
  - `s3:AbortMultipartUpload`
- CloudFormation permissions
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
- Lambda permissions
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
- API Gateway permissions
  - `apigateway:GET`
  - `apigateway:POST`
  - `apigateway:PUT`
  - `apigateway:PATCH`
  - `apigateway:DELETE`
  - `apigateway:TagResource`
  - `apigateway:UntagResource`
- IAM permissions for the Lambda execution role
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

If the bucket uses SSE-KMS, add KMS permissions such as:

- `kms:Encrypt`
- `kms:Decrypt`
- `kms:GenerateDataKey`
- `kms:DescribeKey`

## Deploy

Recommended CLI-driven flow:

```powershell
cd D:\my_coupon_app
miniprogram publish --target cloud
miniprogram cloud doctor
miniprogram cloud deploy
miniprogram cloud outputs
```

Manual `sam build` / `sam deploy` remains available as a fallback:

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
sam deploy --stack-name mini-program-cloud-api-prod --region ap-south-1 --capabilities CAPABILITY_IAM --parameter-overrides ArtifactBucketName=mehed-mini-program-prod-ap-south-1-20260418 ArtifactsPrefix=artifacts MetadataPrefix=metadata StageName=prod RequireMiniProgramAccessKeys=true
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
- `RequireMiniProgramAccessKeys`
  - default `false` for compatibility
  - set to `true` when every protected mini-program route must have an access
    key policy under `metadata/access_keys/`

CLI-exposed AWS env options that influence deploy:

- `--aws-profile`
- `--stack-name`
- `--stage-name`
- `--sam-s3-bucket`
- `--function-timeout-seconds`
- `--function-memory-size`
- `--log-level`
- `--require-access-keys`

## MiniProgram Access Keys

For production partner delivery, create one or more MiniProgram access keys per
mini-program and store the allowed keys in S3:

```json
{
  "schemaVersion": 1,
  "miniProgramId": "my_coupon_app",
  "keys": [
    {
      "id": "company-a",
      "sha256": "SHA256_HEX_OF_ACCESS_KEY",
      "enabled": true
    },
    {
      "id": "company-b",
      "key": "mpk_live_plaintext_development_key",
      "enabled": true
    }
  ]
}
```

Upload it to:

```text
metadata/access_keys/my_coupon_app.json
```

The host app config keeps endpoint URLs and keys out of UI code:

```dart
MiniProgramEndpoint(
  apiBaseUri: Uri.parse('https://abc123.execute-api.ap-south-1.amazonaws.com/prod/api/'),
  accessKey: 'mpk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
)
```

The SDK sends the key as `X-Mini-Program-Access-Key` for manifest and screen
requests. To revoke one company without breaking others, disable or remove only
that company's key entry. SHA-256 key hashes are preferred for production
metadata; plaintext keys are accepted to keep local/manual setup simple.

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
miniprogram embed init
miniprogram embed cloud configure --env my-aws-prod
miniprogram host run -d chrome --env my-aws-prod
```

Equivalent manual run still works:

```powershell
flutter run -d windows --dart-define=MINI_PROGRAM_BACKEND_BASE_URL=https://abc123.execute-api.ap-south-1.amazonaws.com/prod/api/
```

## Recommended End-To-End Flow

1. Connect the developer machine to AWS through SSO, profile, or env vars.
2. Create the publish bucket and enable versioning.
3. Create and preview the mini-program locally.
4. Configure the named AWS env in `miniprogram`.
5. Publish it with `miniprogram publish --target cloud`.
6. Run `miniprogram cloud doctor`.
7. Deploy or update the backend with `miniprogram cloud deploy`.
8. Inspect the deployed URL with `miniprogram cloud outputs`.
9. Connect the Flutter host with `miniprogram embed cloud configure`.
10. Launch the host with `miniprogram host run`.

## Notes

- CloudFront is still the right long-term place for immutable public artifacts.
- This API currently reads directly from S3 because the host runtime already
  speaks the backend `/api/...` contract.
- If you later introduce rollout rules or secure routes, extend the Lambda
  contract instead of changing the Flutter host wire format.
