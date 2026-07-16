part of '../../http_mini_program_source.dart';

extension _HttpMiniProgramSourcePublisherBackend on HttpMiniProgramSource {
  Future<MiniProgramPublisherBackendContract?> _loadPublisherBackendContract({
    required String miniProgramId,
    required String version,
  }) async {
    Map<String, dynamic> json;
    try {
      json = await _loadJsonObject(
        _resolve('artifacts/$miniProgramId/$version/publisher_backend.json'),
        resourceLabel: 'Publisher API contract',
      );
    } on MiniProgramSourceException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
    try {
      final contract = MiniProgramPublisherBackendContract.fromJson(json);
      if (contract.appId != miniProgramId) {
        throw FormatException(
          'Contract appId "${contract.appId}" does not match '
          '"$miniProgramId".',
        );
      }
      return contract;
    } catch (error) {
      throw MiniProgramSourceException(
        message: 'Publisher API contract is invalid: $error',
        errorCode: MiniProgramPublisherBackendErrorCodes.invalidContract,
        details: <String, dynamic>{
          'miniProgramId': miniProgramId,
          'version': version,
        },
      );
    }
  }
}
