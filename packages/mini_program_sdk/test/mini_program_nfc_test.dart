import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

const _policy = MiniProgramNfcPolicy(enabled: true);
const _tag = {
  'records': [
    {'type': 'text', 'text': 'product-42', 'language': 'en'},
  ],
};

void main() {
  test(
    'NFC is default-denied and validates policy before native access',
    () async {
      final provider = _NfcProvider();
      final manager = MiniProgramNfcManager(provider);
      addTearDown(manager.dispose);
      await expectLater(
        manager.run(
          miniProgramId: 'shop',
          action: 'nfc.read',
          arguments: {},
          policy: const MiniProgramNfcPolicy(),
        ),
        throwsA(_code('nfc_not_accepted')),
      );
      await expectLater(
        manager.run(
          miniProgramId: 'shop',
          action: 'nfc.read',
          arguments: {},
          policy: const MiniProgramNfcPolicy(enabled: true, maxRecords: 17),
        ),
        throwsFormatException,
      );
      expect(provider.calls, isEmpty);
    },
  );
  test('NFC clamps duration and forwards accepted host limits only', () async {
    final provider = _NfcProvider();
    final manager = MiniProgramNfcManager(provider);
    addTearDown(manager.dispose);
    final future = manager.run(
      miniProgramId: 'shop',
      action: 'nfc.read',
      arguments: {'timeoutMs': 30000},
      policy: const MiniProgramNfcPolicy(
        enabled: true,
        maxReadMs: 1200,
        allowedRecordTypes: ['text'],
        maxRecords: 2,
        maxMessageBytes: 64,
      ),
    );
    expect(provider.calls.single.args, {
      'timeoutMs': 1200,
      'allowedRecordTypes': ['text'],
      'maxRecords': 2,
      'maxMessageBytes': 64,
    });
    provider.calls.single.result.complete({
      ..._tag,
      'tagId': 'must not escape',
    });
    expect(await future, _tag);
    expect(provider.released.single, provider.calls.single.id);
  });
  test(
    'NFC rejects concurrent requests and cancellation is app-scoped',
    () async {
      final provider = _NfcProvider();
      final manager = MiniProgramNfcManager(provider);
      addTearDown(manager.dispose);
      final first = manager.run(
        miniProgramId: 'shop',
        action: 'nfc.read',
        arguments: {},
        policy: _policy,
      );
      final cancelled = expectLater(
        first,
        throwsA(_code('nfc_request_cancelled')),
      );
      await expectLater(
        manager.run(
          miniProgramId: 'shop',
          action: 'nfc.read',
          arguments: {},
          policy: _policy,
        ),
        throwsA(_code('nfc_request_in_progress')),
      );
      expect(
        await manager.run(
          miniProgramId: 'other',
          action: 'nfc.cancel',
          arguments: {},
          policy: const MiniProgramNfcPolicy(),
        ),
        {'cancelled': false},
      );
      expect(provider.released, isEmpty);
      expect(
        await manager.run(
          miniProgramId: 'shop',
          action: 'nfc.cancel',
          arguments: {},
          policy: const MiniProgramNfcPolicy(),
        ),
        {'cancelled': true},
      );
      await cancelled;
      provider.calls.first.result.complete(_tag);
      await Future<void>.delayed(Duration.zero);
      expect(provider.released, hasLength(1));
    },
  );
  test(
    'A late result and stale cleanup cannot touch a replacement NFC session',
    () async {
      final provider = _NfcProvider();
      final manager = MiniProgramNfcManager(provider);
      addTearDown(manager.dispose);
      final first = manager.run(
        miniProgramId: 'shop',
        action: 'nfc.read',
        arguments: {},
        policy: _policy,
      );
      final cancelled = expectLater(
        first,
        throwsA(_code('nfc_request_cancelled')),
      );
      final firstGeneration = manager.sessionGeneration;
      await manager.releaseFor('shop');
      await cancelled;
      final second = manager.run(
        miniProgramId: 'shop',
        action: 'nfc.read',
        arguments: {},
        policy: _policy,
      );
      await manager.releaseFor('shop', sessionGeneration: firstGeneration);
      provider.calls.first.result.complete(_tag);
      await Future<void>.delayed(Duration.zero);
      expect(provider.released, [provider.calls.first.id]);
      provider.calls.last.result.complete(_tag);
      expect(await second, _tag);
      expect(provider.calls.first.id, isNot(provider.calls.last.id));
    },
  );
  test(
    'NFC validates native results and independently releases malformed data',
    () async {
      final provider = _NfcProvider();
      final manager = MiniProgramNfcManager(provider);
      addTearDown(manager.dispose);
      final future = manager.run(
        miniProgramId: 'shop',
        action: 'nfc.read',
        arguments: {},
        policy: _policy,
      );
      final failed = expectLater(future, throwsA(_code('nfc_invalid_result')));
      provider.calls.single.result.complete({
        'records': [
          {'type': 'uri', 'uri': 'intent://x'},
        ],
      });
      await failed;
      expect(provider.released, hasLength(1));
    },
  );
  test(
    'Disposal cancels immediately even if a provider read never completes',
    () async {
      final provider = _NfcProvider();
      final manager = MiniProgramNfcManager(provider);
      final future = manager.run(
        miniProgramId: 'shop',
        action: 'nfc.read',
        arguments: {},
        policy: _policy,
      );
      final cancelled = expectLater(
        future,
        throwsA(_code('nfc_request_cancelled')),
      );
      await manager.dispose();
      await cancelled;
      provider.calls.single.result.completeError(
        StateError('late platform error'),
      );
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        manager.run(
          miniProgramId: 'shop',
          action: 'nfc.getState',
          arguments: {},
          policy: _policy,
        ),
        throwsA(_code('nfc_request_cancelled')),
      );
    },
  );
  testWidgets('A stalled native read has an independent SDK timeout', (
    tester,
  ) async {
    final provider = _NfcProvider();
    final manager = MiniProgramNfcManager(provider);
    addTearDown(manager.dispose);
    final future = manager.run(
      miniProgramId: 'shop',
      action: 'nfc.read',
      arguments: {'timeoutMs': 1000},
      policy: _policy,
    );
    final timedOut = expectLater(future, throwsA(_code('nfc_timeout')));
    await tester.pump(const Duration(milliseconds: 2100));
    await timedOut;
    expect(provider.released, hasLength(1));
    provider.calls.single.result.complete(_tag);
    await tester.pump();
  });
}

Matcher _code(String code) =>
    isA<MiniProgramNfcException>().having((e) => e.errorCode, 'code', code);

class _NfcProvider implements MiniProgramNfcProvider {
  final calls =
      <
        ({
          String id,
          Map<String, dynamic> args,
          Completer<Map<String, dynamic>> result,
        })
      >[];
  final released = <String>[];
  @override
  Future<Map<String, dynamic>> invoke({
    required String miniProgramId,
    required String sessionId,
    required String action,
    required Map<String, dynamic> arguments,
  }) {
    final result = Completer<Map<String, dynamic>>();
    calls.add((id: sessionId, args: arguments, result: result));
    return result.future;
  }

  @override
  Future<void> release({
    required String miniProgramId,
    required String sessionId,
  }) async {
    released.add(sessionId);
  }
}
