import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/network/http_mini_program_source.dart'
    as http_source;
import 'package:mini_program_sdk/network/mini_program_delivery_context.dart';
import 'package:mini_program_sdk/network/mini_program_endpoint.dart'
    as endpoint;
import 'package:mini_program_sdk/network/mini_program_source.dart';

void main() {
  test(
    'historical static delivery import paths retain public declarations',
    () {
      final source = http_source.HttpMiniProgramSource(
        apiBaseUri: Uri.parse('https://cdn.example.com/store/'),
        manifestRequestQueryParametersBuilder: _legacyQueryBuilder,
      );
      final appEndpoint = endpoint.MiniProgramEndpoint.public(
        apiBaseUri: Uri.parse('https://cdn.example.com/store/'),
      );

      expect(_legacyQueryBuilder('weather'), const <String, String>{
        'hostApp': 'legacy_host',
      });
      expect(
        _legacyQueryBuilder,
        isA<http_source.ManifestRequestQueryParametersBuilder>(),
      );
      expect(source, isA<http_source.HttpMiniProgramSource>());
      expect(appEndpoint, isA<endpoint.MiniProgramEndpoint>());
      expect(
        _legacySourceFactory,
        isA<endpoint.MiniProgramEndpointSourceFactory>(),
      );

      source.dispose();
    },
  );
}

Map<String, String> _legacyQueryBuilder(String miniProgramId) =>
    const <String, String>{'hostApp': 'legacy_host'};

MiniProgramSource _legacySourceFactory({
  required String appId,
  required endpoint.MiniProgramEndpoint endpoint,
  required MiniProgramDeliveryContext deliveryContext,
}) {
  return http_source.HttpMiniProgramSource.fromDeliveryContext(
    apiBaseUri: endpoint.apiBaseUri,
    deliveryContext: deliveryContext,
  );
}
