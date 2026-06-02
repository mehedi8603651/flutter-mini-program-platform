part of '../../publisher_backend_starter.dart';

String _firebaseJson() => _prettyJson(<String, Object?>{
  'functions': <String, Object?>{'source': 'functions'},
  'emulators': <String, Object?>{
    'functions': <String, Object?>{'port': 5001},
    'firestore': <String, Object?>{'port': 8080},
    'ui': <String, Object?>{'enabled': true},
  },
});

String _firebaseRcExample() => _prettyJson(<String, Object?>{
  'projects': <String, Object?>{'default': 'your-firebase-project-id'},
});

String _firebaseFunctionsPackageJson(
  String appId,
) => _prettyJson(<String, Object?>{
  'name': '${_safeNodePackageSegment(appId)}-firebase-backend',
  'private': true,
  'type': 'module',
  'main': 'index.js',
  'engines': <String, Object?>{'node': '22'},
  'scripts': <String, Object?>{
    'serve':
        'firebase emulators:start --config ../firebase.json --only functions,firestore',
    'shell': 'firebase functions:shell --config ../firebase.json',
    'deploy': 'firebase deploy --config ../firebase.json --only functions',
    'logs': 'firebase functions:log',
  },
  'dependencies': <String, Object?>{
    'firebase-admin': _firebaseAdminVersion,
    'firebase-functions': _firebaseFunctionsVersion,
  },
});

String _firebaseFunctionsReadme(String appId, String title) =>
    '''
# $title Firebase publisher backend

This is a Firebase Cloud Functions v2 + Firestore publisher backend for
mini-program business data. It is separate from mini-program delivery and keeps
Firebase Admin SDK credentials on publisher-owned infrastructure.

Storage mode: Firestore

Generated routes:

- `GET /health`
- `GET /home/bootstrap`
- `GET /coupons/list`
- `GET /coupons/page?limit=20&cursor=<couponId>`
- `GET /auth/session` (requires `Authorization: Bearer <idToken>`)
- `POST /auth/email/sign-up`
- `POST /auth/email/sign-in`
- `POST /auth/refresh`
- `POST /auth/sign-out`
- `POST /coupon/redeem`

Firestore data model:

- `miniPrograms/$appId/home/bootstrap`
- `miniPrograms/$appId/sessions/demo`
- `miniPrograms/$appId/coupons/<couponId>`
- `miniPrograms/$appId/authSessions/<sessionId>`
- `miniPrograms/$appId/redemptions/<safeUserId_safeCouponId>`

Setup from the mini-program root:

```powershell
cd ../..
miniprogram env init
miniprogram env configure my-firebase-prod `
  --provider firebase `
  --project-id your-firebase-project-id `
  --region us-central1 `
  --auth-web-api-key your-firebase-web-api-key

miniprogram publisher-backend firebase deploy `
  --env my-firebase-prod
miniprogram publisher-backend firebase seed `
  --env my-firebase-prod
miniprogram publisher-backend firebase data status `
  --env my-firebase-prod
miniprogram publisher-backend firebase smoke `
  --env my-firebase-prod
miniprogram publisher-backend firebase smoke `
  --env my-firebase-prod `
  --include-write
miniprogram publisher-backend firebase smoke `
  --env my-firebase-prod `
  --include-auth `
  --auth-email test@example.com `
  --auth-password "replace-with-a-test-password" `
  --auth-create-user
```

`firebase seed` and `firebase data status` use your Firebase CLI login token, so
run `firebase login` first or provide `FIREBASE_TOKEN` in CI.
`firebase smoke --include-write` also uses that token to verify the written
Firestore redemption document after `POST /coupon/redeem`.
`firebase smoke --include-auth` calls the public auth endpoints and redacts
passwords and auth tokens from CLI output.

Local emulator:

```powershell
cd functions
npm install
npm run serve
```

After deploy, connect host apps with the HTTPS function URL as
`--backend-base-url`. The host app does not need Firebase SDKs, Firebase
project access, or the Firebase Web API key. Email/password auth is owned by
this publisher backend and returns SDK-compatible sessions.
''';

