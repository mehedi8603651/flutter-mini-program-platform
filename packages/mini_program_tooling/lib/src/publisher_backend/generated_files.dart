part of '../publisher_backend_starter.dart';

Map<String, String> buildAwsLambdaPublisherBackendFiles({
  required String miniProgramRootPath,
  String? miniProgramId,
  String? title,
  String storageMode = 'bundled',
}) {
  if (!const <String>[
    _publisherBackendStorageBundled,
    _publisherBackendStorageDynamoDb,
  ].contains(storageMode)) {
    throw PublisherBackendException(
      'Unsupported AWS Lambda publisher backend storage mode: $storageMode',
    );
  }
  final appId = miniProgramId?.trim().isNotEmpty == true
      ? miniProgramId!.trim()
      : _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
  final displayTitle = title?.trim().isNotEmpty == true
      ? title!.trim()
      : _titleFromAppId(appId);
  final sampleFiles = buildMockPublisherBackendFiles(
    miniProgramRootPath: miniProgramRootPath,
    miniProgramId: appId,
    title: displayTitle,
  );
  return <String, String>{
    'template.yaml': _awsLambdaTemplateYaml(
      displayTitle,
      appId: appId,
      storageMode: storageMode,
    ),
    'README.md': _awsLambdaReadme(appId, displayTitle, storageMode),
    p.join('src', 'package.json'): _awsLambdaPackageJson(appId, storageMode),
    p.join('src', 'handler.mjs'): _awsLambdaHandlerSource(),
    p.join('src', 'data', 'home_bootstrap.json'):
        sampleFiles[p.join('data', 'home_bootstrap.json')]!,
    p.join('src', 'data', 'coupons_list.json'):
        sampleFiles[p.join('data', 'coupons_list.json')]!,
    p.join('src', 'data', 'session.json'):
        sampleFiles[p.join('data', 'session.json')]!,
  };
}

Map<String, String> buildFirebaseFunctionsPublisherBackendFiles({
  required String miniProgramRootPath,
  String? miniProgramId,
  String? title,
}) {
  final appId = miniProgramId?.trim().isNotEmpty == true
      ? miniProgramId!.trim()
      : _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
  final displayTitle = title?.trim().isNotEmpty == true
      ? title!.trim()
      : _titleFromAppId(appId);
  final sampleFiles = buildMockPublisherBackendFiles(
    miniProgramRootPath: miniProgramRootPath,
    miniProgramId: appId,
    title: displayTitle,
  );
  return <String, String>{
    'firebase.json': _firebaseJson(),
    '.firebaserc.example': _firebaseRcExample(),
    'README.md': _firebaseFunctionsReadme(appId, displayTitle),
    p.join('functions', 'package.json'): _firebaseFunctionsPackageJson(appId),
    p.join('functions', 'index.js'): _firebaseFunctionsIndexSource(appId),
    p.join('functions', 'router.js'): _firebaseFunctionsRouterSource(),
    p.join('functions', 'auth_service.js'):
        _firebaseFunctionsAuthServiceSource(),
    p.join('functions', 'firestore_store.js'):
        _firebaseFunctionsFirestoreStoreSource(),
    p.join('functions', 'data', 'home_bootstrap.json'):
        sampleFiles[p.join('data', 'home_bootstrap.json')]!,
    p.join('functions', 'data', 'coupons_list.json'):
        sampleFiles[p.join('data', 'coupons_list.json')]!,
    p.join('functions', 'data', 'session.json'):
        sampleFiles[p.join('data', 'session.json')]!,
  };
}

