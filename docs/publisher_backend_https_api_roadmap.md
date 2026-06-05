# Publisher Backend HTTPS API Roadmap

## Goal

Keep mini-programs frontend-only while giving publishers full backend freedom:

```text
Mini-program = frontend only
Mp JSON -> mini_program_sdk HTTPS client -> publisher-owned backend -> any provider/service
```

Static manifest, screen JSON, and assets can be public. Business data, writes,
auth, payments, databases, provider SDKs, and secrets belong behind the
publisher backend.

Production backend calls should use HTTPS. Plain HTTP is only for local preview
or loopback development.

## Core Architecture

Mp screens call relative publisher backend endpoints:

```text
orders/page
users/me
wallet/balance
files/upload-url
```

They do not contain absolute provider URLs. The full backend URL comes from the
partner handoff package:

```json
{
  "appId": "my_shop",
  "apiBaseUrl": "https://delivery.publisher.example/",
  "backendBaseUrl": "https://api.publisher.example/",
  "accessMode": "protected",
  "accessKey": "<partner-access-key>"
}
```

At runtime the SDK resolves:

```text
backendBaseUrl + relative endpoint
https://api.publisher.example/ + orders/page
= https://api.publisher.example/orders/page
```

The host app remains lightweight. It stores endpoint configuration and access
keys, but it does not install Firebase, AWS, database, payment, email, storage,
or AI provider SDKs for publishers.

## Protected API Model

The SDK sends standard context headers to publisher backends:

```text
X-Mini-Program-App-Id
X-Mini-Program-Host-App
X-Mini-Program-Host-Version
X-Mini-Program-SDK-Version
X-Mini-Program-Platform
X-Mini-Program-Access-Key
Authorization: Bearer <publisher-auth-token>
```

Publisher backends should verify:

- mini-program app id
- MiniProgram access key
- host app id and host version when relevant
- user auth token for signed-in data
- route-level permissions
- quotas and rate limits
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

## Backend Developer Model

The publisher backend can run anywhere:

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
miniprogram publisher-backend contract init
miniprogram publisher-backend start
miniprogram publisher-backend validate
miniprogram publisher-backend smoke
miniprogram publisher-backend handoff
```

Optional examples or templates can come later for Dart, Node, Firebase
Functions, AWS Lambda, Cloud Run, Docker, or other targets, but those are
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