String _firebaseFunctionsIndexSource(String appId) =>
    '''
import { onRequest } from 'firebase-functions/v2/https';
import { getApps, initializeApp } from 'firebase-admin/app';
import { createPublisherBackendHandler } from './router.js';
import { createFirebasePublisherAuthService } from './auth_service.js';
import { createFirestorePublisherBackendStore } from './firestore_store.js';

if (getApps().length === 0) {
  initializeApp();
}

const appId = process.env.MINI_PROGRAM_ID || '$appId';
const store = createFirestorePublisherBackendStore({ appId });
const authService = createFirebasePublisherAuthService({ appId, store });
const publisherBackendHandler = createPublisherBackendHandler({
  store,
  authService,
});

export const publisherBackend = onRequest(
  {
    region: process.env.PUBLISHER_BACKEND_REGION || 'us-central1',
  },
  publisherBackendHandler,
);
''';

String _firebaseFunctionsRouterSource() => r'''
import { createHash } from 'node:crypto';

export const expectedRoutes = [
  'GET /health',
  'GET /home/bootstrap',
  'GET /coupons/list',
  'GET /coupons/page',
  'GET /auth/session',
  'POST /auth/email/sign-up',
  'POST /auth/email/sign-in',
  'POST /auth/refresh',
  'POST /auth/sign-out',
  'POST /coupon/redeem',
];

export function createPublisherBackendHandler({
  store,
  authService,
  clock = () => new Date(),
} = {}) {
  if (!store) {
    throw new Error('createPublisherBackendHandler requires a store.');
  }

  return async function publisherBackendHandler(request, response) {
    writeCorsHeaders(response);
    if (request.method === 'OPTIONS') {
      return endEmpty(response, 204);
    }

    const method = String(request.method || 'GET').toUpperCase();
    const routePath = normalizePath(
      request.path || request.url || request.originalUrl || '/',
    );

    try {
      if (method === 'GET' && routePath === '/health') {
        return writeJson(response, 200, {
          status: 'ok',
          service: 'mini_program_firebase_publisher_backend',
          generatedAtUtc: clock().toISOString(),
        });
      }

      const accessGuard = await verifyMiniProgramAccessKey({
        store,
        request,
        clock,
      });
      if (accessGuard) {
        return writeJson(
          response,
          accessGuard.statusCode,
          accessGuard.body,
        );
      }

      if (method === 'GET' && routePath === '/home/bootstrap') {
        const body = await store.homeBootstrap();
        return body
          ? writeJson(response, 200, body)
          : writeJson(response, 404, {
              errorCode: 'home_bootstrap_missing',
              message: 'Home bootstrap document was not found.',
            });
      }
      if (method === 'GET' && routePath === '/coupons/list') {
        return writeJson(response, 200, await store.couponsList());
      }
      if (method === 'GET' && routePath === '/coupons/page') {
        const options = pagingOptions(request);
        if (typeof store.couponsPage === 'function') {
          return writeJson(response, 200, await store.couponsPage(options));
        }
        const body = await store.couponsList();
        return writeJson(response, 200, pageItems(body?.coupons, options));
      }
      if (method === 'GET' && routePath === '/auth/session') {
        const result = await requireAuthService(authService).currentSession({
          authorizationHeader: headerValue(request, 'authorization'),
        });
        return writeJson(response, result.statusCode || 200, result.body || result);
      }
      if (method === 'POST' && routePath === '/auth/email/sign-up') {
        const body = await readJsonBody(request);
        const result = await requireAuthService(authService).signUpEmail({
          email: stringValue(body?.email),
          password: stringValue(body?.password),
          requestedAtUtc: clock().toISOString(),
        });
        return writeJson(response, result.statusCode || 200, result.body || result);
      }
      if (method === 'POST' && routePath === '/auth/email/sign-in') {
        const body = await readJsonBody(request);
        const result = await requireAuthService(authService).signInEmail({
          email: stringValue(body?.email),
          password: stringValue(body?.password),
          requestedAtUtc: clock().toISOString(),
        });
        return writeJson(response, result.statusCode || 200, result.body || result);
      }
      if (method === 'POST' && routePath === '/auth/refresh') {
        const body = await readJsonBody(request);
        const result = await requireAuthService(authService).refresh({
          refreshToken: stringValue(body?.refreshToken),
          requestedAtUtc: clock().toISOString(),
        });
        return writeJson(response, result.statusCode || 200, result.body || result);
      }
      if (method === 'POST' && routePath === '/auth/sign-out') {
        const body = await readJsonBody(request);
        const result = await requireAuthService(authService).signOut({
          refreshToken: stringValue(body?.refreshToken),
          authorizationHeader: headerValue(request, 'authorization'),
          requestedAtUtc: clock().toISOString(),
        });
        return writeJson(response, result.statusCode || 200, result.body || result);
      }
      if (method === 'POST' && routePath === '/coupon/redeem') {
        const body = await readJsonBody(request);
        const couponId = stringValue(body?.couponId);
        if (!couponId) {
          return writeJson(response, 400, {
            errorCode: 'missing_coupon_id',
            message: 'couponId is required.',
          });
        }
        const userId = stringValue(body?.userId) || 'preview-user';
        const result = await store.redeemCoupon({
          couponId,
          userId,
          requestedAtUtc: clock().toISOString(),
        });
        return writeJson(response, result.statusCode || 200, result.body || result);
      }

      return writeJson(response, 404, {
        errorCode: 'not_found',
        message: 'No publisher backend route matches ' + method + ' ' + routePath + '.',
      });
    } catch (error) {
      return writeJson(response, 500, {
        errorCode: 'publisher_backend_error',
        message: error instanceof Error ? error.message : String(error),
      });
    }
  };
}

function normalizePath(value) {
  let path = String(value || '/');
  if (path.startsWith('http://') || path.startsWith('https://')) {
    path = new URL(path).pathname;
  }
  path = path.split('?')[0].replace(/\/+$/g, '');
  return path || '/';
}

async function readJsonBody(request) {
  if (request.body && typeof request.body === 'object') {
    return request.body;
  }
  if (typeof request.body === 'string') {
    return request.body.trim() ? JSON.parse(request.body) : {};
  }
  if (request[Symbol.asyncIterator]) {
    const chunks = [];
    for await (const chunk of request) {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    const text = Buffer.concat(chunks).toString('utf8');
    return text.trim() ? JSON.parse(text) : {};
  }
  return {};
}

function writeCorsHeaders(response) {
  response.setHeader?.('access-control-allow-origin', '*');
  response.setHeader?.('access-control-allow-methods', 'GET, POST, OPTIONS');
  response.setHeader?.(
    'access-control-allow-headers',
    [
      'content-type',
      'x-mini-program-access-key',
      'x-mini-program-app-id',
      'x-mini-program-host-app',
      'x-mini-program-host-version',
      'x-mini-program-id',
      'x-mini-program-sdk-version',
      'x-mini-program-platform',
      'x-mini-program-locale',
      'authorization',
    ].join(', '),
  );
}

function requireAuthService(authService) {
  if (!authService) {
    return {
      currentSession: async () => authNotConfigured(),
      signUpEmail: async () => authNotConfigured(),
      signInEmail: async () => authNotConfigured(),
      refresh: async () => authNotConfigured(),
      signOut: async () => authNotConfigured(),
    };
  }
  return authService;
}

function authNotConfigured() {
  return {
    statusCode: 500,
    body: {
      errorCode: 'auth_not_configured',
      message: 'Publisher auth service is not configured.',
    },
  };
}

function headerValue(request, name) {
  const lowerName = String(name).toLowerCase();
  const headers = request.headers || {};
  for (const [key, value] of Object.entries(headers)) {
    if (String(key).toLowerCase() === lowerName) {
      return Array.isArray(value) ? String(value[0] || '') : String(value || '');
    }
  }
  if (typeof request.get === 'function') {
    return String(request.get(name) || '');
  }
  return '';
}

async function verifyMiniProgramAccessKey({ store, request, clock }) {
  if (typeof store.activeAccessKeys !== 'function') {
    return null;
  }
  const keys = await store.activeAccessKeys();
  const configuredKeys = Array.isArray(keys)
    ? keys.filter((key) => key && key.active !== false && !key.revokedAtUtc)
    : [];
  if (configuredKeys.length === 0) {
    return null;
  }
  const accessKey = headerValue(request, 'x-mini-program-access-key').trim();
  if (!accessKey) {
    return accessKeyFailed(
      401,
      'access_key_required',
      'MiniProgram access key is required for this publisher backend.',
    );
  }
  const accessKeyHash = createHash('sha256')
    .update(accessKey, 'utf8')
    .digest('hex');
  const now = clock();
  const matched = configuredKeys.some((key) => {
    if (String(key.keyHash || key.sha256 || '').trim() !== accessKeyHash) {
      return false;
    }
    if (key.expiresAtUtc) {
      const expiresAt = new Date(key.expiresAtUtc);
      if (Number.isFinite(expiresAt.getTime()) && expiresAt <= now) {
        return false;
      }
    }
    return true;
  });
  if (!matched) {
    return accessKeyFailed(
      403,
      'access_key_invalid',
      'MiniProgram access key is not authorized for this publisher backend.',
    );
  }
  return null;
}

function accessKeyFailed(statusCode, errorCode, message) {
  return {
    statusCode,
    body: {
      errorCode,
      message,
    },
  };
}

function writeJson(response, statusCode, body) {
  if (typeof response.status === 'function') {
    response.status(statusCode);
  } else {
    response.statusCode = statusCode;
  }
  response.setHeader?.('content-type', 'application/json; charset=utf-8');
  if (typeof response.json === 'function') {
    response.json(body);
  } else {
    response.end(JSON.stringify(body, null, 2));
  }
}

function endEmpty(response, statusCode) {
  if (typeof response.status === 'function') {
    response.status(statusCode);
  } else {
    response.statusCode = statusCode;
  }
  response.end();
}

function stringValue(value) {
  if (value === undefined || value === null) {
    return '';
  }
  return String(value).trim();
}

function pagingOptions(request) {
  return {
    limit: boundedLimit(queryValue(request, 'limit'), 20, 100),
    cursor: queryValue(request, 'cursor'),
  };
}

function pageItems(items, { limit, cursor }) {
  const source = Array.isArray(items) ? items : [];
  const startIndex = cursor ? cursorStartIndex(source, cursor) : 0;
  const page = source.slice(startIndex, startIndex + limit);
  const nextIndex = startIndex + page.length;
  const hasMore = nextIndex < source.length;
  return {
    items: page,
    nextCursor: hasMore ? cursorFor(page[page.length - 1], nextIndex) : null,
    hasMore,
  };
}

function queryValue(request, name) {
  if (request.query && request.query[name] !== undefined) {
    const value = request.query[name];
    return Array.isArray(value) ? String(value[0] || '') : String(value || '');
  }
  const rawUrl = request.originalUrl || request.url || request.path || '';
  try {
    const parsed = rawUrl.startsWith('http://') || rawUrl.startsWith('https://')
      ? new URL(rawUrl)
      : new URL(rawUrl, 'http://localhost');
    return parsed.searchParams.get(name) || '';
  } catch (_) {
    return '';
  }
}

function boundedLimit(value, defaultLimit, maxLimit) {
  const parsed = Number.parseInt(String(value || ''), 10);
  if (!Number.isFinite(parsed) || parsed < 1) {
    return defaultLimit;
  }
  return Math.min(parsed, maxLimit);
}

function cursorStartIndex(items, cursor) {
  const index = items.findIndex((item) => String(item?.id || '') === cursor);
  if (index >= 0) {
    return index + 1;
  }
  const numeric = Number.parseInt(cursor, 10);
  return Number.isFinite(numeric) && numeric > 0 ? numeric : 0;
}

function cursorFor(item, fallbackIndex) {
  const id = item?.id == null ? '' : String(item.id);
  return id || String(fallbackIndex);
}
''';