Map<String, String> buildMockPublisherBackendFiles({
  required String miniProgramRootPath,
  String? miniProgramId,
  String? title,
}) {
  final appId = miniProgramId?.trim().isNotEmpty == true
      ? miniProgramId!.trim()
      : _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
  final displayTitle = title?.trim().isNotEmpty == true
      ? title!.trim()
      : _titleFromAppId(appId);
  return <String, String>{
    'pubspec.yaml': _mockBackendPubspec(appId),
    'README.md': _mockBackendReadme(appId, displayTitle),
    p.join('bin', 'server.dart'): _mockBackendServerSource(),
    p.join('data', 'home_bootstrap.json'): _prettyJson(<String, Object?>{
      'title': '$displayTitle backend starter',
      'subtitle': 'Loaded from the publisher-owned mock backend.',
      'user': <String, Object?>{
        'id': 'preview-user',
        'name': 'Preview User',
        'tier': 'Gold',
      },
      'heroImageUrl': 'https://picsum.photos/seed/${appId}_hero/960/480',
    }),
    p.join('data', 'coupons_list.json'): _prettyJson(<String, Object?>{
      'coupons': <Object?>[
        <String, Object?>{
          'id': 'coupon-10',
          'title': '10% starter coupon',
          'description': 'Backend-driven coupon item from mock data.',
          'imageUrl': 'https://picsum.photos/seed/${appId}_coupon_10/320/200',
        },
        <String, Object?>{
          'id': 'coupon-20',
          'title': '20% weekend reward',
          'description':
              'Replace this JSON with Firebase, AWS, or custom API data.',
          'imageUrl': 'https://picsum.photos/seed/${appId}_coupon_20/320/200',
        },
      ],
    }),
    p.join('data', 'session.json'): _prettyJson(<String, Object?>{
      'authenticated': true,
      'user': <String, Object?>{
        'id': 'preview-user',
        'name': 'Preview User',
        'email': 'preview@example.com',
      },
      'note': 'Mock auth only. Real auth belongs on publisher servers.',
    }),
  };
}

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
export const expectedRoutes = [
  'GET /health',
  'GET /home/bootstrap',
  'GET /coupons/list',
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
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

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

function safeDocumentId(value) {
  return String(value || 'unknown')
    .trim()
    .replace(/[^A-Za-z0-9_.-]+/g, '_')
    .replace(/^_+|_+$/g, '') || 'unknown';
}
''';

String _mockBackendPubspec(String appId) =>
    '''
name: ${appId}_mock_backend
description: Local mock publisher backend for $appId.
publish_to: none

environment:
  sdk: '>=3.9.0 <4.0.0'
''';

String _mockBackendReadme(String appId, String title) =>
    '''
# $title mock publisher backend

This is a local-only mock backend for mini-program data calls. It is not the
mini-program delivery backend and it does not contain production secrets.

Run it from the mini-program root:

```powershell
miniprogram publisher-backend run --port 9090
```

Useful base URLs:

- desktop/web host: `http://127.0.0.1:9090/`
- Android emulator host: `http://10.0.2.2:9090/`

Routes:

- `GET /health`
- `GET /home/bootstrap`
- `GET /coupons/list`
- `GET /auth/session`
- `POST /coupon/redeem`

Connect a host endpoint with:

```powershell
miniprogram host endpoint add $appId `
  --api-base-url <delivery-url> `
  --public `
  --backend-base-url http://127.0.0.1:9090/
```

Production Firebase, AWS, GCP, or custom server SDKs should live on your
publisher backend server, not in the Flutter host app or mini_program_sdk.
''';

String _mockBackendServerSource() => r'''
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final host = _option(arguments, 'host') ?? '0.0.0.0';
  final port = int.tryParse(_option(arguments, 'port') ?? '9090') ?? 9090;
  final dataRoot = Directory(
    _option(arguments, 'data-root') ??
        '${File.fromUri(Platform.script).parent.parent.path}${Platform.pathSeparator}data',
  );
  final server = await HttpServer.bind(host, port);
  stdout.writeln('Mock publisher backend listening on http://$host:$port');
  stdout.writeln('Data root: ${dataRoot.path}');
  await for (final request in server) {
    await _handleRequest(request, dataRoot);
  }
}

Future<void> _handleRequest(HttpRequest request, Directory dataRoot) async {
  _writeCorsHeaders(request.response);
  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }

  final path = request.uri.path.replaceAll(RegExp(r'/+$'), '');
  if (request.method == 'GET' && path == '/health') {
    await _writeJson(request.response, <String, Object?>{
      'status': 'ok',
      'service': 'mini_program_mock_publisher_backend',
      'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    });
    return;
  }
  if (request.method == 'GET' && path == '/home/bootstrap') {
    await _writeDataFile(request.response, dataRoot, 'home_bootstrap.json');
    return;
  }
  if (request.method == 'GET' && path == '/coupons/list') {
    await _writeDataFile(request.response, dataRoot, 'coupons_list.json');
    return;
  }
  if (request.method == 'GET' && path == '/auth/session') {
    await _writeDataFile(request.response, dataRoot, 'session.json');
    return;
  }
  if (request.method == 'POST' && path == '/coupon/redeem') {
    final body = await utf8.decoder.bind(request).join();
    final decoded = body.trim().isEmpty ? <String, Object?>{} : jsonDecode(body);
    await _writeJson(request.response, <String, Object?>{
      'status': 'redeemed',
      'couponId': decoded is Map ? decoded['couponId']?.toString() : null,
      'message': 'Mock redeem succeeded. Replace this route on your real backend.',
    });
    return;
  }

  request.response.statusCode = HttpStatus.notFound;
  await _writeJson(request.response, <String, Object?>{
    'errorCode': 'not_found',
    'message': 'No mock backend route matches ${request.uri.path}.',
  });
}

Future<void> _writeDataFile(
  HttpResponse response,
  Directory dataRoot,
  String fileName,
) async {
  final file = File('${dataRoot.path}${Platform.pathSeparator}$fileName');
  if (!await file.exists()) {
    response.statusCode = HttpStatus.notFound;
    await _writeJson(response, <String, Object?>{
      'errorCode': 'mock_data_missing',
      'message': 'Mock data file was not found: $fileName',
    });
    return;
  }
  response.headers.contentType = ContentType.json;
  await response.addStream(file.openRead());
  await response.close();
}

Future<void> _writeJson(HttpResponse response, Object? body) async {
  response.headers.contentType = ContentType.json;
  response.write(const JsonEncoder.withIndent('  ').convert(body));
  await response.close();
}

void _writeCorsHeaders(HttpResponse response) {
  response.headers.set('access-control-allow-origin', '*');
  response.headers.set(
    'access-control-allow-methods',
    'GET, POST, OPTIONS',
  );
  response.headers.set(
    'access-control-allow-headers',
    'content-type, x-mini-program-access-key, x-mini-program-app-id, x-mini-program-host-app, x-mini-program-host-version, x-mini-program-id, x-mini-program-sdk-version, x-mini-program-platform, x-mini-program-locale',
  );
}

String? _option(List<String> arguments, String name) {
  final prefix = '--$name=';
  for (var i = 0; i < arguments.length; i++) {
    final value = arguments[i];
    if (value.startsWith(prefix)) {
      return value.substring(prefix.length);
    }
    if (value == '--$name' && i + 1 < arguments.length) {
      return arguments[i + 1];
    }
  }
  return null;
}
''';

String _awsLambdaTemplateYaml(
  String title, {
  required String appId,
  required String storageMode,
}) {
  final usesDynamoDb = storageMode == _publisherBackendStorageDynamoDb;
  final dataTableResource = usesDynamoDb
      ? '''
  PublisherBackendDataTable:
    Type: AWS::DynamoDB::Table
    Properties:
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: pk
          AttributeType: S
        - AttributeName: sk
          AttributeType: S
      KeySchema:
        - AttributeName: pk
          KeyType: HASH
        - AttributeName: sk
          KeyType: RANGE

'''
      : '';
  final functionEnvironment =
      '''
      Environment:
        Variables:
          PUBLISHER_BACKEND_STORAGE: $storageMode
          MINI_PROGRAM_ID: $appId
${usesDynamoDb ? '          PUBLISHER_BACKEND_TABLE_NAME: !Ref PublisherBackendDataTable\n' : ''}''';
  final functionPolicies = usesDynamoDb
      ? '''
      Policies:
        - DynamoDBCrudPolicy:
            TableName: !Ref PublisherBackendDataTable
'''
      : '';
  final dataTableOutput = usesDynamoDb
      ? '''
  PublisherBackendDataTableName:
    Description: DynamoDB table used by the publisher backend.
    Value: !Ref PublisherBackendDataTable
'''
      : '';
  return '''
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: Publisher-owned business API backend for $title.

Parameters:
  StageName:
    Type: String
    Default: prod
    Description: API Gateway stage name.

Globals:
  Function:
    Runtime: nodejs24.x
    Timeout: 8
    MemorySize: 256
    Architectures:
      - arm64

Resources:
  PublisherBackendHttpApi:
    Type: AWS::Serverless::HttpApi
    Properties:
      StageName: !Ref StageName
      CorsConfiguration:
        AllowOrigins:
          - '*'
        AllowMethods:
          - GET
          - POST
          - OPTIONS
        AllowHeaders:
          - content-type
          - x-mini-program-access-key
          - x-mini-program-app-id
          - x-mini-program-host-app
          - x-mini-program-host-version
          - x-mini-program-id
          - x-mini-program-sdk-version
          - x-mini-program-platform
          - x-mini-program-locale

$dataTableResource  PublisherBackendFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: src/
      Handler: handler.handler
      Description: Publisher-owned mini-program business API.
$functionEnvironment$functionPolicies      Events:
        ProxyApi:
          Type: HttpApi
          Properties:
            ApiId: !Ref PublisherBackendHttpApi
            Path: /{proxy+}
            Method: ANY

Outputs:
  PublisherBackendBaseUrl:
    Description: Base URL for MiniProgramBackendEndpoint.baseUri.
    Value: !Sub 'https://\${PublisherBackendHttpApi}.execute-api.\${AWS::Region}.amazonaws.com/\${StageName}/'
  PublisherBackendHealthUrl:
    Description: Publisher backend health URL.
    Value: !Sub 'https://\${PublisherBackendHttpApi}.execute-api.\${AWS::Region}.amazonaws.com/\${StageName}/health'
  PublisherBackendFunctionName:
    Description: Publisher backend Lambda function name.
    Value: !Ref PublisherBackendFunction
  PublisherBackendStackName:
    Description: Publisher backend CloudFormation stack name.
    Value: !Ref AWS::StackName
  PublisherBackendStorageMode:
    Description: Publisher backend storage mode.
    Value: $storageMode
$dataTableOutput''';
}

String _awsLambdaReadme(String appId, String title, String storageMode) {
  final usesDynamoDb = storageMode == _publisherBackendStorageDynamoDb;
  final storageSection = usesDynamoDb
      ? '''
Storage mode: DynamoDB.

After deploying the stack, seed the starter data into DynamoDB:

```powershell
miniprogram publisher-backend aws seed --env <env-name>
miniprogram publisher-backend aws data status --env <env-name>
miniprogram publisher-backend aws data export --env <env-name> --include-redemptions
miniprogram publisher-backend aws data import --env <env-name> --input <export-file> --dry-run --include-redemptions
miniprogram publisher-backend aws data redemptions --env <env-name> --coupon-id coupon-10
miniprogram publisher-backend aws smoke --env <env-name> --include-write
```

The DynamoDB table is owned by this SAM stack. `aws destroy --yes` checks for
stack-owned DynamoDB data and requires `--confirm-data-loss` when app records or
redemptions exist. Seed retries unprocessed DynamoDB batch writes; data status
counts paginated app and redemption records. Export production data before stack
cleanup or migration.
'''
      : '''
Storage mode: bundled JSON.

The sample Lambda returns bundled JSON from `src/data/`. To create a persistent
DynamoDB starter instead, re-run scaffold with:

```powershell
miniprogram publisher-backend scaffold --template aws-lambda --storage dynamodb
```
''';
  return '''
# $title AWS Lambda publisher backend

This backend is for publisher-owned business APIs. It is not the mini-program
delivery backend. Host apps only receive the resulting `backendBaseUrl`; AWS
secrets and future database credentials stay on the publisher server.

$storageSection

Routes:

- `GET /health`
- `GET /home/bootstrap`
- `GET /coupons/list`
- `GET /auth/session`
- `POST /coupon/redeem`
- `OPTIONS *`

Deploy from the mini-program root:

```powershell
miniprogram publisher-backend aws deploy --env <env-name>
```

Deploy waits for the health endpoint with cold-start-aware retries. The default
smoke command is read-only; add `--include-write` only when you want to verify
`POST /coupon/redeem`.

After deploy, connect a host endpoint with:

```powershell
miniprogram host endpoint add $appId `
  --api-base-url <delivery-url> `
  --public `
  --backend-base-url <PublisherBackendBaseUrl>
```

Do not put publisher backend secrets in mini-program JSON, host source, APK,
IPA, or web JavaScript.
''';
}

String _awsLambdaPackageJson(String appId, String storageMode) {
  final dependencies = storageMode == _publisherBackendStorageDynamoDb
      ? ''',
  "dependencies": {
    "@aws-sdk/client-dynamodb": "$_awsSdkJavaScriptV3Version",
    "@aws-sdk/lib-dynamodb": "$_awsSdkJavaScriptV3Version"
  }'''
      : '';
  return '''
{
  "name": "${appId}_aws_publisher_backend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "description": "AWS Lambda publisher backend starter for $appId"$dependencies
}
''';
}

String _awsLambdaHandlerSource() => r'''
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = dirname(fileURLToPath(import.meta.url));
const dataRoot = join(currentDir, 'data');
const storageMode = process.env.PUBLISHER_BACKEND_STORAGE ?? 'bundled';
const miniProgramId = process.env.MINI_PROGRAM_ID ?? 'mini_program';

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-allow-headers':
    'content-type, x-mini-program-access-key, x-mini-program-app-id, x-mini-program-host-app, x-mini-program-host-version, x-mini-program-id, x-mini-program-sdk-version, x-mini-program-platform, x-mini-program-locale',
  'content-type': 'application/json; charset=utf-8',
};

