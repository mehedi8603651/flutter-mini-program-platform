part of '../manifest_loader.dart';

extension _PublisherBackendContractLoading on ManifestLoader {
  Future<MiniProgramPublisherBackendContract?> _loadPublisherBackendContract({
    required String miniProgramId,
    required MiniProgramManifest manifest,
    required MiniProgramSource source,
    required SdkLogger logger,
  }) async {
    if (source is! MiniProgramPublisherBackendContractSource) {
      return null;
    }
    try {
      final contract =
          await (source as MiniProgramPublisherBackendContractSource)
              .loadPublisherBackendContract(
                miniProgramId: miniProgramId,
                version: manifest.version,
              );
      if (contract != null && contract.appId != miniProgramId) {
        throw MiniProgramSourceException(
          message:
              'Publisher API contract appId "${contract.appId}" does not '
              'match "$miniProgramId".',
          errorCode: MiniProgramPublisherBackendErrorCodes.invalidContract,
        );
      }
      return contract;
    } on MiniProgramSourceException catch (error, stackTrace) {
      if (error.errorCode == MiniProgramErrorCodes.backendUnreachable ||
          error.errorCode == MiniProgramErrorCodes.backendTimeout) {
        logger.warn(
          'Publisher API contract could not be loaded; runtime API access '
          'will remain unavailable for this load.',
          context: <String, Object?>{
            'miniProgramId': miniProgramId,
            'version': manifest.version,
            'errorCode': error.errorCode,
          },
        );
        return null;
      }
      throw MiniProgramLoadException(
        MiniProgramFailure(
          errorCode: error.errorCode,
          message: error.message,
          fallback: manifest.fallback,
          cause: error,
          stackTrace: stackTrace,
          details: <String, dynamic>{
            'miniProgramId': miniProgramId,
            'version': manifest.version,
            ...error.details,
          },
        ),
      );
    } catch (error, stackTrace) {
      throw MiniProgramLoadException(
        MiniProgramFailure(
          errorCode: MiniProgramPublisherBackendErrorCodes.invalidContract,
          message: 'Failed to load the Publisher API contract.',
          fallback: manifest.fallback,
          cause: error,
          stackTrace: stackTrace,
          details: <String, dynamic>{
            'miniProgramId': miniProgramId,
            'version': manifest.version,
          },
        ),
      );
    }
  }
}
