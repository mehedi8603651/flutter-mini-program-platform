import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Host authority for opening known destinations in external map applications.
/// Installing an adapter does not enable access for any mini-program.
@immutable
class MiniProgramMapsPolicy {
  const MiniProgramMapsPolicy({
    this.enabled = false,
    this.allowOpenLocation = true,
    this.allowDirections = true,
  });
  final bool enabled;
  final bool allowOpenLocation;
  final bool allowDirections;

  @override
  bool operator ==(Object other) =>
      other is MiniProgramMapsPolicy &&
      enabled == other.enabled &&
      allowOpenLocation == other.allowOpenLocation &&
      allowDirections == other.allowDirections;
  @override
  int get hashCode => Object.hash(enabled, allowOpenLocation, allowDirections);
}

abstract interface class MiniProgramMapsPolicyProvider {
  MiniProgramMapsPolicy mapsPolicyFor(String miniProgramId);
}

/// Trusted host adapter. Choose compatible installed apps using host settings,
/// encode destination data, and preserve the calling Activity/task. Never
/// request device location or fall back to displaying a pin for directions.
/// Success means map UI opened, not that a route or journey was completed.
abstract interface class MiniProgramMapsProvider {
  Future<void> openLocation({
    required String miniProgramId,
    required MiniProgramMapDestination destination,
  });
  Future<void> openDirections({
    required String miniProgramId,
    required MiniProgramMapDestination destination,
    required MiniProgramMapTravelMode mode,
  });
}

class MiniProgramMapsException implements Exception {
  const MiniProgramMapsException({
    required this.errorCode,
    required this.message,
  });
  final String errorCode;
  final String message;
  @override
  String toString() => message;
}
