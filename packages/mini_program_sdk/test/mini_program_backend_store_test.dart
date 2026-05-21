import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('MiniProgramBackendStore ignores stale results after clear', () async {
    final completer = Completer<MiniProgramBackendResult>();
    final store = MiniProgramBackendStore();
    final connector = _CompleterBackendConnector(completer);

    final future = store.runQuery(
      connector: connector,
      miniProgramId: 'coupon',
      query: const MiniProgramBackendQuery(
        requestId: 'home',
        endpoint: 'home/bootstrap',
      ),
    );

    expect(store.snapshot('home').isLoading, isTrue);
    store.clear();

    completer.complete(
      MiniProgramBackendResult.success(
        requestId: 'home',
        endpoint: 'home/bootstrap',
        data: const <String, dynamic>{'title': 'Old response'},
      ),
    );

    await future;
    expect(store.snapshot('home').isIdle, isTrue);
  });
}

class _CompleterBackendConnector implements MiniProgramBackendConnector {
  const _CompleterBackendConnector(this.completer);

  final Completer<MiniProgramBackendResult> completer;

  @override
  Future<MiniProgramBackendResult> call(MiniProgramBackendRequest request) {
    return completer.future;
  }
}
