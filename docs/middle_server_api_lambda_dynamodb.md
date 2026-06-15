# Track 2: Middle-Server API With Lambda, DynamoDB, And JWT

This guide shows one optional runtime API setup for mini-programs that need
dynamic data.

The platform boundary stays the same:

- mini-program UI is still published as public static artifacts
- host opening still uses only `appId + artifactBaseUrl`
- runtime data calls go to an optional `middleServerApiUrl`
- the middle-server owns database access, auth, payment logic, secrets, provider SDKs, and business rules

AWS Lambda and DynamoDB are used here only as an example implementation. A
publisher can build the same API with Node, Laravel, Spring Boot, Supabase,
Cloudflare Workers, a VPS, or any other HTTPS server.

## What You Will Build

```text
Mini-program screen
  -> Mp.backendBuilder / Mp.lazy.chunk
  -> Host SDK runtime connector
  -> middleServerApiUrl
  -> AWS Lambda Function URL
  -> DynamoDB
```

Demo routes:

| Route | Method | Auth | Purpose |
| --- | --- | --- | --- |
| `/health` | `GET` | none | CLI smoke and uptime check. |
| `/profile` | `GET` | none | Read profile data from DynamoDB. |
| `/notes` | `GET` | optional JWT | Return paginated notes for `Mp.lazy.chunk`. |
| `/auth/demo-login` | `POST` | demo only | Return a short-lived JWT for local/manual testing. |
| `/notes` | `POST` | JWT | Create a note for the signed-in user. |

For the mini-program runtime, the important response shapes are:

```json
{ "data": { "name": "Mehedi" }, "traceId": "trace-id" }
```

```json
{ "items": [], "nextCursor": null, "hasMore": false, "traceId": "trace-id" }
```

```json
{ "errorCode": "unauthorized", "message": "Missing bearer token.", "traceId": "trace-id" }
```

## Architecture Rules

Keep these rules strict:

- Do not put AWS credentials, DynamoDB table names, JWT secrets, payment keys, or admin tokens inside mini-program static files.
- Do not call DynamoDB, AWS SDKs, payment SDKs, or provider services directly from `mini_program_ui`.
- The mini-program calls only relative runtime endpoints such as `profile` or `notes`.
- The host config may point the mini-program to `middleServerApiUrl`.
- JWT verification happens inside the middle-server.
- If the host app owns user login, the host should attach the user token to the runtime API connector or provide a custom connector. Do not bake user JWTs into published artifacts.

## 1. Create A DynamoDB Table

Create a table named `MiniProgramDemo`:

| Setting | Value |
| --- | --- |
| Partition key | `pk` string |
| Sort key | `sk` string |
| Capacity mode | On-demand / pay per request |

Seed one profile item in the DynamoDB console.

If `View DynamoDB JSON` is enabled, paste this typed DynamoDB JSON:

```json
{
  "pk": { "S": "PROFILE#mehedi" },
  "sk": { "S": "PROFILE" },
  "name": { "S": "Mehedi" },
  "role": { "S": "Mini-Program Platform Builder" },
  "location": { "S": "Dhaka, Bangladesh" },
  "bio": { "S": "Building lightweight mini-program experiences for Flutter host apps." }
}
```

If `View DynamoDB JSON` is disabled, use normal JSON instead:

```json
{
  "pk": "PROFILE#mehedi",
  "sk": "PROFILE",
  "name": "Mehedi",
  "role": "Mini-Program Platform Builder",
  "location": "Dhaka, Bangladesh",
  "bio": "Building lightweight mini-program experiences for Flutter host apps."
}
```

Seed two notes.

With `View DynamoDB JSON` enabled:

```json
{
  "pk": { "S": "USER#demo-user" },
  "sk": { "S": "NOTE#2026-06-15T00:00:00.000Z#welcome" },
  "id": { "S": "welcome" },
  "text": { "S": "First dynamic note from DynamoDB." },
  "createdAt": { "S": "2026-06-15T00:00:00.000Z" }
}
```

```json
{
  "pk": { "S": "USER#demo-user" },
  "sk": { "S": "NOTE#2026-06-15T00:01:00.000Z#workflow" },
  "id": { "S": "workflow" },
  "text": { "S": "Static artifacts open first; runtime API is optional." },
  "createdAt": { "S": "2026-06-15T00:01:00.000Z" }
}
```

With `View DynamoDB JSON` disabled:

```json
{
  "pk": "USER#demo-user",
  "sk": "NOTE#2026-06-15T00:00:00.000Z#welcome",
  "id": "welcome",
  "text": "First dynamic note from DynamoDB.",
  "createdAt": "2026-06-15T00:00:00.000Z"
}
```

