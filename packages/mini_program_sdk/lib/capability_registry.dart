import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Immutable registry of capabilities supported by the current host app.
class CapabilityRegistry {
  CapabilityRegistry(Iterable<Capability> supportedCapabilities)
    : _supportedCapabilities = Set.unmodifiable(supportedCapabilities);

  final Set<Capability> _supportedCapabilities;

  Set<Capability> get supportedCapabilities => _supportedCapabilities;

  bool supports(Capability capability) =>
      _supportedCapabilities.contains(capability);

  bool supportsAll(Iterable<Capability> capabilities) =>
      missingCapabilities(capabilities).isEmpty;

  Set<Capability> missingCapabilities(Iterable<Capability> capabilities) {
    return Set<Capability>.from(
      capabilities.where((capability) => !supports(capability)),
    );
  }
}
