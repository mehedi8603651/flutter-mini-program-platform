part of '../../mini_program_backend_connector.dart';

abstract interface class MiniProgramBackendConnector {
  Future<MiniProgramBackendResult> call(MiniProgramBackendRequest request);
}

abstract interface class DisposableMiniProgramBackendConnector
    implements MiniProgramBackendConnector {
  void dispose();
}