let testStore = null;
let cachedStore = null;

export function setPublisherBackendStoreForTesting(store) {
  testStore = store;
  cachedStore = null;
}

export async function handler(event) {
  const method = event.requestContext?.http?.method ?? event.httpMethod ?? 'GET';
  const path = normalizePath(
    event.rawPath ?? event.path ?? '/',
    event.requestContext?.stage,
  );

  if (method === 'OPTIONS') {
    return {
      statusCode: 204,
      headers: corsHeaders,
      body: '',
    };
  }

  const store = await resolveStore();

  if (method === 'GET' && path === '/health') {
    return json(200, {
      status: 'ok',
      service: 'mini_program_aws_publisher_backend',
      storageMode,
      generatedAtUtc: new Date().toISOString(),
    });
  }

  if (method === 'GET' && path === '/home/bootstrap') {
    return jsonFromStore(await store.homeBootstrap(), 'home/bootstrap');
  }

  if (method === 'GET' && path === '/coupons/list') {
    return jsonFromStore(await store.couponsList(), 'coupons/list');
  }

  if (method === 'GET' && path === '/auth/session') {
    return jsonFromStore(await store.authSession(), 'auth/session');
  }

  if (method === 'POST' && path === '/coupon/redeem') {
    const body = parseJsonBody(event.body, event.isBase64Encoded);
    const result = await store.redeemCoupon(body);
    return json(result.statusCode, result.body);
  }

  return json(404, {
    errorCode: 'not_found',
    message: `No publisher backend route matches ${path}.`,
  });
}

