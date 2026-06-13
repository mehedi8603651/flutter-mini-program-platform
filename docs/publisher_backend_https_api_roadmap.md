# Publisher API HTTPS Roadmap

## Goal

Keep mini-programs frontend-only while giving publishers full backend freedom:

```text
Mini-program = frontend only
Mp JSON -> mini_program_sdk HTTPS client -> publisher-owned Publisher API -> any provider/service
```

Static manifest, screen JSON, and assets can be public. Business data, writes,
auth, payments, databases, provider SDKs, and secrets belong behind the
Publisher API backend.

Production backend calls should use HTTPS. Plain HTTP is only for local preview
or loopback development.

## Current Usable Model

The standalone API model is already usable through the existing Publisher API
endpoint configuration. Static opening still uses only `appId` and
`artifactBaseUrl`; Publisher API Contract V1 is for optional runtime
middle-server calls after the mini-program opens. A mini-program screen stores
relative endpoints:

Publisher API Contract V1 is a runtime API standard only; host opening still
uses `appId` plus `artifactBaseUrl`.

```dart
Mp.backendBuilder(
  requestId: 'scholarshipHome',
  endpoint: 'scholarships/home',
  child: Mp.text('{{backend.scholarshipHome.data.title}}'),
)

Mp.pagedBackendBuilder(
  requestId: 'scholarships',
  endpoint: 'scholarships/page',
  itemTemplate: Mp.text('{{item.title}}'),
)

Mp.formSubmit(
  requestId: 'applicationSubmit',
  endpoint: 'applications/submit',
  body: {'scholarshipId': '{{state.application.selected.id}}'},
)
```

Optional runtime API configuration supplies the standalone HTTPS API base URL.
New docs should call this `middleServerApiUrl`; current compatibility files may
still use `backendBaseUrl`:

```text
middleServerApiUrl = https://api.publisher.example
```

At runtime the SDK combines both parts:

```text
scholarships/page
-> https://api.publisher.example/scholarships/page
```

This is the same runtime path for a custom server, Cloud Run, Docker, Lambda,
Firebase Functions, VPS, or Kubernetes. Firebase/AWS provider-specific backend
commands are no longer the active model; the Mp frontend uses the same
Publisher API contract for every provider.

## Core Architecture

Mp screens call relative middle-server API endpoints:

```text
orders/page
users/me
wallet/balance
files/upload-url
```

They do not contain absolute provider URLs. The current MVP host handoff is only
the static artifact opening boundary:

```json
{
  "appId": "my_shop",
  "artifactBaseUrl": "https://delivery.publisher.example/"
}
```

Runtime API config is separate. In current compatibility tooling it may still be
stored as `backendBaseUrl`; treat that as a runtime API connector field, not a
required host handoff field.

At runtime the SDK resolves:

```text
backendBaseUrl + relative endpoint
https://api.publisher.example/ + orders/page
= https://api.publisher.example/orders/page
```

The host app remains lightweight. It stores static artifact endpoint
configuration, but it does not install Firebase, AWS, database, payment, email,
storage, or AI provider SDKs for publishers.

## Contract V1 Runtime API Model

The SDK sends standard context headers to Publisher API backends:

```text
X-Mini-Program-App-Id
X-Mini-Program-Host-App
X-Mini-Program-Host-Version
X-Mini-Program-SDK-Version
X-Mini-Program-Platform
Authorization: Bearer <publisher-auth-token>
```

Publisher API backends should verify:

- mini-program app id
- host app id and host version when relevant
- user auth token for signed-in data
- route-level permissions
- quotas and rate limits

Access-key protected delivery and protected Publisher API partner handoffs are
legacy/advanced compatibility features. They are not part of the current MVP
opening boundary.
- request size and response size

Access keys identify and revoke partner integrations. They are not permanent
mobile secrets because app binaries can be inspected. High-risk routes should
also use signed user sessions, short-lived tokens, request signing, device/app
attestation, and server-side rate limits.

## Mini-Program API Usage

Use one `requestId` per API state. This lets one mini-program call many backend
routes without mixing data.

Object data:

```dart
Mp.backendBuilder(
  requestId: 'profile',
  endpoint: 'users/me',
  loading: Mp.text('Loading profile...'),
  error: Mp.text('{{backend.profile.message}}'),
  child: Mp.card(
    child: Mp.column(
      children: [
        Mp.heading('{{backend.profile.data.name}}'),
        Mp.text('{{backend.profile.data.email}}'),
      ],
    ),
  ),
)
```

