import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Host authority for foreground flashlight control.
@immutable
class MiniProgramFlashlightPolicy {
  const MiniProgramFlashlightPolicy({this.enabled = false});

  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is MiniProgramFlashlightPolicy && enabled == other.enabled;

  @override
  int get hashCode => enabled.hashCode;
}

/// Resolves accepted flashlight policy for one mini-program endpoint.
abstract interface class MiniProgramFlashlightPolicyProvider {
  MiniProgramFlashlightPolicy flashlightPolicyFor(String miniProgramId);
}

/// Controls the device torch without exposing camera identifiers.
abstract interface class MiniProgramFlashlightProvider {
  Future<MiniProgramFlashlightStatus> setEnabled(bool enabled);

  Future<MiniProgramFlashlightStatus> getStatus();
}

/// Structured flashlight provider failure.
class MiniProgramFlashlightException implements Exception {
  const MiniProgramFlashlightException({
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

/// Tracks flashlight ownership and guarantees foreground cleanup.
class MiniProgramFlashlightManager {
  MiniProgramFlashlightManager(this.provider);

  final MiniProgramFlashlightProvider provider;
  String? _ownerAppId;
  bool _disposed = false;

  Future<MiniProgramFlashlightStatus> turnOn(String miniProgramId) async {
    _ensureActive();
    final owner = _ownerAppId;
    if (owner != null && owner != miniProgramId) {
      throw const MiniProgramFlashlightException(
        errorCode: MiniProgramErrorCodes.flashlightInUse,
        message: 'The flashlight is controlled by another mini-program.',
      );
    }
    final status = await provider.setEnabled(true);
    status.validate();
    if (!status.available || !status.enabled) {
      throw const MiniProgramFlashlightException(
        errorCode: MiniProgramErrorCodes.flashlightUnavailable,
        message: 'The flashlight could not be enabled.',
      );
    }
    _ownerAppId = miniProgramId;
    return status;
  }

  Future<MiniProgramFlashlightStatus> turnOff(String miniProgramId) async {
    _ensureActive();
    final owner = _ownerAppId;
    if (owner != null && owner != miniProgramId) {
      throw const MiniProgramFlashlightException(
        errorCode: MiniProgramErrorCodes.flashlightInUse,
        message: 'The flashlight is controlled by another mini-program.',
      );
    }
    if (owner == null) {
      final status = await getStatus();
      if (status.enabled) {
        throw const MiniProgramFlashlightException(
          errorCode: MiniProgramErrorCodes.flashlightInUse,
          message: 'The flashlight is controlled outside this mini-program.',
        );
      }
      return status;
    }
    final status = await provider.setEnabled(false);
    status.validate();
    _ownerAppId = null;
    return status;
  }

  Future<MiniProgramFlashlightStatus> toggle(String miniProgramId) async {
    final status = await getStatus();
    return status.enabled ? turnOff(miniProgramId) : turnOn(miniProgramId);
  }

  Future<MiniProgramFlashlightStatus> getStatus() async {
    _ensureActive();
    final status = await provider.getStatus();
    status.validate();
    if (!status.enabled) {
      _ownerAppId = null;
    }
    return status;
  }

  Future<void> releaseFor(String miniProgramId) async {
    if (_ownerAppId != miniProgramId) {
      return;
    }
    try {
      await provider.setEnabled(false);
    } on Object {
      // Foreground lifecycle cleanup is best effort.
    } finally {
      _ownerAppId = null;
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    final owner = _ownerAppId;
    if (owner != null) {
      await releaseFor(owner);
    }
    _disposed = true;
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('MiniProgramFlashlightManager is disposed.');
    }
  }
}
