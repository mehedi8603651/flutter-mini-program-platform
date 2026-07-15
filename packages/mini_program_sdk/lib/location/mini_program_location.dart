import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Supplies one-time foreground location results for a host platform.
abstract interface class MiniProgramLocationProvider {
  Future<MiniProgramLocationResult> getCurrentLocation({
    required MiniProgramLocationAccuracy accuracy,
    required Duration timeout,
  });
}

/// Resolves host-accepted location policy for an active mini-program.
abstract interface class MiniProgramLocationPolicyProvider {
  MiniProgramLocationPolicy locationPolicyFor(String miniProgramId);
}

/// Host authority for mini-program current-location actions.
@immutable
class MiniProgramLocationPolicy {
  const MiniProgramLocationPolicy({
    this.enabled = false,
    this.accuracy = MiniProgramLocationAccuracy.approximate,
    this.mode = MiniProgramLocationMode.whenInUse,
  });

  final bool enabled;
  final MiniProgramLocationAccuracy accuracy;
  final MiniProgramLocationMode mode;

  @override
  bool operator ==(Object other) {
    return other is MiniProgramLocationPolicy &&
        enabled == other.enabled &&
        accuracy == other.accuracy &&
        mode == other.mode;
  }

  @override
  int get hashCode => Object.hash(enabled, accuracy, mode);
}

/// Structured failure returned by a platform location provider.
class MiniProgramLocationException implements Exception {
  const MiniProgramLocationException({
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