async function resolveStore() {
  if (testStore) {
    return testStore;
  }
  if (cachedStore) {
    return cachedStore;
  }
  cachedStore =
    storageMode === 'dynamodb'
      ? await createDynamoDbStore()
      : new BundledJsonStore(dataRoot);
  return cachedStore;
}

function jsonFromStore(body, label) {
  if (body == null) {
    return json(404, {
      errorCode: 'backend_data_missing',
      message: `Backend data was not found: ${label}`,
    });
  }
  return json(200, body);
}

class BundledJsonStore {
  constructor(root) {
    this.root = root;
  }

  homeBootstrap() {
    return this.dataFile('home_bootstrap.json');
  }

  couponsList() {
    return this.dataFile('coupons_list.json');
  }

  authSession() {
    return this.dataFile('session.json');
  }

  async redeemCoupon(body) {
    return {
      statusCode: body?.couponId ? 200 : 400,
      body: body?.couponId
        ? {
            status: 'redeemed',
            couponId: body.couponId,
            message:
              'AWS sample redeem succeeded. Use --storage dynamodb for persistent redemptions.',
          }
        : {
            errorCode: 'missing_coupon_id',
            message: 'couponId is required.',
          },
    };
  }

  async dataFile(fileName) {
    try {
      const raw = await readFile(join(this.root, fileName), 'utf8');
      return JSON.parse(raw);
    } catch (error) {
      return null;
    }
  }
}

