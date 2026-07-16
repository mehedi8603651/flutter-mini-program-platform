part of '../../mini_program_backend_connector.dart';

/// Connector used when an artifact declares an API that the host denied.
class DisabledMiniProgramBackendConnector
    implements MiniProgramBackendConnector {
  const DisabledMiniProgramBackendConnector();

  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    return MiniProgramBackendResult.failed(
      requestId: request.requestId,
      endpoint: request.endpoint,
      method: request.method,
      message:
          'Publisher API access is disabled by the host for mini-program '
          '"${request.miniProgramId}".',
      errorCode: MiniProgramErrorCodes.publisherApiDisabled,
    );
  }
}
