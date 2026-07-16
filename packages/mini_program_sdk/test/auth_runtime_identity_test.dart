import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('auth models preserve ordering, redaction, and expiry boundaries', () {
    final now = DateTime.utc(2026, 7, 16, 12);
    final session = _session(
      appId: ' weather ',
      idToken: ' id-token ',
      refreshToken: ' refresh-token ',
      expiresAtUtc: now.add(const Duration(seconds: 30)),
    );
    final decoded = MiniProgramAuthSession.fromJson(session.toJson());

    expect(decoded.toJson().keys, <String>[
      'miniProgramId',
      'user',
      'idToken',
      'refreshToken',
      'expiresAtUtc',
    ]);
    expect(decoded.toBindingData().keys, <String>[
      'miniProgramId',
      'user',
      'expiresAtUtc',
    ]);
    expect(decoded.miniProgramId, 'weather');
    expect(decoded.idToken, 'id-token');
    expect(decoded.refreshToken, 'refresh-token');
    expect(decoded.isExpired(nowUtc: now), isTrue);
    expect(decoded.isExpired(nowUtc: now, skew: Duration.zero), isFalse);

    final snapshot = MiniProgramAuthSnapshot.fromSession(decoded);
    expect(snapshot.toBindingData().keys, <String>[
      'status',
      'authenticated',
      'loading',
      'signedOut',
      'error',
      'user',
      'expiresAtUtc',
    ]);
    final result = MiniProgramAuthResult(
      success: true,
      snapshot: snapshot,
      message: 'Signed in',
      statusCode: 200,
    );
    expect(result.toJson().keys, <String>[
      'success',
      'authenticated',
      'status',
      'message',
      'statusCode',
      'auth',
    ]);
    final bindingJson = jsonEncode(<String, dynamic>{
      'session': decoded.toBindingData(),
      'result': result.toJson(),
    });
    expect(bindingJson, isNot(contains('id-token')));
    expect(bindingJson, isNot(contains('refresh-token')));
  });

  test('backend session expiry parsing preserves precedence and fallback', () {
    final now = DateTime.utc(2026, 7, 16, 12);
    final explicit = MiniProgramAuthSession.fromBackendData(
      miniProgramId: 'weather',
      data: <String, dynamic>{
        ..._backendData(),
        'expiresAtUtc': '2026-07-17T09:30:00+03:00',
        'expiresIn': 1,
      },
      nowUtc: now,
    );
    final fallback = MiniProgramAuthSession.fromBackendData(
      miniProgramId: 'weather',
      data: <String, dynamic>{
        ..._backendData(),
        'expiresAtUtc': 'not-a-date',
        'expiresIn': '120',
      },
      nowUtc: now,
    );

    expect(explicit.expiresAtUtc, DateTime.utc(2026, 7, 17, 6, 30));
    expect(fallback.expiresAtUtc, now.add(const Duration(minutes: 2)));
  });

  test(
    'secure store preserves key encoding and removes invalid sessions',
    () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      const platformStorage = FlutterSecureStorage();
      final store = SecureMiniProgramAuthStore(storage: platformStorage);
      final session = _session(appId: 'weather');

      await store.write(' weather ', session);
      final raw = await platformStorage.read(
        key: 'mini_program_auth_session::d2VhdGhlcg==',
      );
      expect(raw, isNotNull);
      expect((jsonDecode(raw!) as Map<String, dynamic>).keys, <String>[
        'miniProgramId',
        'user',
        'idToken',
        'refreshToken',
        'expiresAtUtc',
      ]);
      expect((await store.read('weather'))?.idToken, 'id-token');

      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'mini_program_auth_session::d2VhdGhlcg==':
            '{"miniProgramId":"weather"}',
      });
      final invalidStore = SecureMiniProgramAuthStore();
      expect(await invalidStore.read('weather'), isNull);
      expect(
        await const FlutterSecureStorage().read(
          key: 'mini_program_auth_session::d2VhdGhlcg==',
        ),
        isNull,
      );
    },
  );

  test('secure store preserves malformed JSON failure behavior', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'mini_program_auth_session::d2VhdGhlcg==': '{invalid',
    });

    expect(
      () => SecureMiniProgramAuthStore().read('weather'),
      throwsA(isA<FormatException>()),
    );
  });

  test('sign-in notifies loading before the signed-in snapshot', () async {
    final controller = MiniProgramAuthController(
      store: InMemoryMiniProgramAuthStore(),
      clock: _now,
    );
    final statuses = <MiniProgramAuthStatus>[];
    controller.addListener(() {
      statuses.add(controller.snapshot('weather').status);
    });

    final result = await controller.signInEmail(
      miniProgramId: 'weather',
      connector: _AuthConnector((_) => _authResult(appId: 'weather')),
      email: ' user@example.com ',
      password: 'secret',
    );

    expect(result.success, isTrue);
    expect(statuses, <MiniProgramAuthStatus>[
      MiniProgramAuthStatus.signingIn,
      MiniProgramAuthStatus.signedIn,
    ]);
  });

  test('expired restore notifies restore, refresh, then signed in', () async {
    final store = InMemoryMiniProgramAuthStore();
    await store.write(
      'weather',
      _session(
        appId: 'weather',
        expiresAtUtc: _now().subtract(const Duration(seconds: 1)),
      ),
    );
    final controller = MiniProgramAuthController(store: store, clock: _now);
    final statuses = <MiniProgramAuthStatus>[];
    controller.addListener(() {
      statuses.add(controller.snapshot('weather').status);
    });

    await controller.restore(
      miniProgramId: 'weather',
      connector: _AuthConnector(
        (_) => _authResult(appId: 'weather', idToken: 'refreshed-token'),
      ),
    );

    expect(statuses, <MiniProgramAuthStatus>[
      MiniProgramAuthStatus.restoring,
      MiniProgramAuthStatus.refreshing,
      MiniProgramAuthStatus.signedIn,
    ]);
    expect(controller.session('weather')?.idToken, 'refreshed-token');
  });

  test('auth sessions and authorization remain isolated by app ID', () async {
    final controller = MiniProgramAuthController(
      store: InMemoryMiniProgramAuthStore(),
      clock: _now,
    );
    await controller.signInEmail(
      miniProgramId: 'weather',
      connector: _AuthConnector(
        (_) => _authResult(appId: 'weather', idToken: 'weather-token'),
      ),
      email: 'weather@example.com',
      password: 'secret',
    );
    await controller.signInEmail(
      miniProgramId: 'orders',
      connector: _AuthConnector(
        (_) => _authResult(appId: 'orders', idToken: 'orders-token'),
      ),
      email: 'orders@example.com',
      password: 'secret',
    );

    final weather = await controller.authorizeRequest(
      request: const MiniProgramBackendRequest(
        miniProgramId: 'weather',
        endpoint: 'forecast',
      ),
      connector: null,
    );
    final orders = await controller.authorizeRequest(
      request: const MiniProgramBackendRequest(
        miniProgramId: 'orders',
        endpoint: 'history',
      ),
      connector: null,
    );

    expect(weather.headers['authorization'], 'Bearer weather-token');
    expect(orders.headers['authorization'], 'Bearer orders-token');
    expect(controller.session('weather')?.miniProgramId, 'weather');
    expect(controller.session('orders')?.miniProgramId, 'orders');
  });

  test(
    'authorization refreshes expired sessions and overwrites auth header',
    () async {
      final store = InMemoryMiniProgramAuthStore();
      await store.write(
        'weather',
        _session(
          appId: 'weather',
          idToken: 'expired-token',
          expiresAtUtc: _now().subtract(const Duration(minutes: 1)),
        ),
      );
      final controller = MiniProgramAuthController(store: store, clock: _now);

      final request = await controller.authorizeRequest(
        request: const MiniProgramBackendRequest(
          miniProgramId: 'weather',
          endpoint: 'forecast',
          headers: <String, String>{
            'authorization': 'Bearer caller-token',
            'x-request': 'preserved',
          },
        ),
        connector: _AuthConnector((request) {
          expect(request.endpoint, 'auth/refresh');
          expect(request.body['refreshToken'], 'refresh-token');
          return _authResult(appId: 'weather', idToken: 'new-token');
        }),
      );

      expect(request.headers, <String, String>{
        'authorization': 'Bearer new-token',
        'x-request': 'preserved',
      });
    },
  );

  test('sign-out clears local session before calling the backend', () async {
    final store = InMemoryMiniProgramAuthStore();
    await store.write('weather', _session(appId: 'weather'));
    final controller = MiniProgramAuthController(store: store, clock: _now);
    await controller.restore(miniProgramId: 'weather', connector: null);

    final result = await controller.signOut(
      miniProgramId: 'weather',
      connector: _AuthConnector((request) async {
        expect(await store.read('weather'), isNull);
        expect(controller.session('weather'), isNull);
        expect(request.endpoint, 'auth/sign-out');
        return MiniProgramBackendResult.failed(statusCode: 503);
      }),
    );

    expect(result.success, isTrue);
    expect(controller.snapshot('weather').signedOut, isTrue);
  });

  test('restore retains virtual refresh dispatch for subclasses', () async {
    final store = InMemoryMiniProgramAuthStore();
    await store.write(
      'weather',
      _session(
        appId: 'weather',
        expiresAtUtc: _now().subtract(const Duration(minutes: 1)),
      ),
    );
    final controller = _RefreshOverrideController(store);

    final result = await controller.restore(
      miniProgramId: 'weather',
      connector: _AuthConnector((_) => _authResult(appId: 'weather')),
    );

    expect(controller.refreshCalls, 1);
    expect(result.success, isFalse);
    expect(result.message, 'overridden');
  });

  test('auth public types remain available from the SDK barrel', () {
    expect(const MiniProgramAuthBackendPaths(), isNotNull);
    expect(MiniProgramAuthHttpHeaders.authorization, 'authorization');
    expect(const MiniProgramAuthUser(uid: 'user'), isNotNull);
    expect(MiniProgramAuthStatus.values, hasLength(8));
    expect(InMemoryMiniProgramAuthStore(), isA<MiniProgramAuthStore>());
    expect(
      MiniProgramAuthController.inMemory(),
      isA<MiniProgramAuthController>(),
    );
  });
}

