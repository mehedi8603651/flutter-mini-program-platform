import 'host_integration/capabilities/location/installer.dart'
    as location_capability;
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
  static const String androidPlatform = location_capability.androidPlatform;

  Future<MiniProgramHostCapabilityInitResult> initialize(
    MiniProgramHostCapabilityInitRequest request,
  ) {
    return location_capability.initializeMiniProgramHostCapability(request);
  }
}