String _firebaseFunctionsAuthServiceSource() => r'''
import { createHash, randomBytes } from 'node:crypto';
import { getAuth } from 'firebase-admin/auth';

export function createFirebasePublisherAuthService({
  appId,
  store,
  auth = getAuth(),
  apiKey = process.env.PUBLISHER_AUTH_WEB_API_KEY || process.env.FIREBASE_AUTH_WEB_API_KEY,
  fetchImpl = globalThis.fetch,
  clock = () => new Date(),
  refreshTokenTtlDays = Number(process.env.PUBLISHER_AUTH_REFRESH_TOKEN_TTL_DAYS || 30),
} = {}) {
  if (!appId) {
    throw new Error('createFirebasePublisherAuthService requires appId.');
  }
  if (!store) {
    throw new Error('createFirebasePublisherAuthService requires store.');
  }

  async function signUpEmail({ email, password }) {
    const validation = validateEmailPassword(email, password);
    if (validation) {
      return validation;
    }
    if (!authConfigured(apiKey, fetchImpl)) {
      return authNotConfigured();
    }
    try {
      const userRecord = await auth.createUser({
        email,
        password,
        emailVerified: false,
        disabled: false,
      });
      return ok(
        await createPublisherSession({
          auth,
          store,
          appId,
          apiKey,
          fetchImpl,
          clock,
          refreshTokenTtlDays,
          userRecord,
        }),
      );
    } catch (error) {
      return mapAdminAuthError(error, {
        'auth/email-already-exists': {
          statusCode: 409,
          errorCode: 'email_already_exists',
          message: 'A Firebase Auth user already exists for this email.',
        },
      });
    }
  }

  async function signInEmail({ email, password }) {
    const validation = validateEmailPassword(email, password);
    if (validation) {
      return validation;
    }
    if (!authConfigured(apiKey, fetchImpl)) {
      return authNotConfigured();
    }
    const signIn = await callIdentityToolkit({
      apiKey,
      fetchImpl,
      endpoint: 'accounts:signInWithPassword',
      body: {
        email,
        password,
        returnSecureToken: true,
      },
    });
    if (!signIn.ok) {
      return signIn.error;
    }
    const uid = String(signIn.body.localId || '').trim();
    if (!uid) {
      return failed(502, 'invalid_auth_response', 'Firebase Auth did not return a user id.');
    }
    try {
      const userRecord = await auth.getUser(uid);
      if (userRecord.disabled) {
        return failed(403, 'user_disabled', 'Firebase Auth user is disabled.');
      }
      return ok(
        await createPublisherSession({
          auth,
          store,
          appId,
          apiKey,
          fetchImpl,
          clock,
          refreshTokenTtlDays,
          userRecord,
        }),
      );
    } catch (error) {
      return mapAdminAuthError(error);
    }
  }

  async function refresh({ refreshToken }) {
    if (!refreshToken) {
      return failed(400, 'missing_refresh_token', 'refreshToken is required.');
    }
    if (!authConfigured(apiKey, fetchImpl)) {
      return authNotConfigured();
    }
    const session = await store.authSessionByRefreshTokenHash(hashToken(refreshToken));
    const sessionCheck = await validateStoredSession({ session, store, clock });
    if (sessionCheck) {
      return sessionCheck;
    }
    try {
      const userRecord = await auth.getUser(session.uid);
      if (userRecord.disabled) {
        return failed(403, 'user_disabled', 'Firebase Auth user is disabled.');
      }
      const nextRefreshToken = randomToken();
      const now = clock();
      await store.updateAuthSession({
        sessionId: session.sessionId,
        refreshTokenHash: hashToken(nextRefreshToken),
        updatedAtUtc: now.toISOString(),
        refreshExpiresAtUtc: refreshExpiry(clock, refreshTokenTtlDays).toISOString(),
        email: userRecord.email || session.email || null,
      });
      return ok(
        await createSessionResponse({
          auth,
          apiKey,
          fetchImpl,
          appId,
          sessionId: session.sessionId,
          userRecord,
          refreshToken: nextRefreshToken,
        }),
      );
    } catch (error) {
      return mapAdminAuthError(error);
    }
  }

  async function signOut({ refreshToken, authorizationHeader }) {
    if (refreshToken) {
      const session = await store.authSessionByRefreshTokenHash(hashToken(refreshToken));
      if (session?.sessionId) {
        await store.deleteAuthSession(session.sessionId);
      }
      return ok({ status: 'signed_out' });
    }

    const decoded = await verifyPublisherToken({ auth, appId, authorizationHeader });
    if (decoded.ok && decoded.sessionId) {
      await store.deleteAuthSession(decoded.sessionId);
    }
    return ok({ status: 'signed_out' });
  }

  async function currentSession({ authorizationHeader }) {
    const decoded = await verifyPublisherToken({ auth, appId, authorizationHeader });
    if (!decoded.ok) {
      return decoded.error;
    }
    const session = await store.authSession(decoded.sessionId);
    const sessionCheck = await validateStoredSession({ session, store, clock });
    if (sessionCheck) {
      return sessionCheck;
    }
    if (session.uid !== decoded.uid) {
      return failed(401, 'auth_invalid_token', 'Auth token does not match the publisher session.');
    }
    try {
      const userRecord = await auth.getUser(decoded.uid);
      if (userRecord.disabled) {
        return failed(403, 'user_disabled', 'Firebase Auth user is disabled.');
      }
      return ok({
        authenticated: true,
        user: userJson(userRecord),
      });
    } catch (error) {
      return mapAdminAuthError(error);
    }
  }

  return {
    signUpEmail,
    signInEmail,
    refresh,
    signOut,
    currentSession,
  };
}

async function createPublisherSession({
  auth,
  store,
  appId,
  apiKey,
  fetchImpl,
  clock,
  refreshTokenTtlDays,
  userRecord,
}) {
  const sessionId = randomToken();
  const refreshToken = randomToken();
  const now = clock();
  const response = await createSessionResponse({
    auth,
    apiKey,
    fetchImpl,
    appId,
    sessionId,
    userRecord,
    refreshToken,
  });
  await store.createAuthSession({
    sessionId,
    uid: userRecord.uid,
    email: userRecord.email || null,
    refreshTokenHash: hashToken(refreshToken),
    createdAtUtc: now.toISOString(),
    updatedAtUtc: now.toISOString(),
    refreshExpiresAtUtc: refreshExpiry(clock, refreshTokenTtlDays).toISOString(),
  });
  return response;
}

async function createSessionResponse({
  auth,
  apiKey,
  fetchImpl,
  appId,
  sessionId,
  userRecord,
  refreshToken,
}) {
  const customToken = await auth.createCustomToken(userRecord.uid, {
    miniProgramId: appId,
    miniProgramSessionId: sessionId,
  });
  const exchange = await callIdentityToolkit({
    apiKey,
    fetchImpl,
    endpoint: 'accounts:signInWithCustomToken',
    body: {
      token: customToken,
      returnSecureToken: true,
    },
  });
  if (!exchange.ok) {
    throw new Error(exchange.error.body.message || 'Firebase custom token exchange failed.');
  }
  const idToken = String(exchange.body.idToken || '').trim();
  const expiresIn = Number(exchange.body.expiresIn || 3600);
  if (!idToken) {
    throw new Error('Firebase custom token exchange did not return an idToken.');
  }
  return {
    authenticated: true,
    user: userJson(userRecord),
    idToken,
    refreshToken,
    expiresIn: Number.isFinite(expiresIn) && expiresIn > 0 ? expiresIn : 3600,
  };
}

async function verifyPublisherToken({ auth, appId, authorizationHeader }) {
  const idToken = bearerToken(authorizationHeader);
  if (!idToken) {
    return {
      ok: false,
      error: failed(401, 'auth_required', 'Authorization bearer token is required.'),
    };
  }
  try {
    const decoded = await auth.verifyIdToken(idToken, true);
    if (decoded.miniProgramId !== appId) {
      return {
        ok: false,
        error: failed(401, 'auth_invalid_token', 'Auth token belongs to a different mini-program.'),
      };
    }
    const sessionId = String(decoded.miniProgramSessionId || '').trim();
    if (!sessionId) {
      return {
        ok: false,
        error: failed(401, 'auth_invalid_token', 'Auth token is missing publisher session claims.'),
      };
    }
    return {
      ok: true,
      uid: decoded.uid,
      sessionId,
    };
  } catch (_) {
    return {
      ok: false,
      error: failed(401, 'auth_invalid_token', 'Auth token is invalid or expired.'),
    };
  }
}

async function validateStoredSession({ session, store, clock }) {
  if (!session) {
    return failed(401, 'auth_session_revoked', 'Publisher auth session was revoked.');
  }
  if (session.revokedAtUtc) {
    return failed(401, 'auth_session_revoked', 'Publisher auth session was revoked.');
  }
  if (session.refreshExpiresAtUtc) {
    const expiresAt = new Date(session.refreshExpiresAtUtc);
    if (Number.isFinite(expiresAt.getTime()) && expiresAt <= clock()) {
      await store.deleteAuthSession(session.sessionId);
      return failed(401, 'auth_session_expired', 'Publisher auth session expired.');
    }
  }
  return null;
}

async function callIdentityToolkit({ apiKey, fetchImpl, endpoint, body }) {
  const response = await fetchImpl(
    `https://identitytoolkit.googleapis.com/v1/${endpoint}?key=${encodeURIComponent(apiKey)}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    },
  );
  const decoded = await safeJson(response);
  if (!response.ok) {
    return {
      ok: false,
      error: mapIdentityToolkitError(response.status, decoded),
    };
  }
  return { ok: true, body: decoded };
}

async function safeJson(response) {
  try {
    return await response.json();
  } catch (_) {
    return {};
  }
}

function validateEmailPassword(email, password) {
  if (!email || !password) {
    return failed(400, 'missing_email_password', 'Email and password are required.');
  }
  return null;
}

function authConfigured(apiKey, fetchImpl) {
  return typeof fetchImpl === 'function' && String(apiKey || '').trim().length > 0;
}

function authNotConfigured() {
  return failed(
    500,
    'auth_not_configured',
    'PUBLISHER_AUTH_WEB_API_KEY is required for publisher-owned email auth.',
  );
}

function mapIdentityToolkitError(statusCode, decoded) {
  const message = String(decoded?.error?.message || '').trim();
  const normalized = message.split(' : ')[0];
  if (normalized === 'EMAIL_EXISTS') {
    return failed(409, 'email_already_exists', 'A Firebase Auth user already exists for this email.');
  }
  if (
    normalized === 'EMAIL_NOT_FOUND' ||
    normalized === 'INVALID_PASSWORD' ||
    normalized === 'INVALID_LOGIN_CREDENTIALS'
  ) {
    return failed(401, 'invalid_credentials', 'Email or password is incorrect.');
  }
  if (normalized === 'USER_DISABLED') {
    return failed(403, 'user_disabled', 'Firebase Auth user is disabled.');
  }
  return failed(statusCode || 502, 'firebase_auth_error', message || 'Firebase Auth request failed.');
}

function mapAdminAuthError(error, overrides = {}) {
  const code = String(error?.code || '').trim();
  if (overrides[code]) {
    return failed(
      overrides[code].statusCode,
      overrides[code].errorCode,
      overrides[code].message,
    );
  }
  if (code === 'auth/user-not-found') {
    return failed(401, 'auth_user_not_found', 'Firebase Auth user was not found.');
  }
  if (code === 'auth/invalid-password') {
    return failed(400, 'invalid_password', 'Password does not satisfy Firebase Auth requirements.');
  }
  return failed(500, 'firebase_admin_auth_error', error instanceof Error ? error.message : String(error));
}

function ok(body) {
  return { statusCode: 200, body };
}

function failed(statusCode, errorCode, message) {
  return {
    statusCode,
    body: {
      errorCode,
      message,
    },
  };
}

function userJson(userRecord) {
  return {
    uid: userRecord.uid,
    ...(userRecord.email ? { email: userRecord.email } : {}),
  };
}

function randomToken() {
  return randomBytes(32).toString('base64url');
}

function hashToken(token) {
  return createHash('sha256').update(String(token), 'utf8').digest('hex');
}

function refreshExpiry(clock, refreshTokenTtlDays) {
  const days = Number.isFinite(refreshTokenTtlDays) && refreshTokenTtlDays > 0
    ? refreshTokenTtlDays
    : 30;
  return new Date(clock().getTime() + days * 24 * 60 * 60 * 1000);
}

function bearerToken(header) {
  const value = String(header || '').trim();
  const match = /^Bearer\s+(.+)$/i.exec(value);
  return match ? match[1].trim() : '';
}
''';

