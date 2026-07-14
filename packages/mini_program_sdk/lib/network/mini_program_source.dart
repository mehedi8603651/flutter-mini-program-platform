import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'mini_program_delivery_context.dart';

/// Host-provided loading abstraction for manifests and entry screen JSON.
abstract interface class MiniProgramSource {
  Future<MiniProgramManifest> loadManifest(String miniProgramId);

  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  });
}

/// Optional source capability for immutable JSON files under artifact assets.
abstract interface class MiniProgramJsonAssetSource {
  Future<List<int>> loadJsonAsset({
    required String miniProgramId,
    required String version,
    required String assetPath,
  });
}

/// Optional source capability for an artifact-owned Publisher API contract.
abstract interface class MiniProgramPublisherBackendContractSource {
  Future<MiniProgramPublisherBackendContract?> loadPublisherBackendContract({
    required String miniProgramId,
    required String version,
  });
}

/// Optional source capability exposing request metadata for Publisher APIs.
abstract interface class MiniProgramDeliveryContextProvider {
  MiniProgramDeliveryContext? get deliveryContext;
}

/// Optional contract for sources that own disposable resources.
abstract interface class DisposableMiniProgramSource
    implements MiniProgramSource {
  void dispose();
}
