# Firebase Delivery Guide

This guide is intentionally no longer a Firebase Functions/Firestore publisher
backend walkthrough.

The active backend model is provider-neutral:

- use Firebase Hosting only for static mini-program delivery when you want it
- put auth, database, payments, file storage, admin logic, business rules, and
  secrets on a publisher-owned HTTPS API
- connect that API with `publisher-api contract ...`

The removed commands include the old Firebase Functions/Firestore scaffold,
deploy, auth, seed, data, and handoff flows.

## Firebase Hosting Static Delivery

Configure a Firebase environment:

```powershell
miniprogram env configure firebase-prod --provider firebase --project-id <project-id>
```

Publish public static delivery artifacts:

```powershell
miniprogram build --mini-program-root D:\my_mp
miniprogram validate --mini-program-root D:\my_mp
miniprogram publish --target firebase-hosting --env firebase-prod --mini-program-root D:\my_mp --clean
```

## Publisher API

Build your middle server on any provider, including Firebase Functions if that
is your preference. The mini-program does not know or depend on that provider;
it only receives the HTTPS API base URL.

```powershell
miniprogram publisher-api contract init `
  --mini-program-root D:\my_mp `
  --backend-base-url https://api.publisher.example `
  --public

miniprogram publisher-api contract validate --mini-program-root D:\my_mp
miniprogram publisher-api contract smoke --mini-program-root D:\my_mp
```

Create the host handoff package:

```powershell
miniprogram publisher-api contract handoff `
  --mini-program-root D:\my_mp `
  --delivery-url https://<project-id>.web.app/ `
  --public `
  --output D:\my_mp\my_mp.partner.json
```

Import it in the host app:

```powershell
miniprogram host endpoint import D:\my_mp\my_mp.partner.json --project-root D:\host_app
```

## Migration Note

If an older project already has a Firebase Functions/Firestore backend, keep it
as your own middle server if it works for your product. Do not expect current
tooling to scaffold, deploy, seed, inspect, or destroy it. Maintain that backend
with normal Firebase tools and expose the same provider-neutral HTTPS API
contract to the mini-program platform.