```json
{
  "pk": "USER#demo-user",
  "sk": "NOTE#2026-06-15T00:01:00.000Z#workflow",
  "id": "workflow",
  "text": "Static artifacts open first; runtime API is optional.",
  "createdAt": "2026-06-15T00:01:00.000Z"
}
```

## 2. Create The Lambda Package

Create a local package:

```powershell
cd D:\
mkdir mp_middle_server_demo
cd D:\mp_middle_server_demo
npm init -y
npm pkg set type=module
npm i @aws-sdk/client-dynamodb @aws-sdk/lib-dynamodb jsonwebtoken
```

Create `index.mjs`:

```js
import crypto from 'node:crypto';

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  QueryCommand,
} from '@aws-sdk/lib-dynamodb';
import jwt from 'jsonwebtoken';

const tableName = process.env.TABLE_NAME;
const jwtSecret = process.env.JWT_SECRET;
const demoPassword = process.env.DEMO_PASSWORD || 'change-me';
const demoLoginEnabled = process.env.DEMO_LOGIN_ENABLED === 'true';
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '*')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

const dynamo = DynamoDBDocumentClient.from(new DynamoDBClient({}));

export async function handler(event, context) {
  const traceId = context.awsRequestId || crypto.randomUUID();

  try {
    const method = event.requestContext?.http?.method || event.httpMethod || 'GET';
    const path = normalizePath(event.rawPath || event.path || '/');

    if (method === 'OPTIONS') {
      return json(event, 204, '', traceId);
    }

    if (method === 'GET' && path === '/health') {
      return json(event, 200, {
        data: { status: 'ok', service: 'my-profile-middle-server' },
        traceId,
      }, traceId);
    }

    if (method === 'GET' && path === '/profile') {
      return getProfile(event, traceId);
    }

    if (method === 'GET' && path === '/notes') {
      return listNotes(event, traceId);
    }

    if (method === 'POST' && path === '/auth/demo-login') {
      return demoLogin(event, traceId);
    }

    if (method === 'POST' && path === '/notes') {
      return createNote(event, traceId);
    }

    return error(event, 404, 'not_found', 'Route not found.', traceId);
  } catch (cause) {
    console.error(cause);
    return error(event, 500, 'server_error', 'Server error.', traceId);
  }
}

async function getProfile(event, traceId) {
  assertTableConfigured();

  const result = await dynamo.send(new GetCommand({
    TableName: tableName,
    Key: { pk: 'PROFILE#mehedi', sk: 'PROFILE' },
  }));

  const profile = result.Item || {
    name: 'Mehedi',
    role: 'Mini-Program Platform Builder',
    location: 'Dhaka, Bangladesh',
    bio: 'Building lightweight mini-program experiences for Flutter host apps.',
  };

  return json(event, 200, {
    data: {
      name: profile.name,
      role: profile.role,
      location: profile.location,
      bio: profile.bio,
    },
    traceId,
  }, traceId);
}

async function listNotes(event, traceId) {
  assertTableConfigured();

  const query = event.queryStringParameters || {};
  const limit = clampInt(query.limit, 1, 50, 10);
  const cursor = decodeCursor(query.cursor);
  const user = readOptionalUser(event, traceId);
  if (user.error) {
    return user.error;
  }
  const userId = user.claims?.sub || 'demo-user';

  const result = await dynamo.send(new QueryCommand({
    TableName: tableName,
    KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
    ExpressionAttributeValues: {
      ':pk': `USER#${userId}`,
      ':prefix': 'NOTE#',
    },
    ScanIndexForward: false,
    Limit: limit,
    ExclusiveStartKey: cursor,
  }));

  const items = (result.Items || []).map((item) => ({
    id: item.id,
    text: item.text,
    createdAt: item.createdAt,
  }));

  return json(event, 200, {
    items,
    nextCursor: encodeCursor(result.LastEvaluatedKey),
    hasMore: Boolean(result.LastEvaluatedKey),
    traceId,
  }, traceId);
}

