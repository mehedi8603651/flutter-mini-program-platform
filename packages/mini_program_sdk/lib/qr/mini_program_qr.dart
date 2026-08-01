import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Host authority for one-time QR scanning.
@immutable
class MiniProgramQrPolicy {
  const MiniProgramQrPolicy({this.enabled = false, this.allowTorch = false});

  final bool enabled;
  final bool allowTorch;

  @override
  bool operator ==(Object other) =>
      other is MiniProgramQrPolicy &&
      enabled == other.enabled &&
      allowTorch == other.allowTorch;

  @override
  int get hashCode => Object.hash(enabled, allowTorch);
}

/// Resolves accepted QR scanner policy for one mini-program endpoint.
abstract interface class MiniProgramQrPolicyProvider {
  MiniProgramQrPolicy qrPolicyFor(String miniProgramId);
}

/// Trusted request passed to a host QR scanner implementation.
@immutable
class MiniProgramQrScanRequest {
  const MiniProgramQrScanRequest({
    required this.scanId,
    required this.miniProgramId,
    required this.allowTorch,
    required this.timeout,
  });

  final String scanId;
  final String miniProgramId;
  final bool allowTorch;
  final Duration timeout;
}

/// Opens trusted host UI that scans only QR codes.
abstract interface class MiniProgramQrScannerProvider {
  Future<MiniProgramQrScanResult> scan(MiniProgramQrScanRequest request);

  Future<bool> cancel(String scanId);
}

/// Structured QR provider failure mapped to a stable contract error.
class MiniProgramQrException implements Exception {
  const MiniProgramQrException({
    required this.errorCode,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final String errorCode;
  final String message;
  final Map<String, Object?> details;

  @override
  String toString() => message;
}

/// Owns one active scanner request and enforces app-scoped cancellation.
class MiniProgramQrManager {
  MiniProgramQrManager(this.provider);

  final MiniProgramQrScannerProvider provider;
  final Map<String, String> _activeByApp = <String, String>{};
  int _sequence = 0;
  bool _disposed = false;

  Future<MiniProgramQrScanResult> scan({
    required String miniProgramId,
    required bool allowTorch,
    required Duration timeout,
  }) async {
    _ensureActive();
    if (_activeByApp.isNotEmpty) {
      throw const MiniProgramQrException(
        errorCode: MiniProgramErrorCodes.qrRequestInProgress,
        message: 'A QR scan request is already in progress.',
      );
    }
    _sequence++;
    final scanId = 'qr_${DateTime.now().microsecondsSinceEpoch}_$_sequence';
    _activeByApp[miniProgramId] = scanId;
    try {
      final result = await provider
          .scan(
            MiniProgramQrScanRequest(
              scanId: scanId,
              miniProgramId: miniProgramId,
              allowTorch: allowTorch,
              timeout: timeout,
            ),
          )
          .timeout(
            timeout + const Duration(seconds: 2),
            onTimeout: () async {
              await _cancelBestEffort(scanId);
              throw const MiniProgramQrException(
                errorCode: MiniProgramErrorCodes.qrTimeout,
                message: 'The QR scan request timed out.',
              );
            },
          );
      result.validate();
      return result;
    } on FormatException catch (error) {
      throw MiniProgramQrException(
        errorCode: MiniProgramErrorCodes.qrInvalidResult,
        message: error.message.toString(),
      );
    } finally {
      if (_activeByApp[miniProgramId] == scanId) {
        _activeByApp.remove(miniProgramId);
      }
    }
  }

  Future<void> releaseFor(String miniProgramId) async {
    final scanId = _activeByApp.remove(miniProgramId);
    if (scanId != null) {
      await _cancelBestEffort(scanId);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    final scanIds = _activeByApp.values.toList(growable: false);
    _activeByApp.clear();
    for (final scanId in scanIds) {
      await _cancelBestEffort(scanId);
    }
    _disposed = true;
  }

  Future<void> _cancelBestEffort(String scanId) async {
    try {
      await provider.cancel(scanId);
    } on Object {
      // Host lifecycle cleanup must not leak provider failures.
    }
  }

  void _ensureActive() {
    if (_disposed) throw StateError('MiniProgramQrManager is disposed.');
  }
}
