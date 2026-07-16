import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/mini_program_discovery.dart' as discovery;
import 'package:mini_program_sdk/network/published_mini_program_catalog_client.dart'
    as catalog;

void main() {
  test(
    'historical catalog and discovery imports retain public declarations',
    () {
      const summary = catalog.PublishedMiniProgramSummary(
        id: 'weather',
        title: 'Weather',
        description: 'Forecasts',
        entry: 'weather/home',
        resolvedVersion: '1.0.0',
        requiredCapabilities: [],
      );
      const publishedCatalog = catalog.PublishedMiniProgramCatalog(
        entries: <catalog.PublishedMiniProgramSummary>[summary],
      );
      const state = discovery.MiniProgramDiscoveryState(
        miniProgramId: 'weather',
        status: discovery.MiniProgramDiscoveryStatus.live,
      );

      expect(
        catalog.PublishedMiniProgramCatalogClient(
          apiBaseUri: Uri.parse('https://catalog.example.com/'),
        ),
        isA<catalog.PublishedMiniProgramCatalogClient>(),
      );
      expect(publishedCatalog.entries.single, same(summary));
      expect(
        const discovery.MiniProgramDiscoveryResolver(),
        isA<discovery.MiniProgramDiscoveryResolver>(),
      );
      expect(state.canOpen, isTrue);
      expect(discovery.MiniProgramDiscoverySourceKind.values, hasLength(2));
    },
  );
}
