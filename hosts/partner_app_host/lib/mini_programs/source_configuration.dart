import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

class PartnerAppHostSourceConfiguration {
  PartnerAppHostSourceConfiguration({
    required this.backendApiBaseUri,
    this.client,
  });

  factory PartnerAppHostSourceConfiguration.fromEnvironment() {
    const rawBackendBaseUrl = String.fromEnvironment(
      'PARTNER_APP_BACKEND_BASE_URL',
      defaultValue: 'http://127.0.0.1:8080/api/',
    );

    return PartnerAppHostSourceConfiguration(
      backendApiBaseUri: Uri.parse(rawBackendBaseUrl),
    );
  }

  final Uri backendApiBaseUri;
  final http.Client? client;

  MiniProgramSource buildSource({
    required String hostAppId,
    required String sdkVersion,
    required CapabilityRegistry capabilityRegistry,
  }) {
    return HttpMiniProgramSource(
      apiBaseUri: backendApiBaseUri,
      client: client,
      manifestRequestQueryParametersBuilder: (_) => <String, String>{
        'hostApp': hostAppId,
        'sdkVersion': sdkVersion,
        'capabilities': _serializeCapabilities(
          capabilityRegistry.supportedCapabilities,
        ),
      },
    );
  }

  String get description => 'Local backend ($backendApiBaseUri)';

  static String _serializeCapabilities(Set<Capability> capabilities) {
    final wireValues =
        capabilities.map((capability) => capability.wireValue).toList()..sort();
    return wireValues.join(',');
  }
}
