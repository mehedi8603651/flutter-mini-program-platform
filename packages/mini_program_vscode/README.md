# MiniProgram Tools

Native VS Code sidebar for MiniProgram CLI workflows.

This extension is a thin UI over the installed `miniprogram` CLI. It does not
reimplement create, build, validate, publish, preview, delivery, access-key,
partner package, host endpoint, or Publisher API logic.

## Requirements

Install or upgrade the CLI first:

```bash
dart pub global activate mini_program_tooling
```

This extension version targets `mini_program_tooling` 0.5.0 or newer.

Install from VS Code Marketplace:

- https://marketplace.visualstudio.com/items?itemName=MiniProgramTools.mini-program-tools

```bash
code --install-extension MiniProgramTools.mini-program-tools
```

## Backend Model

The extension follows the provider-neutral backend model:

- mini-program UI calls relative endpoints
- the host endpoint supplies an optional Publisher API base URL
- auth, database, payment, file storage, secret keys, admin logic, and business
  rules live on the publisher-owned middle server
- the middle server can run on AWS, Firebase, GCP, Docker, Kubernetes, a VPS, or
  any other provider

AWS cloud artifact hosting and Firebase Hosting remain static artifact hosting
tools. They are not exposed as publisher business backend command groups.

## Features

- Activity Bar view named `MiniProgram`.
- Local workflow status from `miniprogram workflow status --json`.
- Manual remote artifact status from `miniprogram workflow status --remote --json`.
- Core mini-program workflow:
  - `MiniProgram: Create MiniProgram`
  - `MiniProgram: Build`
  - `MiniProgram: Validate`
  - `MiniProgram: Preview`
  - `MiniProgram: Publish`
  - `MiniProgram: Publish Public Static MiniProgram`
  - `MiniProgram: Publish MiniProgram to Firebase Hosting`
- Environment and delivery:
  - `MiniProgram: Env Init`
  - `MiniProgram: Configure AWS Environment`
  - `MiniProgram: Configure Firebase Environment`
  - `MiniProgram: Use Environment`
  - `MiniProgram: Environment Status`
  - `MiniProgram: Cloud Deploy`
  - `MiniProgram: Cloud Status`
  - `MiniProgram: Cloud Outputs`
- Local development backend:
  - `MiniProgram: Setup Mock Publisher API`
  - `MiniProgram: Run Mock Publisher API`
  - `MiniProgram: Stop Mock Publisher API`
  - `MiniProgram: Mock Publisher API Status`
  - `MiniProgram: Copy Mock Publisher API URLs`
  - `MiniProgram: Copy Mock Backend Host Command`
- Provider-neutral Publisher API:
  - `MiniProgram: Publisher API Contract Init`
  - `MiniProgram: Publisher API Contract Validate`
  - `MiniProgram: Publisher API Contract Smoke`
  - `MiniProgram: Publisher API Contract Handoff`
- Host integration:
  - `MiniProgram: Embed Init`
  - `MiniProgram: Configure Host Cloud`
  - `MiniProgram: Import Host Endpoint`
  - `MiniProgram: Add Host Endpoint`
  - `MiniProgram: Run Host App`
  - `MiniProgram: Generate MiniProgram Registry`
  - `MiniProgram: Add MiniProgram to Registry`
  - `MiniProgram: Copy Demo Host Button`
- Access keys and partner packages:
  - `MiniProgram: Create Access Key`
  - `MiniProgram: List Access Keys`
  - `MiniProgram: Revoke Access Key`
  - `MiniProgram: Rotate Access Key`
  - `MiniProgram: Create Partner Package`
  - `MiniProgram: Validate Partner Package`
  - `MiniProgram: Open Partner Package`
- Diagnostics and guided flows:
  - `MiniProgram: Diagnose Workspace`
  - `MiniProgram: Diagnose MiniProgram`
  - `MiniProgram: Diagnose Host App`
  - `MiniProgram: Diagnose Cloud Artifact Hosting`
  - `MiniProgram: Setup New MiniProgram`
  - `MiniProgram: Publish MiniProgram to AWS`
  - `MiniProgram: Prepare Partner Handoff`
  - `MiniProgram: Setup Host App`
  - `MiniProgram: Add MiniProgram to Host`
  - `MiniProgram: Run Host Smoke Test`

## Removed Command Groups

The extension no longer contributes AWS/Firebase publisher business backend
commands. The old flows for AWS Lambda/DynamoDB and Firebase
Functions/Firestore were removed from the active model to avoid confusing
delivery infrastructure with the publisher middle server.

Use a real Publisher API instead:

```bash
miniprogram publisher-api contract init --backend-base-url https://api.publisher.example --public
miniprogram publisher-api contract validate
miniprogram publisher-api contract smoke
miniprogram publisher-api contract handoff --delivery-url https://cdn.example.com/app/ --public
```

## Local VSIX install

Use this only when testing an unreleased extension build locally.

```bash
cd packages/mini_program_vscode
npm install
npm run compile
npm run package:vsix
code --install-extension mini-program-tools-0.3.0.vsix
```

## Security Boundary

Mini-program JSON and partner packages should never contain provider
credentials, payment secrets, service account keys, database credentials, or
admin permissions. Public/static frontend data is fine. Sensitive logic belongs
on the publisher-owned HTTPS API.
