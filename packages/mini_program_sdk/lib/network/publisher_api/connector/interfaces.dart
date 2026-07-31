part of '../../mini_program_backend_connector.dart';

abstract interface class MiniProgramBackendConnector {
  Future<MiniProgramBackendResult> call(MiniProgramBackendRequest request);
}

abstract interface class DisposableMiniProgramBackendConnector
    implements MiniProgramBackendConnector {
  void dispose();
}

/// Resolves an authorized relative Publisher API request for streaming.
///
/// File providers receive this host-only result; mini-program JSON never sees
/// absolute Publisher API URLs or host request headers.
abstract interface class MiniProgramBackendTransferResolver {
  MiniProgramResolvedBackendTransfer resolveTransfer(
    MiniProgramBackendRequest request,
  );
}