Long lists:

```dart
Mp.pagedBackendBuilder(
  requestId: 'orders',
  endpoint: 'orders/page',
  limit: 20,
  loading: Mp.text('Loading orders...'),
  error: Mp.text('{{backend.orders.message}}'),
  empty: Mp.text('No orders yet.'),
  end: Mp.text('No more orders.'),
  itemTemplate: Mp.card(
    child: Mp.column(
      children: [
        Mp.heading('{{item.orderNumber}}'),
        Mp.text('{{item.status}}'),
      ],
    ),
  ),
  loadMore: Mp.secondaryButton(
    label: 'Load more',
    action: Mp.backend.loadMore(requestId: 'orders'),
  ),
)
```

Writes:

```dart
Mp.primaryButton(
  label: 'Create order',
  action: Mp.backend.call(
    endpoint: 'orders',
    method: 'POST',
    body: {
      'productId': 'product-1',
      'quantity': 2,
    },
  ),
)
```

The backend response can use normal JSON. Recommended shapes:

```json
{ "data": { "name": "Mehedi", "tier": "Gold" } }
```

```json
{
  "items": [],
  "nextCursor": null,
  "hasMore": false
}
```

```json
{
  "errorCode": "order_not_found",
  "message": "Order was not found."
}
```

## Publisher API Developer Model

The Publisher API backend can run anywhere:

- Firebase Functions
- AWS Lambda
- Google Cloud Run
- Docker
- VPS
- Kubernetes
- Azure Functions
- Supabase Edge Functions
- any custom HTTPS server

The backend can use any server-side services:

- Firestore
- DynamoDB
- PostgreSQL or MySQL
- MongoDB or Redis
- S3 or Cloud Storage
- Stripe or PayPal
- email, SMS, push, or AI APIs
- internal company APIs

Provider SDKs stay server-side. The mini-program and host app only see the
publisher's HTTPS contract.

Do not expose generic unrestricted proxy routes such as:

```text
POST /call-any-provider
```

Expose business routes instead:

```text
GET  /products
POST /orders
GET  /orders/<orderId>
POST /support/tickets
POST /files/upload-url
```

## Future Backend Contract And Tooling

The first priority is not provider-specific packages. The first priority is a
small, stable HTTPS API contract that any backend developer can implement with
any language, framework, cloud, database, or service.

The shared contract should define:

- request and response envelopes
- stable error codes
- access-key verification context
- authenticated user context
- cursor pagination
- upload intent and signed upload URL responses
- background job creation and polling
- request IDs and safe logging fields
- redaction rules for secrets and tokens

Future tooling should help developers scaffold and test generic HTTP APIs
without requiring a specific backend stack:

```text
miniprogram publisher-api contract init
miniprogram publisher-api contract validate
miniprogram publisher-api contract smoke
```

The contract commands are the provider-neutral path for an existing standalone
API. `init` writes `publisher_backend.json` with the backend base URL and smoke
cases, `validate` checks the contract without network calls, and `smoke` calls
the configured API with MiniProgram headers.

`publisher-api contract handoff` is legacy/advanced compatibility for older
protected/API handoff packages. Current MVP host opening should use
`miniprogram partner package <appId> --artifact-base-url <url>` so the package
contains static artifact opening information only.

Optional server examples or templates can come later for Dart, Node, Cloud Run,
Docker, Firebase Functions, AWS Lambda, or other targets, but those are
developer conveniences. A publisher can also bring an existing backend and only
implement the HTTPS contract.

## Security Boundaries

- No provider credentials in Mp JSON, host app source, APK, IPA, web
  JavaScript, logs, diagnostics, or handoff docs.
- No arbitrary absolute URL calls from Mp screens.
- No generic unrestricted proxy routes.
- Store only hashes of access keys on the server.
- Use HTTPS in production.
- Allow HTTP only for local preview or loopback.
- Payments require backend-created checkout sessions and explicit host/native
  payment capability.
- Large uploads use backend-created signed upload URLs.
- Long-running work returns a job ID and uses polling or a later realtime
  contract.
- Realtime WebSocket or Server-Sent Events support should be added later as an
  explicit capability, not as part of the first backend contract.