async function demoLogin(event, traceId) {
  if (!demoLoginEnabled) {
    return error(event, 404, 'not_found', 'Route not found.', traceId);
  }
  if (!jwtSecret) {
    return error(event, 500, 'jwt_secret_missing', 'JWT secret is not configured.', traceId);
  }

  const body = parseBodyOrError(event);
  if (typeof body.error === 'function') {
    return body.error(traceId);
  }
  if (body.password !== demoPassword) {
    return error(event, 401, 'unauthorized', 'Invalid demo password.', traceId);
  }

  const token = jwt.sign(
    {
      sub: 'demo-user',
      scope: 'notes:write',
      appId: event.headers?.['x-mini-program-app-id'] || 'my_profile',
    },
    jwtSecret,
    {
      algorithm: 'HS256',
      expiresIn: '15m',
      issuer: 'my-profile-middle-server',
    },
  );

  return json(event, 200, {
    data: {
      token,
      tokenType: 'Bearer',
      expiresIn: 900,
    },
    traceId,
  }, traceId);
}

async function createNote(event, traceId) {
  assertTableConfigured();

  const auth = requireUser(event, traceId);
  if (auth.error) {
    return auth.error;
  }

  const body = parseBodyOrError(event);
  if (typeof body.error === 'function') {
    return body.error(traceId);
  }
  const text = String(body.text || '').trim();
  if (text.length < 1 || text.length > 500) {
    return error(event, 400, 'validation_failed', 'Note text must be 1-500 characters.', traceId);
  }

  const id = crypto.randomUUID();
  const createdAt = new Date().toISOString();
  const item = {
    pk: `USER#${auth.claims.sub}`,
    sk: `NOTE#${createdAt}#${id}`,
    id,
    text,
    createdAt,
  };

  await dynamo.send(new PutCommand({
    TableName: tableName,
    Item: item,
  }));

  return json(event, 201, {
    data: {
      id,
      text,
      createdAt,
    },
    traceId,
  }, traceId);
}

function requireUser(event, traceId) {
  const authorization = event.headers?.authorization || event.headers?.Authorization || '';
  if (!authorization.toLowerCase().startsWith('bearer ')) {
    return {
      error: error(event, 401, 'unauthorized', 'Missing bearer token.', traceId),
    };
  }
  if (!jwtSecret) {
    return {
      error: error(event, 500, 'jwt_secret_missing', 'JWT secret is not configured.', traceId),
    };
  }

  try {
    const token = authorization.slice('bearer '.length).trim();
    const claims = jwt.verify(token, jwtSecret, {
      algorithms: ['HS256'],
      issuer: 'my-profile-middle-server',
    });
    return { claims };
  } catch {
    return {
      error: error(event, 401, 'session_expired', 'Session expired or invalid.', traceId),
    };
  }
}

function readOptionalUser(event, traceId) {
  const authorization = event.headers?.authorization || event.headers?.Authorization || '';
  if (!authorization.trim()) {
    return { claims: undefined };
  }
  return requireUser(event, traceId);
}

function parseBodyOrError(event) {
  if (!event.body) {
    return {};
  }
  const raw = event.isBase64Encoded
    ? Buffer.from(event.body, 'base64').toString('utf8')
    : event.body;
  try {
    return JSON.parse(raw);
  } catch {
    return {
      error: (traceId) => error(event, 400, 'invalid_json', 'Request body must be valid JSON.', traceId),
    };
  }
}

function normalizePath(path) {
  const trimmed = path.trim();
  if (!trimmed || trimmed === '/') {
    return '/';
  }
  return trimmed.endsWith('/') ? trimmed.slice(0, -1) : trimmed;
}

function assertTableConfigured() {
  if (!tableName) {
    throw new Error('TABLE_NAME is not configured.');
  }
}

function clampInt(value, min, max, fallback) {
  const parsed = Number.parseInt(String(value || ''), 10);
  if (!Number.isInteger(parsed)) {
    return fallback;
  }
  return Math.max(min, Math.min(max, parsed));
}

function encodeCursor(key) {
  if (!key) {
    return null;
  }
  return Buffer.from(JSON.stringify(key), 'utf8').toString('base64url');
}

function decodeCursor(cursor) {
  if (!cursor) {
    return undefined;
  }
  try {
    return JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8'));
  } catch {
    return undefined;
  }
}

function json(event, statusCode, payload, traceId) {
  return {
    statusCode,
    headers: {
      ...corsHeaders(event),
      'content-type': 'application/json; charset=utf-8',
      'x-backend-trace-id': traceId,
    },
    body: payload === '' ? '' : JSON.stringify(payload),
  };
}

function error(event, statusCode, errorCode, message, traceId) {
  return json(event, statusCode, { errorCode, message, traceId }, traceId);
}

