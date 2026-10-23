import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Authority accepted by the host. Publisher requests never grant access.
@immutable
class MiniProgramNfcPolicy {
  const MiniProgramNfcPolicy({
    this.enabled = false,
    this.allowedRecordTypes = const ['text', 'uri'],
    this.maxReadMs = 15000,
    this.maxRecords = 8,
    this.maxMessageBytes = 4096,
  });
  final bool enabled;
  final List<String> allowedRecordTypes;
  final int maxReadMs;
  final int maxRecords;
  final int maxMessageBytes;

  void validate() {
    MiniProgramNfc.recordTypes(allowedRecordTypes);
    if (maxReadMs < 1000 ||
        maxReadMs > MiniProgramNfc.maxReadMs ||
        maxRecords < 1 ||
        maxRecords > MiniProgramNfc.maxRecords ||
        maxMessageBytes < 1 ||
        maxMessageBytes > MiniProgramNfc.maxMessageBytes) {
      throw const FormatException('Invalid accepted NFC limits.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MiniProgramNfcPolicy &&
      enabled == other.enabled &&
      listEquals(allowedRecordTypes, other.allowedRecordTypes) &&
      maxReadMs == other.maxReadMs &&
      maxRecords == other.maxRecords &&
      maxMessageBytes == other.maxMessageBytes;
  @override
  int get hashCode => Object.hash(
    enabled,
    Object.hashAll(allowedRecordTypes),
    maxReadMs,
    maxRecords,
    maxMessageBytes,
  );
}

abstract interface class MiniProgramNfcPolicyProvider {
  MiniProgramNfcPolicy nfcPolicyFor(String miniProgramId);
}

/// Optional native adapter. Native implementations independently enforce one
/// foreground owner across engines/tasks and return sanitized NDEF values only.
abstract interface class MiniProgramNfcProvider {
  Future<Map<String, dynamic>> invoke({
    required String miniProgramId,
    required String sessionId,
    required String action,
    required Map<String, dynamic> arguments,
  });

  /// Idempotently stops only this exact session, including pending native I/O.
  Future<void> release({
    required String miniProgramId,
    required String sessionId,
  });
}

class MiniProgramNfcException implements Exception {
  const MiniProgramNfcException({
    required this.errorCode,
    required this.message,
  });
  final String errorCode;
  final String message;
  @override
  String toString() => message;
}

/// Owns a single bounded request and rejects late results after cancellation.
class MiniProgramNfcManager {
  MiniProgramNfcManager(this.provider);
  final MiniProgramNfcProvider provider;
  _NfcRequest? _pending;
  bool _disposed = false;
  int _generation = 0;
  static int _sequence = 0;
  int get sessionGeneration => _generation;

  Future<Map<String, dynamic>> run({
    required String miniProgramId,
    required String action,
    required Map<String, dynamic> arguments,
    required MiniProgramNfcPolicy policy,
  }) async {
    if (_disposed) _fail('request_cancelled');
    final args = MiniProgramNfc.arguments(action, arguments);
    if (action == 'nfc.cancel') {
      final changed = _pending?.appId == miniProgramId;
      await releaseFor(miniProgramId);
      return {'cancelled': changed};
    }
    policy.validate();
    if (!policy.enabled) _fail('not_accepted');
    if (_pending != null) _fail('request_in_progress');
    final accepted = MiniProgramNfcPolicy(
      enabled: policy.enabled,
      allowedRecordTypes: List.unmodifiable(
        MiniProgramNfc.recordTypes(policy.allowedRecordTypes),
      ),
      maxReadMs: policy.maxReadMs,
      maxRecords: policy.maxRecords,
      maxMessageBytes: policy.maxMessageBytes,
    );
    if (action == 'nfc.read') {
      args['timeoutMs'] = (args['timeoutMs'] as int).clamp(
        1000,
        accepted.maxReadMs,
      );
      args.addAll({
        'allowedRecordTypes': accepted.allowedRecordTypes,
        'maxRecords': accepted.maxRecords,
        'maxMessageBytes': accepted.maxMessageBytes,
      });
    }
    final request = _NfcRequest(
      miniProgramId,
      'nfc_${++_sequence}',
      ++_generation,
    );
    _pending = request;
    request.watchdog = Timer(
      Duration(
        milliseconds: action == 'nfc.read'
            ? (args['timeoutMs'] as int) + 1000
            : 5000,
      ),
      () => _finish(request, error: _error('timeout')),
    );
    unawaited(_invoke(request, action, args, accepted));
    return request.result.future;
  }

  Future<void> _invoke(
    _NfcRequest request,
    String action,
    Map<String, dynamic> args,
    MiniProgramNfcPolicy policy,
  ) async {
    try {
      final raw = await provider.invoke(
        miniProgramId: request.appId,
        sessionId: request.id,
        action: action,
        arguments: args,
      );
      if (!identical(_pending, request)) return;
      final data = MiniProgramNfc.result(
        action,
        raw,
        allowedRecordTypes: policy.allowedRecordTypes,
        recordLimit: policy.maxRecords,
        byteLimit: policy.maxMessageBytes,
      );
      _finish(request, data: data);
    } on TimeoutException {
      _finish(request, error: _error('timeout'));
    } on FormatException {
      _finish(request, error: _error('invalid_result'));
    } on MiniProgramNfcException catch (error) {
      _finish(request, error: error);
    } catch (_) {
      _finish(request, error: _error('operation_failed'));
    }
  }

  void _finish(
    _NfcRequest request, {
    Map<String, dynamic>? data,
    MiniProgramNfcException? error,
  }) {
    if (!identical(_pending, request)) return;
    _pending = null;
    request.watchdog?.cancel();
    // Release before publishing completion. The exact session ID makes a late
    // release harmless when another request has already started.
    unawaited(_releaseNative(request));
    if (error != null) {
      request.result.completeError(error);
    } else {
      request.result.complete(data!);
    }
  }

  Future<void> _releaseNative(_NfcRequest request) async {
    try {
      await provider
          .release(miniProgramId: request.appId, sessionId: request.id)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      /* Native Activity lifecycle independently releases ownership. */
    }
  }

  Future<void> releaseFor(
    String miniProgramId, {
    int? sessionGeneration,
  }) async {
    final request = _pending;
    if (request == null ||
        request.appId != miniProgramId ||
        (sessionGeneration != null &&
            request.generation != sessionGeneration)) {
      return;
    }
    _finish(request, error: _error('request_cancelled'));
  }

  Future<void> dispose() async {
    _disposed = true;
    final request = _pending;
    if (request != null) _finish(request, error: _error('request_cancelled'));
  }

  static MiniProgramNfcException _error(String suffix) =>
      MiniProgramNfcException(
        errorCode: 'nfc_$suffix',
        message: 'NFC operation did not complete ($suffix).',
      );
  static Never _fail(String suffix) => throw _error(suffix);
}

class _NfcRequest {
  _NfcRequest(this.appId, this.id, this.generation);
  final String appId;
  final String id;
  final int generation;
  Timer? watchdog;
  final result = Completer<Map<String, dynamic>>();
}
