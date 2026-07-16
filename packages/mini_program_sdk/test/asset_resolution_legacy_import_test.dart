import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/network/asset_resolver.dart' as assets;

void main() {
  test('historical asset resolver import path retains public declarations', () {
    const result = assets.AssetResolutionResult(
      screenJson: <String, dynamic>{'type': 'text', 'data': 'Weather'},
      cachedAssetCount: 1,
      downloadedAssetCount: 2,
      failedAssetCount: 3,
    );

    expect(assets.AssetResolver(), isA<assets.AssetResolver>());
    expect(result.resolvedAssetCount, 3);
    expect(result.failedAssetCount, 3);
  });
}