DateTime _now() => DateTime.utc(2026, 7, 16, 12);

MiniProgramAuthSession _session({
  required String appId,
  String idToken = 'id-token',
  String refreshToken = 'refresh-token',
  DateTime? expiresAtUtc,
}) {
  return MiniProgramAuthSession(
    miniProgramId: appId,
    user: const MiniProgramAuthUser(uid: 'user-1', email: 'user@example.com'),
    idToken: idToken,
    refreshToken: refreshToken,
    expiresAtUtc: expiresAtUtc ?? _now().add(const Duration(hours: 1)),
  );
}

Map<String, dynamic> _backendData({
  String idToken = 'id-token',
  String refreshToken = 'refresh-token',
}) {
  return <String, dynamic>{
    'authenticated': true,
    'user': <String, dynamic>{'uid': 'user-1', 'email': 'user@example.com'},
    'idToken': idToken,
    'refreshToken': refreshToken,
  };
}

MiniProgramBackendResult _authResult({
  required String appId,
  String idToken = 'id-token',
}) {
  return MiniProgramBackendResult.success(
    endpoint: 'auth/email/sign-in',
    method: 'POST',
    statusCode: 200,
    data: <String, dynamic>{
      ..._backendData(idToken: idToken),
      'expiresIn': 3600,
    },
  );
}

class _AuthConnector implements MiniProgramBackendConnector {
  const _AuthConnector(this.handler);

  final FutureOr<MiniProgramBackendResult> Function(
    MiniProgramBackendRequest request,
  )
  handler;

  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    return handler(request);
  }
}

class _RefreshOverrideController extends MiniProgramAuthController {
  _RefreshOverrideController(MiniProgramAuthStore store)
    : super(store: store, clock: _now);

  int refreshCalls = 0;

  @override
  Future<MiniProgramAuthResult> refresh({
    required String miniProgramId,
    required MiniProgramBackendConnector connector,
  }) async {
    refreshCalls++;
    const snapshot = MiniProgramAuthSnapshot.signedOut();
    return const MiniProgramAuthResult(
      success: false,
      snapshot: snapshot,
      message: 'overridden',
    );
  }
}
