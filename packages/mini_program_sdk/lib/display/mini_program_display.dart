import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Host authority for temporary foreground window brightness.
@immutable
class MiniProgramDisplayBrightnessPolicy {
  const MiniProgramDisplayBrightnessPolicy({
    this.enabled = false,
    this.maxLevel = 1,
  }) : assert(maxLevel > 0 && maxLevel <= 1);

  final bool enabled;
  final double maxLevel;

  @override
  bool operator ==(Object other) =>
      other is MiniProgramDisplayBrightnessPolicy &&
      enabled == other.enabled &&
      maxLevel == other.maxLevel;

  @override
  int get hashCode => Object.hash(enabled, maxLevel);
}

/// Resolves accepted display-brightness policy for one endpoint.
abstract interface class MiniProgramDisplayBrightnessPolicyProvider {
  MiniProgramDisplayBrightnessPolicy displayBrightnessPolicyFor(
    String miniProgramId,
  );
}

/// Applies a temporary brightness override to the active host window.
abstract interface class MiniProgramDisplayBrightnessProvider {
  Future<void> setBrightness(double level);

  /// Restores normal system-controlled window brightness.
  Future<void> restoreBrightness();
}

/// Structured display-brightness provider failure.
class MiniProgramDisplayBrightnessException implements Exception {
  const MiniProgramDisplayBrightnessException({
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

@immutable
class _BrightnessRequest {
  const _BrightnessRequest({required this.appId, required this.level});

  final String appId;
  final double level;
}

/// Serializes nested brightness scopes and guarantees restoration.
class MiniProgramDisplayBrightnessManager {
  MiniProgramDisplayBrightnessManager(this.provider);

  final MiniProgramDisplayBrightnessProvider provider;
  final Map<Object, _BrightnessRequest> _requests =
      <Object, _BrightnessRequest>{};
  Future<void> _tail = Future<void>.value();
  bool _suspended = false;
  bool _disposed = false;

  Future<void> acquire({
    required String miniProgramId,
    required Object owner,
    required double level,
  }) => _enqueue(() async {
    _ensureActive();
    _validateLevel(level);
    final previous = _requests.remove(owner);
    _requests[owner] = _BrightnessRequest(appId: miniProgramId, level: level);
    if (_suspended) {
      return;
    }
    try {
      await provider.setBrightness(level);
    } on Object catch (error) {
      _requests.remove(owner);
      if (previous != null) {
        _requests[owner] = previous;
      }
      await _restoreCurrentBestEffort();
      throw _normalizeFailure(error);
    }
  });

  Future<void> release(Object owner) => _enqueue(() async {
    if (_disposed || _requests.remove(owner) == null || _suspended) {
      return;
    }
    await _applyCurrentOrRestore();
  });

  Future<void> releaseAllFor(String miniProgramId) => _enqueue(() async {
    if (_disposed) {
      return;
    }
    final hadActiveRequest = _requests.values.any(
      (request) => request.appId == miniProgramId,
    );
    _requests.removeWhere((_, request) => request.appId == miniProgramId);
    if (hadActiveRequest && !_suspended) {
      await _applyCurrentOrRestore(bestEffort: true);
    }
  });

  Future<void> suspend() => _enqueue(() async {
    if (_disposed || _suspended) {
      return;
    }
    _suspended = true;
    await _restoreBestEffort();
  });

  Future<void> resume() => _enqueue(() async {
    if (_disposed || !_suspended) {
      return;
    }
    _suspended = false;
    await _applyCurrentOrRestore(bestEffort: true);
  });

  Future<void> dispose() => _enqueue(() async {
    if (_disposed) {
      return;
    }
    _requests.clear();
    await _restoreBestEffort();
    _disposed = true;
  });

  Future<void> _applyCurrentOrRestore({bool bestEffort = false}) async {
    final current = _requests.isEmpty ? null : _requests.values.last;
    if (current == null) {
      if (bestEffort) {
        await _restoreBestEffort();
      } else {
        await provider.restoreBrightness();
      }
      return;
    }
    if (bestEffort) {
      try {
        await provider.setBrightness(current.level);
      } on Object {
        // Host lifecycle cleanup and recovery are best effort.
      }
      return;
    }
    await provider.setBrightness(current.level);
  }

  Future<void> _restoreCurrentBestEffort() async {
    await _applyCurrentOrRestore(bestEffort: true);
  }

  Future<void> _restoreBestEffort() async {
    try {
      await provider.restoreBrightness();
    } on Object {
      // Host lifecycle cleanup is best effort.
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('MiniProgramDisplayBrightnessManager is disposed.');
    }
  }

  static void _validateLevel(double level) {
    if (!level.isFinite || level <= 0 || level > 1) {
      throw MiniProgramDisplayBrightnessException(
        errorCode: MiniProgramErrorCodes.displayBrightnessInvalidLevel,
        message: 'Display brightness must be over 0 and at most 1.',
        details: <String, Object?>{'level': level},
      );
    }
  }

  static MiniProgramDisplayBrightnessException _normalizeFailure(Object error) {
    if (error is MiniProgramDisplayBrightnessException) {
      return error;
    }
    return const MiniProgramDisplayBrightnessException(
      errorCode: MiniProgramErrorCodes.displayBrightnessOperationFailed,
      message: 'The host could not update display brightness.',
    );
  }
}
