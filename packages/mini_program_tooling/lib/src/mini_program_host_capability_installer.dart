import 'host_integration/capabilities/location/installer.dart'
    as location_capability;
import 'host_integration/capabilities/file_transfer/installer.dart'
    as file_capability;
import 'host_integration/capabilities/models.dart';

export 'host_integration/capabilities/models.dart'
    show
        MiniProgramHostCapabilityException,
        MiniProgramHostCapabilityInitRequest,
        MiniProgramHostCapabilityInitResult;

/// Installs optional, host-owned native capability adapters.
///
/// Capability installation only makes a provider available to the SDK. It
/// never accepts a mini-program permission policy.
class MiniProgramHostCapabilityInstaller {
  const MiniProgramHostCapabilityInstaller();

  static const String locationCapability =
      location_capability.locationCapability;
  static const String fileCapability = file_capability.fileCapability;
  static const String androidPlatform = location_capability.androidPlatform;

  Future<MiniProgramHostCapabilityInitResult> initialize(
    MiniProgramHostCapabilityInitRequest request,
  ) async {
    return await switch (request.capability.trim().toLowerCase()) {
      locationCapability =>
        location_capability.initializeMiniProgramHostCapability(request),
      fileCapability => file_capability.initializeMiniProgramHostFileCapability(
        request,
      ),
      _ => throw MiniProgramHostCapabilityException(
        'Unsupported host capability "${request.capability}". Supported '
        'capabilities: $locationCapability, $fileCapability.',
      ),
    };
  }
}
