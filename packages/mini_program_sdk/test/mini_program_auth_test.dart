import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('MiniProgram auth models and store', () {
    test('session JSON/storage round trip redacts binding data', () async {
      final session = _session();
      final decoded = MiniProgramAuthSession.fromJson(session.toJson());
      expect(decoded.miniProgramId, 'coupon');
      expect(decoded.user.uid, 'user-1');
      expect(decoded.idToken, 'id-token');

      final binding = decoded.toBindingData();
      expect(binding.toString(), isNot(contains('id-token')));
      expect(binding.toString(), isNot(contains('refresh-token')));

      final store = InMemoryMiniProgramAuthStore();
      await store.write('coupon', decoded);
      expect((await store.read('coupon'))?.user.email, 'user@example.com');
      await store.delete('coupon');
      expect(await store.read('coupon'), isNull);
    });
  });

  group('MiniProgramAuthController', () {
    test('sign-in success stores a session', () async {
      final store = InMemoryMiniProgramAuthStore();
      final controller = MiniProgramAuthController(
        store: store,
        clock: _fixedNow,
      );
      final connector = _AuthConnector((request) {
        expect(request.endpoint, 'auth/email/sign-in');
        expect(request.body['email'], 'user@example.com');
        expect(request.body['password'], 'secret123');
        return _authResult();
      });

      final result = await controller.signInEmail(
        miniProgramId: 'coupon',
        connector: connector,
        email: ' user@example.com ',
        password: 'secret123',
      );

      expect(result.success, isTrue);
      expect(controller.snapshot('coupon').authenticated, isTrue);
      expect((await store.read('coupon'))?.idToken, 'id-token');
      expect(result.toJson().toString(), isNot(contains('id-token')));
    });

    test('sign-up success stores a session', () async {
      final controller = MiniProgramAuthController(
        store: InMemoryMiniProgramAuthStore(),
        clock: _fixedNow,
      );
      final connector = _AuthConnector((request) {
        expect(request.endpoint, 'auth/email/sign-up');
        return _authResult();
      });

      final result = await controller.signUpEmail(
        miniProgramId: 'coupon',
        connector: connector,
        email: 'user@example.com',
        password: 'secret123',
      );

      expect(result.success, isTrue);
      expect(controller.session('coupon')?.refreshToken, 'refresh-token');
    });

    test('invalid auth response does not write storage', () async {
      final store = InMemoryMiniProgramAuthStore();
      final controller = MiniProgramAuthController(
        store: store,
        clock: _fixedNow,
      );
      final connector = _AuthConnector(
        (_) => MiniProgramBackendResult.success(
          endpoint: 'auth/email/sign-in',
          method: 'POST',
          data: const <String, dynamic>{'authenticated': true},
        ),
      );

      final result = await controller.signInEmail(
        miniProgramId: 'coupon',
        connector: connector,
        email: 'user@example.com',
        password: 'secret123',
      );

      expect(result.success, isFalse);
      expect(result.errorCode, 'invalid_auth_response');
      expect(await store.read('coupon'), isNull);
    });

    test('restore loads cached session', () async {
      final store = InMemoryMiniProgramAuthStore();
      await store.write('coupon', _session());
      final controller = MiniProgramAuthController(
        store: store,
        clock: _fixedNow,
      );

      final result = await controller.restore(
        miniProgramId: 'coupon',
        connector: null,
      );

      expect(result.success, isTrue);
      expect(controller.snapshot('coupon').authenticated, isTrue);
      expect(controller.session('coupon')?.idToken, 'id-token');
    });

    test('expired restore refreshes session', () async {
      final store = InMemoryMiniProgramAuthStore();
      await store.write(
        'coupon',
        _session(
          expiresAtUtc: _fixedNow().subtract(const Duration(minutes: 1)),
        ),
      );
      final controller = MiniProgramAuthController(
        store: store,
        clock: _fixedNow,
      );
      final connector = _AuthConnector((request) {
        expect(request.endpoint, 'auth/refresh');
        expect(request.body['refreshToken'], 'refresh-token');
        return _authResult(idToken: 'new-id-token');
      });

      final result = await controller.restore(
        miniProgramId: 'coupon',
        connector: connector,
      );

      expect(result.success, isTrue);
      expect((await store.read('coupon'))?.idToken, 'new-id-token');
    });

    test('failed refresh clears expired cache', () async {
      final store = InMemoryMiniProgramAuthStore();
      await store.write(
        'coupon',
        _session(
          expiresAtUtc: _fixedNow().subtract(const Duration(minutes: 1)),
        ),
      );
      final controller = MiniProgramAuthController(
        store: store,
        clock: _fixedNow,
      );
      final connector = _AuthConnector(
        (_) => MiniProgramBackendResult.failed(
          statusCode: 401,
          message: 'refresh failed',
          errorCode: 'auth_refresh_failed',
        ),
      );

      final result = await controller.restore(
        miniProgramId: 'coupon',
        connector: connector,
      );

      expect(result.success, isFalse);
      expect(await store.read('coupon'), isNull);
      expect(controller.snapshot('coupon').hasError, isTrue);
    });

    test('sign-out clears cache even when backend fails', () async {
      final store = InMemoryMiniProgramAuthStore();
      await store.write('coupon', _session());
      final controller = MiniProgramAuthController(
        store: store,
        clock: _fixedNow,
      );
      await controller.restore(miniProgramId: 'coupon', connector: null);
      final connector = _AuthConnector(
        (_) => MiniProgramBackendResult.failed(statusCode: 500),
      );

      final result = await controller.signOut(
        miniProgramId: 'coupon',
        connector: connector,
      );

      expect(result.success, isTrue);
      expect(await store.read('coupon'), isNull);
      expect(controller.snapshot('coupon').signedOut, isTrue);
    });

    test('authorizes backend requests only when a session exists', () async {
      final controller = MiniProgramAuthController(
        store: InMemoryMiniProgramAuthStore(),
        clock: _fixedNow,
      );
      final request = const MiniProgramBackendRequest(
        miniProgramId: 'coupon',
        endpoint: 'profile',
      );

      final unsigned = await controller.authorizeRequest(
        request: request,
        connector: null,
      );
      expect(unsigned.headers['authorization'], isNull);

      await controller.signInEmail(
        miniProgramId: 'coupon',
        connector: _AuthConnector((_) => _authResult()),
        email: 'user@example.com',
        password: 'secret123',
      );
      final signed = await controller.authorizeRequest(
        request: request,
        connector: null,
      );
      expect(signed.headers['authorization'], 'Bearer id-token');
    });
  });

  group('MiniProgram email auth sheet', () {
    testWidgets('validates input and stores successful session', (
      tester,
    ) async {
      final controller = MiniProgramAuthController(
        store: InMemoryMiniProgramAuthStore(),
        clock: _fixedNow,
      );
      final connector = _AuthConnector((request) {
        expect(request.endpoint, 'auth/email/sign-in');
        return _authResult();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  showMiniProgramEmailAuthSheet(
                    context: context,
                    controller: controller,
                    connector: connector,
                    miniProgramId: 'coupon',
                  );
                },
                child: const Text('Open auth'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open auth'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(controller.snapshot('coupon').authenticated, isTrue);
      expect(controller.session('coupon')?.idToken, 'id-token');
    });
  });
}

DateTime _fixedNow() => DateTime.utc(2026, 5, 25, 12);

MiniProgramAuthSession _session({DateTime? expiresAtUtc}) {
  return MiniProgramAuthSession(
    miniProgramId: 'coupon',
    user: const MiniProgramAuthUser(uid: 'user-1', email: 'user@example.com'),
    idToken: 'id-token',
    refreshToken: 'refresh-token',
    expiresAtUtc: expiresAtUtc ?? _fixedNow().add(const Duration(hours: 1)),
  );
}

MiniProgramBackendResult _authResult({String idToken = 'id-token'}) {
  return MiniProgramBackendResult.success(
    endpoint: 'auth/email/sign-in',
    method: 'POST',
    statusCode: 200,
    data: <String, dynamic>{
      'authenticated': true,
      'user': <String, dynamic>{'uid': 'user-1', 'email': 'user@example.com'},
      'idToken': idToken,
      'refreshToken': 'refresh-token',
      'expiresIn': 3600,
    },
  );
}

class _AuthConnector implements MiniProgramBackendConnector {
  const _AuthConnector(this.handler);

  final MiniProgramBackendResult Function(MiniProgramBackendRequest request)
  handler;

  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    return handler(request);
  }
}