String _firebaseFunctionsFirestoreStoreSource() => r'''
import { FieldPath, FieldValue, getFirestore } from 'firebase-admin/firestore';

export function createFirestorePublisherBackendStore({
  appId,
  db = getFirestore(),
} = {}) {
  if (!appId) {
    throw new Error('createFirestorePublisherBackendStore requires appId.');
  }
  const appRef = db.collection('miniPrograms').doc(appId);

  return {
    async homeBootstrap() {
      return readDocument(appRef.collection('home').doc('bootstrap'));
    },

    async couponsList() {
      const snapshot = await appRef.collection('coupons').get();
      const coupons = snapshot.docs
        .map((document) => ({
          id: document.id,
          ...document.data(),
        }))
        .sort(compareCoupons);
      return { coupons };
    },

    async couponsPage({ limit = 20, cursor = '' } = {}) {
      const pageLimit = boundedLimit(limit, 20, 100);
      let query = appRef
        .collection('coupons')
        .orderBy(FieldPath.documentId());
      if (cursor) {
        query = query.startAfter(String(cursor));
      }
      const snapshot = await query.limit(pageLimit + 1).get();
      const documents = snapshot.docs;
      const pageDocuments = documents.slice(0, pageLimit);
      const items = pageDocuments.map((document) => ({
        id: document.id,
        ...document.data(),
      }));
      const hasMore = documents.length > pageLimit;
      return {
        items,
        nextCursor: hasMore && items.length > 0 ? items[items.length - 1].id : null,
        hasMore,
      };
    },

    async createAuthSession(session) {
      await appRef.collection('authSessions').doc(session.sessionId).set({
        ...session,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return session;
    },

    async authSession(sessionId) {
      const document = await readDocument(
        appRef.collection('authSessions').doc(sessionId),
      );
      return document ? { sessionId, ...document } : null;
    },

    async authSessionByRefreshTokenHash(refreshTokenHash) {
      const snapshot = await appRef
        .collection('authSessions')
        .where('refreshTokenHash', '==', refreshTokenHash)
        .limit(1)
        .get();
      if (snapshot.empty) {
        return null;
      }
      const document = snapshot.docs[0];
      return { sessionId: document.id, ...document.data() };
    },

    async updateAuthSession({
      sessionId,
      refreshTokenHash,
      updatedAtUtc,
      refreshExpiresAtUtc,
      email,
    }) {
      await appRef.collection('authSessions').doc(sessionId).set(
        {
          refreshTokenHash,
          updatedAtUtc,
          refreshExpiresAtUtc,
          email: email || null,
          revokedAtUtc: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    },

    async deleteAuthSession(sessionId) {
      await appRef.collection('authSessions').doc(sessionId).delete();
    },

    async activeAccessKeys() {
      const snapshot = await appRef
        .collection('accessKeys')
        .where('active', '==', true)
        .get();
      return snapshot.docs.map((document) => ({
        keyId: document.id,
        ...document.data(),
      }));
    },

    async redeemCoupon({ couponId, userId, requestedAtUtc }) {
      const couponRef = appRef.collection('coupons').doc(couponId);
      const redemptionRef = appRef
        .collection('redemptions')
        .doc(safeDocumentId(userId) + '_' + safeDocumentId(couponId));

      return db.runTransaction(async (transaction) => {
        const couponSnapshot = await transaction.get(couponRef);
        if (!couponSnapshot.exists) {
          return {
            statusCode: 404,
            body: {
              errorCode: 'coupon_not_found',
              message: 'Coupon was not found.',
              couponId,
            },
          };
        }

        const redemptionSnapshot = await transaction.get(redemptionRef);
        if (redemptionSnapshot.exists) {
          return {
            statusCode: 200,
            body: {
              status: 'already_redeemed',
              couponId,
              userId,
              redemption: redemptionSnapshot.data(),
            },
          };
        }

        const redemption = {
          status: 'redeemed',
          couponId,
          userId,
          redeemedAtUtc: requestedAtUtc,
          createdAt: FieldValue.serverTimestamp(),
        };
        transaction.set(redemptionRef, redemption);
        return {
          statusCode: 200,
          body: {
            status: 'redeemed',
            couponId,
            userId,
            redemption: {
              ...redemption,
              createdAt: null,
            },
          },
        };
      });
    },
  };
}

async function readDocument(reference) {
  const snapshot = await reference.get();
  return snapshot.exists ? snapshot.data() : null;
}

function compareCoupons(left, right) {
  const leftSort = Number.isFinite(Number(left.sortIndex))
    ? Number(left.sortIndex)
    : Number.MAX_SAFE_INTEGER;
  const rightSort = Number.isFinite(Number(right.sortIndex))
    ? Number(right.sortIndex)
    : Number.MAX_SAFE_INTEGER;
  if (leftSort !== rightSort) {
    return leftSort - rightSort;
  }
  return String(left.title || left.id).localeCompare(String(right.title || right.id));
}

function boundedLimit(value, defaultLimit, maxLimit) {
  const parsed = Number.parseInt(String(value || ''), 10);
  if (!Number.isFinite(parsed) || parsed < 1) {
    return defaultLimit;
  }
  return Math.min(parsed, maxLimit);
}

function safeDocumentId(value) {
  return String(value || 'unknown')
    .trim()
    .replace(/[^A-Za-z0-9_.-]+/g, '_')
    .replace(/^_+|_+$/g, '') || 'unknown';
}
''';
