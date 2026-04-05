import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'local_mini_program_source.dart';

enum SuperAppHostSourceMode { assets, localBackend }

class SuperAppHostSourceConfiguration {
  SuperAppHostSourceConfiguration({required this.mode, this.backendApiBaseUri});

  factory SuperAppHostSourceConfiguration.fromEnvironment() {
    const rawMode = String.fromEnvironment(
      'SUPER_APP_SOURCE_MODE',
      defaultValue: 'assets',
    );
    const rawBackendBaseUrl = String.fromEnvironment(
      'SUPER_APP_BACKEND_BASE_URL',
      defaultValue: 'http://127.0.0.1:8080/api/',
    );

    return SuperAppHostSourceConfiguration(
      mode: _parseMode(rawMode),
      backendApiBaseUri: Uri.parse(rawBackendBaseUrl),
    );
  }

  final SuperAppHostSourceMode mode;
  final Uri? backendApiBaseUri;

  MiniProgramSource buildSource({
    required String hostAppId,
    required String sdkVersion,
    required CapabilityRegistry capabilityRegistry,
  }) {
    switch (mode) {
      case SuperAppHostSourceMode.assets:
        return const LocalMiniProgramSource();
      case SuperAppHostSourceMode.localBackend:
        final apiBaseUri = backendApiBaseUri;
        if (apiBaseUri == null) {
          throw StateError(
            'A backend API base URI is required for local backend source mode.',
          );
        }

        return HttpMiniProgramSource(
          apiBaseUri: apiBaseUri,
          manifestRequestQueryParametersBuilder: (_) => <String, String>{
            'hostApp': hostAppId,
            'sdkVersion': sdkVersion,
            'capabilities': _serializeCapabilities(
              capabilityRegistry.supportedCapabilities,
            ),
          },
        );
    }
  }

  String get description {
    switch (mode) {
      case SuperAppHostSourceMode.assets:
        return 'Bundled assets';
      case SuperAppHostSourceMode.localBackend:
        return 'Local backend (${backendApiBaseUri ?? 'unconfigured'})';
    }
  }

  static SuperAppHostSourceMode _parseMode(String rawMode) {
    switch (rawMode.trim().toLowerCase()) {
      case 'backend':
      case 'local_backend':
      case 'local-backend':
        return SuperAppHostSourceMode.localBackend;
      case 'assets':
      default:
        return SuperAppHostSourceMode.assets;
    }
  }

  static String _serializeCapabilities(Set<Capability> capabilities) {
    final wireValues =
        capabilities.map((capability) => capability.wireValue).toList()..sort();
    return wireValues.join(',');
  }
}
