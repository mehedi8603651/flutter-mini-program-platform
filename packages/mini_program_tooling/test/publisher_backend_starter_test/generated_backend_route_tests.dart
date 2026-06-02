part of '../publisher_backend_starter_test.dart';

void _registerGeneratedBackendRouteTests() {
  test(
    'generated Firebase router serves read and redeem routes with fake store',
    () async {
      final nodeVersion = await Process.run('node', <String>['--version']);
      if (nodeVersion.exitCode != 0) {
        markTestSkipped('Node.js is not available.');
      }
      final starter = const PublisherBackendStarter();
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );
      final routerUri = Uri.file(
        p.join(
          miniProgramRoot.path,
          'backend',
          'firebase_functions',
          'functions',
          'router.js',
        ),
      ).toString();

      final result = await _runNodeScript(tempDir, '''
import { createPublisherBackendHandler } from '$routerUri';

const coupons = new Set(['coupon-10']);
const redemptions = new Set();
const handler = createPublisherBackendHandler({
  clock: () => new Date('2026-05-23T12:00:00.000Z'),
  store: {
    homeBootstrap: async () => ({ title: 'Firebase home' }),
    couponsList: async () => ({ coupons: [{ id: 'coupon-10', title: 'Ten' }] }),
    redeemCoupon: async ({ couponId, userId }) => {
      if (!coupons.has(couponId)) {
        return { statusCode: 404, body: { errorCode: 'coupon_not_found' } };
      }
      const key = userId + ':' + couponId;
      if (redemptions.has(key)) {
        return { statusCode: 200, body: { status: 'already_redeemed', couponId, userId } };
      }
      redemptions.add(key);
      return { statusCode: 200, body: { status: 'redeemed', couponId, userId } };
    },
  },
  authService: {
    currentSession: async ({ authorizationHeader }) =>
      authorizationHeader === 'Bearer valid-token'
        ? { statusCode: 200, body: { authenticated: true, user: { uid: 'user-1', email: 'user@example.com' } } }
        : { statusCode: 401, body: { errorCode: 'auth_required' } },
    signUpEmail: async ({ email }) => ({
      statusCode: 200,
      body: {
        authenticated: true,
        user: { uid: 'user-1', email },
        idToken: 'id-token-1',
        refreshToken: 'refresh-token-1',
        expiresIn: 3600,
      },
    }),
    signInEmail: async ({ email }) => ({
      statusCode: 200,
      body: {
        authenticated: true,
        user: { uid: 'user-1', email },
        idToken: 'id-token-2',
        refreshToken: 'refresh-token-2',
        expiresIn: 3600,
      },
    }),
    refresh: async () => ({
      statusCode: 200,
      body: {
        authenticated: true,
        user: { uid: 'user-1', email: 'user@example.com' },
        idToken: 'id-token-3',
        refreshToken: 'refresh-token-3',
        expiresIn: 3600,
      },
    }),
    signOut: async () => ({ statusCode: 200, body: { status: 'signed_out' } }),
  },
});

async function call(method, path, body, headers = {}) {
  const response = {
    statusCode: 200,
    headers: {},
    setHeader(name, value) { this.headers[name] = value; },
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; },
    end(body) { this.body = body ? JSON.parse(body) : null; },
  };
  await handler({ method, path, body, headers }, response);
  return { statusCode: response.statusCode, body: response.body };
}

const health = await call('GET', '/health');
const home = await call('GET', '/home/bootstrap');
const couponsList = await call('GET', '/coupons/list');
const couponsPage = await call('GET', '/coupons/page?limit=1');
const missingSession = await call('GET', '/auth/session');
const session = await call('GET', '/auth/session', null, { authorization: 'Bearer valid-token' });
const signUp = await call('POST', '/auth/email/sign-up', { email: 'user@example.com', password: 'secret123' });
const signIn = await call('POST', '/auth/email/sign-in', { email: 'user@example.com', password: 'secret123' });
const refreshed = await call('POST', '/auth/refresh', { refreshToken: 'refresh-token-2' });
const signedOut = await call('POST', '/auth/sign-out', { refreshToken: 'refresh-token-3' });
const missingCouponId = await call('POST', '/coupon/redeem', {});
const unknownCoupon = await call('POST', '/coupon/redeem', { couponId: 'missing' });
const redeemed = await call('POST', '/coupon/redeem', { couponId: 'coupon-10', userId: 'user-1' });
const duplicate = await call('POST', '/coupon/redeem', { couponId: 'coupon-10', userId: 'user-1' });

console.log(JSON.stringify({
  health,
  home,
  couponsList,
  couponsPage,
  missingSession,
  session,
  signUp,
  signIn,
  refreshed,
  signedOut,
  missingCouponId,
  unknownCoupon,
  redeemed,
  duplicate,
}));
''');

      expect(result.exitCode, 0, reason: result.stderr.toString());
      final decoded =
          jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      expect(decoded['health']['statusCode'], 200);
      expect(decoded['home']['body']['title'], 'Firebase home');
      expect(decoded['couponsList']['body']['coupons'], hasLength(1));
      expect(decoded['couponsPage']['body']['items'], hasLength(1));
      expect(decoded['couponsPage']['body']['hasMore'], isFalse);
      expect(decoded['missingSession']['statusCode'], 401);
      expect(decoded['session']['body']['authenticated'], isTrue);
      expect(decoded['signUp']['body']['refreshToken'], isNotEmpty);
      expect(decoded['signIn']['body']['idToken'], isNotEmpty);
      expect(decoded['refreshed']['body']['refreshToken'], 'refresh-token-3');
      expect(decoded['signedOut']['body']['status'], 'signed_out');
      expect(decoded['missingCouponId']['statusCode'], 400);
      expect(decoded['unknownCoupon']['statusCode'], 404);
      expect(decoded['redeemed']['body']['status'], 'redeemed');
      expect(decoded['duplicate']['body']['status'], 'already_redeemed');
    },
  );

  test('generated Firebase router enforces configured access keys', () async {
    final nodeVersion = await Process.run('node', <String>['--version']);
    if (nodeVersion.exitCode != 0) {
      markTestSkipped('Node.js is not available.');
    }
    final starter = const PublisherBackendStarter();
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );
    final routerUri = Uri.file(
      p.join(
        miniProgramRoot.path,
        'backend',
        'firebase_functions',
        'functions',
        'router.js',
      ),
    ).toString();

    final result = await _runNodeScript(tempDir, '''
import { createHash } from 'node:crypto';
import { createPublisherBackendHandler } from '$routerUri';

const accessKey = 'mpk_live_partner_123456789012345';
const accessKeyHash = createHash('sha256').update(accessKey, 'utf8').digest('hex');
const handler = createPublisherBackendHandler({
  clock: () => new Date('2026-06-01T00:00:00.000Z'),
  store: {
    activeAccessKeys: async () => [{
      keyId: 'host-a',
      keyHash: accessKeyHash,
      active: true,
      expiresAtUtc: '2026-06-02T00:00:00.000Z',
    }],
    homeBootstrap: async () => ({ title: 'Protected home' }),
    couponsList: async () => ({ coupons: [] }),
    redeemCoupon: async () => ({ statusCode: 200, body: { status: 'redeemed' } }),
  },
  authService: {
    currentSession: async () => ({ statusCode: 401, body: { errorCode: 'auth_required' } }),
  },
});

async function call(method, path, headers = {}) {
  const response = {
    statusCode: 200,
    headers: {},
    setHeader(name, value) { this.headers[name] = value; },
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; },
    end(body) { this.body = body ? JSON.parse(body) : null; },
  };
  await handler({ method, path, headers }, response);
  return { statusCode: response.statusCode, body: response.body };
}

const health = await call('GET', '/health');
const missing = await call('GET', '/home/bootstrap');
const invalid = await call('GET', '/home/bootstrap', { 'x-mini-program-access-key': 'mpk_live_wrong_123456789012345' });
const valid = await call('GET', '/home/bootstrap', { 'x-mini-program-access-key': accessKey });
const authGuard = await call('GET', '/auth/session', { 'x-mini-program-access-key': accessKey });

console.log(JSON.stringify({ health, missing, invalid, valid, authGuard }));
''');

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final decoded =
        jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    expect(decoded['health']['statusCode'], 200);
    expect(decoded['missing']['statusCode'], 401);
    expect(decoded['missing']['body']['errorCode'], 'access_key_required');
    expect(decoded['invalid']['statusCode'], 403);
    expect(decoded['invalid']['body']['errorCode'], 'access_key_invalid');
    expect(decoded['valid']['statusCode'], 200);
    expect(decoded['valid']['body']['title'], 'Protected home');
    expect(decoded['authGuard']['statusCode'], 401);
    expect(decoded['authGuard']['body']['errorCode'], 'auth_required');
  });

  test(
    'generated Firebase auth service creates, refreshes, verifies, and signs out sessions',
    () async {
      final nodeVersion = await Process.run('node', <String>['--version']);
      if (nodeVersion.exitCode != 0) {
        markTestSkipped('Node.js is not available.');
      }
      final starter = const PublisherBackendStarter();
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );
      final authServiceUri = Uri.file(
        p.join(
          miniProgramRoot.path,
          'backend',
          'firebase_functions',
          'functions',
          'auth_service.js',
        ),
      ).toString();
      final fakeAdminPackageRoot = Directory(
        p.join(
          miniProgramRoot.path,
          'backend',
          'firebase_functions',
          'functions',
          'node_modules',
          'firebase-admin',
        ),
      );
      await fakeAdminPackageRoot.create(recursive: true);
      await File(
        p.join(fakeAdminPackageRoot.path, 'package.json'),
      ).writeAsString(
        jsonEncode(<String, Object?>{
          'type': 'module',
          'exports': <String, Object?>{'./auth': './auth.js'},
        }),
      );
      await File(p.join(fakeAdminPackageRoot.path, 'auth.js')).writeAsString(
        'export function getAuth() { throw new Error("inject auth"); }',
      );

      final result = await _runNodeScript(tempDir, '''
import { createFirebasePublisherAuthService } from '$authServiceUri';

const sessions = new Map();
const issuedCustomTokens = new Map();
const auth = {
  createUser: async ({ email }) => ({ uid: 'uid-1', email, disabled: false }),
  getUser: async (uid) => ({ uid, email: 'user@example.com', disabled: false }),
  createCustomToken: async (uid, claims) => {
    const token = 'custom-token-' + claims.miniProgramSessionId;
    issuedCustomTokens.set(token, { uid, ...claims });
    return token;
  },
  verifyIdToken: async (idToken) => {
    const sessionId = idToken.replace('id-token-', '');
    return {
      uid: 'uid-1',
      miniProgramId: 'firebase_coupon',
      miniProgramSessionId: sessionId,
    };
  },
};
const store = {
  createAuthSession: async (session) => {
    sessions.set(session.sessionId, { ...session });
  },
  authSession: async (sessionId) => sessions.get(sessionId) ?? null,
  authSessionByRefreshTokenHash: async (hash) => {
    for (const session of sessions.values()) {
      if (session.refreshTokenHash === hash) {
        return { ...session };
      }
    }
    return null;
  },
  updateAuthSession: async ({ sessionId, ...updates }) => {
    sessions.set(sessionId, { ...sessions.get(sessionId), ...updates });
  },
  deleteAuthSession: async (sessionId) => {
    sessions.delete(sessionId);
  },
};
const fetchImpl = async (url, options) => {
  const body = JSON.parse(options.body || '{}');
  if (url.includes('accounts:signInWithPassword')) {
    return response({ localId: 'uid-1', email: body.email });
  }
  if (url.includes('accounts:signInWithCustomToken')) {
    const claims = issuedCustomTokens.get(body.token);
    return response({
      idToken: 'id-token-' + claims.miniProgramSessionId,
      refreshToken: 'firebase-refresh-token-not-returned',
      expiresIn: '3600',
    });
  }
  return response({ error: { message: 'missing route' } }, 404);
};
function response(body, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    async json() { return body; },
  };
}

const service = createFirebasePublisherAuthService({
  appId: 'firebase_coupon',
  store,
  auth,
  apiKey: 'test-api-key',
  fetchImpl,
  clock: () => new Date('2026-05-24T12:00:00.000Z'),
});

const signUp = await service.signUpEmail({
  email: 'user@example.com',
  password: 'secret123',
});
const current = await service.currentSession({
  authorizationHeader: 'Bearer ' + signUp.body.idToken,
});
const refresh = await service.refresh({
  refreshToken: signUp.body.refreshToken,
});
const refreshedCurrent = await service.currentSession({
  authorizationHeader: 'Bearer ' + refresh.body.idToken,
});
const signOut = await service.signOut({
  refreshToken: refresh.body.refreshToken,
});
const revoked = await service.currentSession({
  authorizationHeader: 'Bearer ' + refresh.body.idToken,
});
const signIn = await service.signInEmail({
  email: 'user@example.com',
  password: 'secret123',
});

console.log(JSON.stringify({
  signUpStatus: signUp.statusCode,
  signUpAuthenticated: signUp.body.authenticated,
  signUpRefreshTokenLength: signUp.body.refreshToken.length,
  currentStatus: current.statusCode,
  refreshStatus: refresh.statusCode,
  refreshRotated: refresh.body.refreshToken !== signUp.body.refreshToken,
  refreshedCurrentStatus: refreshedCurrent.statusCode,
  signOutStatus: signOut.statusCode,
  signOutStatusText: signOut.body.status,
  revokedStatus: revoked.statusCode,
  revokedCode: revoked.body.errorCode,
  signInStatus: signIn.statusCode,
  signInHasFirebaseRawRefreshToken:
    signIn.body.refreshToken === 'firebase-refresh-token-not-returned',
  sessionCount: sessions.size,
}));
''');

      expect(result.exitCode, 0, reason: result.stderr.toString());
      final decoded =
          jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      expect(decoded['signUpStatus'], 200);
      expect(decoded['signUpAuthenticated'], isTrue);
      expect(decoded['signUpRefreshTokenLength'], greaterThan(20));
      expect(decoded['currentStatus'], 200);
      expect(decoded['refreshStatus'], 200);
      expect(decoded['refreshRotated'], isTrue);
      expect(decoded['refreshedCurrentStatus'], 200);
      expect(decoded['signOutStatus'], 200);
      expect(decoded['signOutStatusText'], 'signed_out');
      expect(decoded['revokedStatus'], 401);
      expect(decoded['revokedCode'], 'auth_session_revoked');
      expect(decoded['signInStatus'], 200);
      expect(decoded['signInHasFirebaseRawRefreshToken'], isFalse);
      expect(decoded['sessionCount'], 1);
    },
  );

  test(
    'generated bundled Lambda handler serves read and redeem routes',
    () async {
      final nodeVersion = await Process.run('node', <String>['--version']);
      if (nodeVersion.exitCode != 0) {
        markTestSkipped('Node.js is not available.');
      }
      final starter = const PublisherBackendStarter();
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'aws-lambda',
        ),
      );
      final handlerUri = Uri.file(
        p.join(
          miniProgramRoot.path,
          'backend',
          'aws_lambda',
          'src',
          'handler.mjs',
        ),
      ).toString();

      final result = await _runNodeScript(tempDir, '''
import { handler } from '$handlerUri';

const event = (method, path, body, queryStringParameters = undefined) => ({
  rawPath: `/prod\${path}`,
  requestContext: { stage: 'prod', http: { method } },
  queryStringParameters,
  body: body == null ? undefined : JSON.stringify(body),
});

const home = await handler(event('GET', '/home/bootstrap'));
const coupons = await handler(event('GET', '/coupons/list'));
const couponPage = await handler(event('GET', '/coupons/page', null, { limit: '1' }));
const session = await handler(event('GET', '/auth/session'));
const redeemed = await handler(event('POST', '/coupon/redeem', { couponId: 'coupon-10' }));
console.log(JSON.stringify({
  homeStatus: home.statusCode,
  homeTitle: JSON.parse(home.body).title,
  couponsStatus: coupons.statusCode,
  couponCount: JSON.parse(coupons.body).coupons.length,
  couponPageStatus: couponPage.statusCode,
  couponPage: JSON.parse(couponPage.body),
  sessionStatus: session.statusCode,
  redeemStatus: redeemed.statusCode,
  redeemBody: JSON.parse(redeemed.body),
}));
''');

      expect(result.exitCode, 0, reason: result.stderr.toString());
      final decoded =
          jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      expect(decoded['homeStatus'], 200);
      expect(decoded['homeTitle'], contains('Coupon App'));
      expect(decoded['couponCount'], 2);
      expect(decoded['couponPageStatus'], 200);
      expect(decoded['couponPage']['items'], hasLength(1));
      expect(decoded['couponPage']['hasMore'], isTrue);
      expect(decoded['couponPage']['nextCursor'], 'coupon-10');
      expect(decoded['sessionStatus'], 200);
      expect(decoded['redeemStatus'], 200);
      expect(decoded['redeemBody']['status'], 'redeemed');
    },
  );

  test(
    'generated Lambda handler supports an injected DynamoDB store',
    () async {
      final nodeVersion = await Process.run('node', <String>['--version']);
      if (nodeVersion.exitCode != 0) {
        markTestSkipped('Node.js is not available.');
      }
      final starter = const PublisherBackendStarter();
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'aws-lambda',
          storageMode: 'dynamodb',
        ),
      );
      final handlerUri = Uri.file(
        p.join(
          miniProgramRoot.path,
          'backend',
          'aws_lambda',
          'src',
          'handler.mjs',
        ),
      ).toString();

      final result = await _runNodeScript(tempDir, '''
import { handler, setPublisherBackendStoreForTesting } from '$handlerUri';

setPublisherBackendStoreForTesting({
  homeBootstrap: async () => ({ title: 'Dynamo home' }),
  couponsList: async () => ({
    coupons: [
      { id: 'coupon-10', title: 'Ten' },
      { id: 'coupon-20', title: 'Twenty' },
    ],
  }),
  authSession: async () => ({ authenticated: true }),
  redeemCoupon: async (body) => body?.couponId
    ? { statusCode: 200, body: { status: 'redeemed', couponId: body.couponId } }
    : { statusCode: 400, body: { errorCode: 'missing_coupon_id' } },
});

const event = (method, path, body, queryStringParameters = undefined) => ({
  rawPath: `/prod\${path}`,
  requestContext: { stage: 'prod', http: { method } },
  queryStringParameters,
  body: body == null ? undefined : JSON.stringify(body),
});
const home = await handler(event('GET', '/home/bootstrap'));
const page = await handler(event('GET', '/coupons/page', null, { limit: '1', cursor: 'coupon-10' }));
const redeemed = await handler(event('POST', '/coupon/redeem', { couponId: 'coupon-10' }));
const missing = await handler(event('POST', '/coupon/redeem', {}));
console.log(JSON.stringify({
  home: JSON.parse(home.body),
  page: JSON.parse(page.body),
  redeemedStatus: redeemed.statusCode,
  redeemed: JSON.parse(redeemed.body),
  missingStatus: missing.statusCode,
}));
''');

      expect(result.exitCode, 0, reason: result.stderr.toString());
      final decoded =
          jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      expect(decoded['home']['title'], 'Dynamo home');
      expect(decoded['page']['items'], hasLength(1));
      expect(decoded['page']['items'][0]['id'], 'coupon-20');
      expect(decoded['page']['hasMore'], isFalse);
      expect(decoded['redeemedStatus'], 200);
      expect(decoded['redeemed']['couponId'], 'coupon-10');
      expect(decoded['missingStatus'], 400);
    },
  );
}
