import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Immutable registry of capabilities supported by the current host app.
class CapabilityRegistry {
  CapabilityRegistry(Iterable<Object?> supportedCapabilities)
    : _supportedCapabilities = Set.unmodifiable(
        supportedCapabilities.map(CapabilityIds.normalizeObject),
      );

  final Set<CapabilityId> _supportedCapabilities;

  Set<CapabilityId> get supportedCapabilities => _supportedCapabilities;

  bool supports(Object? capability) => _supportedCapabilities.contains(
    CapabilityIds.normalizeObject(capability),
  );

  bool supportsAll(Iterable<Object?> capabilities) =>
      missingCapabilities(capabilities).isEmpty;

  Set<CapabilityId> missingCapabilities(Iterable<Object?> capabilities) {
    return Set<CapabilityId>.from(
      capabilities
          .map(CapabilityIds.normalizeObject)
          .where((capability) => !_supportedCapabilities.contains(capability)),
    );
  }
}
