import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Host-owned bridge for explicit native or host-specific capabilities.
abstract interface class HostBridge {
  /// Opens a host-owned native screen.
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  );

  /// Calls a host-owned secure API operation through an allowlisted endpoint.
  Future<HostActionResult> callSecureApi(CallSecureApiActionPayload payload);

  /// Sends an analytics event through the host app's analytics stack.
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload);
}
