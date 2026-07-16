part of '../../mini_program_endpoint.dart';

extension _EndpointRoutingCapabilities on EndpointRoutingMiniProgramSource {
  Future<List<int>> _loadRoutedJsonAsset({
    required String miniProgramId,
    required String version,
    required String assetPath,
  }) {
    final source = _sourceFor(miniProgramId);
    if (source is! MiniProgramJsonAssetSource) {
      throw MiniProgramSourceException(
        message: 'The configured mini-program source cannot load JSON assets.',
        errorCode: MiniProgramErrorCodes.dataAssetUnavailable,
        details: <String, dynamic>{'miniProgramId': miniProgramId},
      );
    }
    return (source as MiniProgramJsonAssetSource).loadJsonAsset(
      miniProgramId: miniProgramId,
      version: version,
      assetPath: assetPath,
    );
  }

  Future<MiniProgramPublisherBackendContract?>
  _loadRoutedPublisherBackendContract({
    required String miniProgramId,
    required String version,
  }) {
    final source = _sourceFor(miniProgramId);
    if (source is! MiniProgramPublisherBackendContractSource) {
      return Future<MiniProgramPublisherBackendContract?>.value();
    }
    return (source as MiniProgramPublisherBackendContractSource)
        .loadPublisherBackendContract(
          miniProgramId: miniProgramId,
          version: version,
        );
  }
}
