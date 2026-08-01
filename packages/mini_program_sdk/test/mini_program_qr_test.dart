import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('QR manager permits one scan and validates provider output', () async {
    final provider = _QrProvider();
    final manager = MiniProgramQrManager(provider);
    final first = manager.scan(
      miniProgramId: 'scanner',
      allowTorch: true,
      timeout: const Duration(seconds: 10),
    );
    await provider.started.future;

    await expectLater(
      manager.scan(
        miniProgramId: 'other',
        allowTorch: false,
        timeout: const Duration(seconds: 10),
      ),
      throwsA(
        isA<MiniProgramQrException>().having(
          (error) => error.errorCode,
          'errorCode',
          MiniProgramErrorCodes.qrRequestInProgress,
        ),
      ),
    );
    provider.complete();
    expect((await first).rawValue, 'https://example.com');
    expect(provider.request?.miniProgramId, 'scanner');
    expect(provider.request?.allowTorch, isTrue);
    await manager.dispose();
  });

  test(
    'QR manager cancels an app-owned scan during lifecycle release',
    () async {
      final provider = _QrProvider();
      final manager = MiniProgramQrManager(provider);
      unawaited(
        manager
            .scan(
              miniProgramId: 'scanner',
              allowTorch: false,
              timeout: const Duration(seconds: 10),
            )
            .catchError((_) => _validResult()),
      );
      await provider.started.future;

      await manager.releaseFor('other');
      expect(provider.cancelled, isEmpty);
      await manager.releaseFor('scanner');
      expect(provider.cancelled, <String>[provider.request!.scanId]);
      provider.complete();
      await manager.dispose();
    },
  );
}

MiniProgramQrScanResult _validResult() => MiniProgramQrScanResult(
  rawValue: 'https://example.com',
  valueType: 'url',
  scannedAtUtc: DateTime.utc(2026, 8, 1),
);

class _QrProvider implements MiniProgramQrScannerProvider {
  final started = Completer<void>();
  final completed = Completer<MiniProgramQrScanResult>();
  final List<String> cancelled = <String>[];
  MiniProgramQrScanRequest? request;

  void complete() {
    if (!completed.isCompleted) completed.complete(_validResult());
  }

  @override
  Future<MiniProgramQrScanResult> scan(MiniProgramQrScanRequest request) async {
    this.request = request;
    if (!started.isCompleted) started.complete();
    return completed.future;
  }

  @override
  Future<bool> cancel(String scanId) async {
    cancelled.add(scanId);
    return true;
  }
}