async function createDynamoDbStore() {
  const tableName = process.env.PUBLISHER_BACKEND_TABLE_NAME;
  if (!tableName) {
    throw new Error('PUBLISHER_BACKEND_TABLE_NAME is required for DynamoDB storage.');
  }
  const [{ DynamoDBClient }, dynamodbLib] = await Promise.all([
    import('@aws-sdk/client-dynamodb'),
    import('@aws-sdk/lib-dynamodb'),
  ]);
  const docClient = dynamodbLib.DynamoDBDocumentClient.from(
    new DynamoDBClient({}),
  );
  return new DynamoDbStore({
    docClient,
    tableName,
    appId: miniProgramId,
    commands: dynamodbLib,
  });
}

class DynamoDbStore {
  constructor({ docClient, tableName, appId, commands }) {
    this.docClient = docClient;
    this.tableName = tableName;
    this.appPk = `APP#${appId}`;
    this.redemptionsPk = `APP#${appId}#REDEMPTIONS`;
    this.GetCommand = commands.GetCommand;
    this.PutCommand = commands.PutCommand;
    this.QueryCommand = commands.QueryCommand;
  }

  homeBootstrap() {
    return this.payloadFor('HOME#bootstrap');
  }

  async couponsList() {
    const items = [];
    let exclusiveStartKey;
    do {
      const response = await this.docClient.send(
        new this.QueryCommand({
          TableName: this.tableName,
          KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
          ExpressionAttributeValues: {
            ':pk': this.appPk,
            ':prefix': 'COUPON#',
          },
          ConsistentRead: true,
          ExclusiveStartKey: exclusiveStartKey,
        }),
      );
      items.push(...(response.Items ?? []));
      exclusiveStartKey = response.LastEvaluatedKey;
    } while (exclusiveStartKey);
    const coupons = items
      .sort((left, right) => (left.sortIndex ?? 0) - (right.sortIndex ?? 0))
      .map((item) => item.payload)
      .filter((item) => item != null);
    return { coupons };
  }