function corsHeaders(event) {
  const requestOrigin = event.headers?.origin || event.headers?.Origin || '';
  const allowOrigin = allowedOrigins.includes('*')
    ? '*'
    : allowedOrigins.includes(requestOrigin)
      ? requestOrigin
      : allowedOrigins[0] || '';

  return {
    'access-control-allow-origin': allowOrigin,
    'access-control-allow-methods': 'GET,POST,OPTIONS',
    'access-control-allow-headers': [
      'content-type',
      'authorization',
      'x-mini-program-app-id',
      'x-mini-program-host-app',
      'x-mini-program-host-version',
      'x-mini-program-sdk-version',
      'x-mini-program-platform',
      'x-mini-program-locale',
    ].join(','),
    'access-control-max-age': '300',
  };
}
```

Package it:

```powershell
Compress-Archive `
  -Path .\index.mjs,.\package.json,.\package-lock.json,.\node_modules `
  -DestinationPath .\function.zip `
  -Force
```

## 3. Create The Lambda Function

In AWS Lambda:

1. Create a function.
2. Use a current Node.js runtime.
3. Upload `function.zip`.
4. Set handler to `index.handler`.
5. Set memory to `256 MB`.
6. Set timeout to `15 seconds`.

Environment variables:

| Name | Example | Purpose |
| --- | --- | --- |
| `TABLE_NAME` | `MiniProgramDemo` | DynamoDB table name. |
| `JWT_SECRET` | long random value | HS256 JWT signing/verification secret. |
| `DEMO_PASSWORD` | long random value | Demo login password. |
| `DEMO_LOGIN_ENABLED` | `true` for test, `false` for production | Enables `/auth/demo-login`. |
| `ALLOWED_ORIGINS` | `*` for test, exact host origins for production | CORS origin policy. |

For production, store secrets in a proper secret manager and inject them at
runtime. Do not commit secrets.

## 4. Add Lambda Permissions For DynamoDB

The Lambda execution role needs CloudWatch Logs and only the DynamoDB actions
this function uses.

Attach a policy like this to the Lambda execution role, replacing region,
account ID, and table name:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:<region>:<account-id>:table/MiniProgramDemo"
    }
  ]
}
```

## 5. Create A Lambda Function URL

For local/demo testing:

- Auth type: `NONE`
- Invoke mode: `BUFFERED`
- CORS: enabled
- Allow origin: `*`
- Allow methods: `GET`, `POST`, `OPTIONS`
- Allow headers:

```text
content-type
authorization
x-mini-program-app-id
x-mini-program-host-app
x-mini-program-host-version
x-mini-program-sdk-version
x-mini-program-platform
x-mini-program-locale
```

For production, prefer exact allowed origins instead of `*`.

Copy the Function URL. This is your runtime `middleServerApiUrl`, for example:

```text
https://abc123.lambda-url.ap-south-1.on.aws/
```

## 6. Test The API Directly

Replace the base URL:

```powershell
$api = "https://abc123.lambda-url.ap-south-1.on.aws"
```

Health:

```powershell
Invoke-RestMethod "$api/health"
```

Profile:

```powershell
Invoke-RestMethod "$api/profile"
```

Paginated notes:

```powershell
Invoke-RestMethod "$api/notes?limit=10"
```

Demo login:

```powershell
$login = Invoke-RestMethod `
  -Method Post `
  -Uri "$api/auth/demo-login" `
  -ContentType "application/json" `
  -Body (@{ password = "your-demo-password" } | ConvertTo-Json)

$token = $login.data.token
```

Create a note with JWT:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri "$api/notes" `
  -Headers @{ Authorization = "Bearer $token" } `
  -ContentType "application/json" `
  -Body (@{ text = "Created from PowerShell." } | ConvertTo-Json)
```

## 7. Register The Runtime API Contract

In the mini-program project:

```powershell
miniprogram publisher-api contract init `
  --mini-program-root D:\my_profile `
  --backend-base-url https://abc123.lambda-url.ap-south-1.on.aws/ `
  --health-endpoint health
```

Validate:

```powershell
miniprogram publisher-api contract validate `
  --mini-program-root D:\my_profile
```

Smoke test public routes:

```powershell
miniprogram publisher-api contract smoke `
  --mini-program-root D:\my_profile
```

Smoke test protected routes when your contract includes them:

```powershell
miniprogram publisher-api contract smoke `
  --mini-program-root D:\my_profile `
  --auth-token $token
