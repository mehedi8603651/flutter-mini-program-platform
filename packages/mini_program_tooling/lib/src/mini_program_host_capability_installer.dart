import 'host_integration/capabilities/dispatch.dart' as capabilities;
import 'host_integration/capabilities/models.dart';

export 'host_integration/capabilities/models.dart'
    show
        MiniProgramHostCapabilityException,
        MiniProgramHostCapabilityInitRequest,
        MiniProgramHostCapabilityInitResult;

/// Installs optional host-owned native capability adapters without accepting
/// any mini-program permission policy.
class MiniProgramHostCapabilityInstaller {
  const MiniProgramHostCapabilityInstaller();

  static const String locationCapability = capabilities.locationCapability;
  static const String fileCapability = capabilities.fileCapability;
  static const String cameraCapability = capabilities.cameraCapability;
  static const String flashlightCapability = capabilities.flashlightCapability;
  static const String qrCapability = capabilities.qrCapability;
  static const String audioCapability = capabilities.audioCapability;
  static const String videoCapability = capabilities.videoCapability;
  static const String androidPlatform = capabilities.androidPlatform;

  Future<MiniProgramHostCapabilityInitResult> initialize(
    MiniProgramHostCapabilityInitRequest request,
  ) => capabilities.dispatchHostCapability(request);
}