  authSession() {
    return this.payloadFor('SESSION#demo');
  }

  async redeemCoupon(body) {
    const couponId = body?.couponId?.toString()?.trim();
    if (!couponId) {
      return {
        statusCode: 400,
        body: {
          errorCode: 'missing_coupon_id',
          message: 'couponId is required.',
        },
      };
    }

    const coupon = await this.payloadFor(`COUPON#${couponId}`);
    if (coupon == null) {
      return {
        statusCode: 404,
        body: {
          errorCode: 'coupon_not_found',
          couponId,
          message: `Coupon was not found: ${couponId}`,
        },
      };
    }

    const userId =
      body?.userId?.toString()?.trim() ||
      body?.user?.id?.toString()?.trim() ||
      'anonymous';
    const redeemedAtUtc = new Date().toISOString();
    const redemption = {
      status: 'redeemed',
      couponId,
      userId,
      redeemedAtUtc,
    };

    try {
      await this.docClient.send(
        new this.PutCommand({
          TableName: this.tableName,
          Item: {
            pk: this.redemptionsPk,
            sk: `USER#${userId}#COUPON#${couponId}`,
            recordType: 'redemption',
            couponId,
            userId,
            payload: redemption,
            createdAtUtc: redeemedAtUtc,
          },
          ConditionExpression: 'attribute_not_exists(pk) AND attribute_not_exists(sk)',
        }),
      );
      return {
        statusCode: 200,
        body: {
          ...redemption,
          message: 'Coupon redeemed.',
        },
      };
    } catch (error) {
      if (error?.name === 'ConditionalCheckFailedException') {
        return {
          statusCode: 200,
          body: {
            status: 'already_redeemed',
            couponId,
            userId,
            message: 'Coupon was already redeemed for this user.',
          },
        };
      }
      throw error;
    }
  }

