# mini_program_tooling

Developer tooling for the portable Flutter mini-program platform.

The `miniprogram` CLI creates, builds, validates, previews, publishes, and
hands off mini-programs. Backend integration is provider-neutral: a
mini-program may call a publisher-owned HTTPS API, but AWS/Firebase database,
auth, payment, file storage, admin logic, and secrets stay behind that middle
server.

## Install

Released package:

```bash
dart pub global activate mini_program_tooling
```

Repo-local contributor install:

```bash
dart pub global activate --source path <repo-root>/packages/mini_program_tooling
```

## Backend Model

Use a Publisher API / external HTTPS API for business backend work:

- auth
- database
- payment
- file storage
- business rules
- secret keys
- admin logic

The mini-program uses relative endpoints through `Mp.backend.*`,
`Mp.backendBuilder`, `Mp.pagedBackendBuilder`, and `Mp.lazy.chunk`. The host
endpoint supplies the Publisher API base URL. The implementation behind that URL
can run on AWS, Firebase, GCP, Docker, Kubernetes, a VPS, or any provider.

AWS cloud artifact hosting and Firebase Hosting are static artifact hosting
systems only. They publish or serve manifests, screens, assets, static JSON, and
optional MiniProgram access keys. They are not the publisher business backend
model.

## CLI Surface

```text
miniprogram create <mini-program-id> [--screen-format mp] [--with-backend mock]
miniprogram capabilities [--json]
miniprogram doctor [--json]

miniprogram env init
miniprogram env configure <env-name> --provider aws --bucket <bucket> --region <region> [--aws-profile <profile>] [--require-access-keys]
miniprogram env configure <env-name> --provider firebase --project-id <firebase-project-id>
miniprogram env list
miniprogram env use <local|env-name>
miniprogram env status [--json]

miniprogram build [mini-program-id] [--mp-build-script <path>]
miniprogram preview -d <device> [mini-program-id] [--mp-build-script <path>]
miniprogram validate [mini-program-id]
miniprogram publish [mini-program-id] [--target local|cloud|static|firebase-hosting] [--env <env-name>] [--output <folder>] [--clean] [--site <firebase-hosting-site>] [--dry-run] [--json]

miniprogram publisher-backend scaffold --template mock [--mini-program-root <path>] [--force]
miniprogram publisher-backend run [--mini-program-root <path>] [--port 9090]
miniprogram publisher-backend status [--mini-program-root <path>] [--json]
miniprogram publisher-backend stop [--mini-program-root <path>]
miniprogram publisher-backend urls [--port 9090]

miniprogram publisher-api contract init --backend-base-url <url> [--mini-program-root <path>] [--public] [--allow-local-http]
miniprogram publisher-api contract validate [--mini-program-root <path>] [--contract <file>] [--allow-local-http] [--json]
miniprogram publisher-api contract smoke [--mini-program-root <path>] [--contract <file>] [--access-key <key>] [--auth-token <token>] [--allow-local-http] [--json]
miniprogram publisher-api contract handoff --delivery-url <url> [--mini-program-root <path>] [--contract <file>] (--access-key <key>|--public) [--output <file>] [--allow-local-http] [--json]

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

miniprogram partner package <mini-program-id> (--access-key <key>|--public) [--api-base-url <url>|--env <env-name>] [--backend-base-url <url>] [--output <file>]
miniprogram host endpoint add <mini-program-id> --title <title> --api-base-url <url> (--access-key <key>|--public) [--backend-base-url <url>|--backend-local-mock]
miniprogram host endpoint import <partner-package.json>
miniprogram host run -d <device> [--env <env-name>]
miniprogram embed init [--project-root <path>] [--force]
miniprogram embed cloud configure [--env <env-name>]

miniprogram backend init
miniprogram backend start --port 8080
miniprogram backend stop
miniprogram backend status [--json]
miniprogram backend reset-local --yes
miniprogram workflow status [--workspace <path>] [--env <env-name>] [--remote] [--json]
```

`publisher-backend` remains the local mock API group. `publisher-api` is the
preferred visible wording for contract, smoke, and handoff.

## Removed Provider Backend Templates

The CLI no longer scaffolds or manages AWS Lambda/DynamoDB or Firebase
Functions/Firestore publisher business backends.

These commands intentionally fail with a migration message:

```bash
miniprogram publisher-backend scaffold --template aws-lambda
miniprogram publisher-backend scaffold --template firebase-functions
miniprogram publisher-backend scaffold --storage dynamodb
miniprogram publisher-backend scaffold --storage firestore
```

Use your own middle server instead, then connect it:

```bash
miniprogram publisher-api contract init --backend-base-url https://api.publisher.example --public
miniprogram publisher-api contract validate
miniprogram publisher-api contract smoke
miniprogram publisher-api contract handoff --delivery-url https://cdn.example.com/app/ --public
```

## Local Mock Publisher API

Use the mock API when frontend work needs repeated or dynamic backend-shaped
data before the real middle server exists:

```bash
miniprogram publisher-backend scaffold --template mock
miniprogram publisher-backend run --port 9090
miniprogram publisher-backend urls
```

The mock is a development tool. Production storage, auth, payment, files, and
business logic belong on the publisher-owned HTTPS API.

## Static Artifact Delivery

Local/static delivery writes public files for local testing or any CDN/static
host:

```bash
miniprogram publish --target static --output public_mini_program --clean
```

AWS static artifact hosting serves mini-program manifests, screen JSON, assets,
and access-key protected artifact access through the platform artifact stack:

```bash
miniprogram env configure prod --provider aws --bucket <bucket> --region <region>
miniprogram cloud deploy --env prod
miniprogram publish --target cloud --env prod
```

Firebase Hosting is static delivery only:

```bash
miniprogram env configure firebase-prod --provider firebase --project-id <project-id>
miniprogram publish --target firebase-hosting --env firebase-prod --clean
```

## Handoff

A host app should receive a small partner package, not backend secrets:

```bash
miniprogram publisher-api contract handoff \
  --delivery-url https://cdn.example.com/app/ \
  --public \
  --output app.partner.json

miniprogram host endpoint import app.partner.json --project-root <host-app>
```

Protected delivery can still use MiniProgram access keys, but those keys are
delivery/endpoint concerns. Provider credentials and backend secrets never go in
mini-program JSON or partner packages.