```

`--backend-base-url` is the current CLI and Contract V1 compatibility name for
the optional runtime API URL. In architecture docs, call it
`middleServerApiUrl`.

## 8. Call The API From A Mini-Program

Use relative endpoints. Do not write the full Lambda URL in screen code.

Example profile screen section:

```dart
Mp.backendBuilder(
  requestId: 'profile',
  endpoint: 'profile',
  loading: Mp.text('Loading profile...'),
  error: Mp.text('{{backend.profile.message}}'),
  empty: Mp.text('No profile found.'),
  child: Mp.card(
    child: Mp.column(
      children: <MpNode>[
        Mp.heading('{{backend.profile.data.name}}'),
        Mp.text('{{backend.profile.data.role}}'),
        Mp.text('{{backend.profile.data.location}}'),
        Mp.text('{{backend.profile.data.bio}}'),
      ],
    ),
  ),
);
```

Example dynamic note list:

```dart
Mp.lazy.chunk(
  id: 'notes_chunk',
  itemsState: 'notes.items',
  cursorState: 'notes.next_cursor',
  hasMoreState: 'notes.has_more',
  statusState: 'notes.status',
  placeholder: Mp.text('Loading notes...'),
  loadingMore: Mp.text('Loading more notes...'),
  empty: Mp.text('No notes yet.'),
  error: Mp.text('Notes failed to load.'),
  end: Mp.text('No more notes.'),
  itemTemplate: Mp.card(
    child: Mp.column(
      children: <MpNode>[
        Mp.text('{{item.text}}'),
        Mp.text('{{item.createdAt}}'),
      ],
    ),
  ),
  initialActions: <MpAction>[
    Mp.backend.loadMore(
      requestId: 'notes',
      endpoint: 'notes',
      limit: 10,
    ),
  ],
  loadMoreActions: <MpAction>[
    Mp.backend.loadMore(
      requestId: 'notes',
      endpoint: 'notes',
      limit: 10,
    ),
  ],
  loadMore: Mp.secondaryButton(
    label: 'Load more',
    action: Mp.lazy.loadMore(id: 'notes_chunk'),
  ),
);
```

## 9. Preview With The Runtime API

Static preview still works without any runtime API URL. Add the backend URL only
when the screen uses runtime actions:

```powershell
miniprogram preview -d chrome `
  --mini-program-root D:\my_profile `
  --backend-base-url https://abc123.lambda-url.ap-south-1.on.aws/
```

## 10. Add The Runtime API To A Host Endpoint

If the host already imported the static partner package, re-add the endpoint
with the same `artifactBaseUrl` and the optional runtime API URL:

```powershell
miniprogram host endpoint add my_profile `
  --artifact-base-url https://<github-user>.github.io/my_profile_static/ `
  --backend-base-url https://abc123.lambda-url.ap-south-1.on.aws/ `
  --title "My Profile" `
  --project-root D:\my_profile_host `
  --force
```

Then run:

```powershell
miniprogram host run -d chrome --project-root D:\my_profile_host
```

For Android:

```powershell
flutter run -d emulator-5554
flutter build apk
```

## JWT Notes

JWT is optional. Use it when the runtime API needs user-specific data or write
actions.

Recommended rules:

- Use short token lifetimes.
- Verify issuer and allowed algorithms.
- Return `401` with `errorCode: "session_expired"` for expired/invalid tokens.
- Do not publish a JWT secret in static artifacts.
- Do not store long-lived user tokens in mini-program code.
- For production identity, prefer the host app or publisher auth system issuing tokens, then attach the token through the host runtime connector or endpoint headers.

The CLI smoke command can send a bearer token with `--auth-token`, but that is
only for testing your middle-server contract.

## Production Checklist

- Replace demo password/login with your real auth system.
- Disable `DEMO_LOGIN_ENABLED`.
- Restrict CORS origins to your real host domains.
- Keep DynamoDB IAM permissions least-privilege.
- Add request validation and rate limits.
- Add structured logs with `traceId`.
- Return JSON error envelopes for all failures.
- Keep static artifact hosting separate from runtime API routes.
- Monitor Lambda errors, duration, and DynamoDB throttling.

## References

- AWS Lambda Function URLs:
  <https://docs.aws.amazon.com/lambda/latest/dg/urls-configuration.html>
- AWS Lambda execution roles:
  <https://docs.aws.amazon.com/lambda/latest/dg/lambda-intro-execution-role.html>
- AWS SDK for JavaScript v3 DynamoDB document client:
  <https://docs.aws.amazon.com/sdk-for-javascript/v3/developer-guide/migrate-dynamodb-doc-client.html>
- Lambda Function URL CORS:
  <https://docs.aws.amazon.com/lambda/latest/api/API_Cors.html>
- jsonwebtoken package:
  <https://www.npmjs.com/package/jsonwebtoken>