  async payloadFor(sk) {
    const response = await this.docClient.send(
      new this.GetCommand({
        TableName: this.tableName,
        Key: {
          pk: this.appPk,
          sk,
        },
        ConsistentRead: true,
      }),
    );
    return response.Item?.payload ?? null;
  }
}

function parseJsonBody(rawBody, isBase64Encoded) {
  if (!rawBody) {
    return {};
  }
  const decoded = isBase64Encoded
    ? Buffer.from(rawBody, 'base64').toString('utf8')
    : rawBody;
  try {
    return JSON.parse(decoded);
  } catch (_) {
    return {};
  }
}

function normalizePath(rawPath, stage) {
  let value = rawPath.replace(/\/+$/g, '');
  if (stage && stage !== '$default') {
    const stagePrefix = `/${stage}`;
    if (value === stagePrefix) {
      value = '/';
    } else if (value.startsWith(`${stagePrefix}/`)) {
      value = value.substring(stagePrefix.length);
    }
  }
  return value.length === 0 ? '/' : value;
}

function json(statusCode, body) {
  return {
    statusCode,
    headers: corsHeaders,
    body: JSON.stringify(body, null, 2),
  };
}
''';

String _defaultAwsPublisherBackendStackName(
  String appId,
  String environmentName,
) {
  final safeAppId = _safeAwsSegment(appId);
  final safeEnv = _safeAwsSegment(environmentName);
  return 'mini-program-publisher-backend-$safeAppId-$safeEnv';
}

String _appPartitionKey(String appId) => 'APP#$appId';

String _redemptionsPartitionKey(String appId) => 'APP#$appId#REDEMPTIONS';

String _safeAwsSegment(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'default' : normalized;
}

String _safeNodePackageSegment(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
  return normalized.isEmpty ? 'mini-program' : normalized;
}

String? _readManifestIdSync(String miniProgramRootPath) {
  try {
    final file = File(p.join(miniProgramRootPath, 'manifest.json'));
    if (!file.existsSync()) {
      return null;
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map) {
      final id = decoded['id']?.toString().trim();
      return id == null || id.isEmpty ? null : id;
    }
  } catch (_) {
    return null;
  }
  return null;
}

String _titleFromAppId(String appId) => appId
    .split(RegExp(r'[_-]+'))
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

String _prettyJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);
