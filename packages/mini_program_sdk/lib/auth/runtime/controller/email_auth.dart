part of '../../mini_program_auth.dart';

Future<MiniProgramAuthResult> _runEmailAuth(
  MiniProgramAuthController controller, {
  required String miniProgramId,
  required MiniProgramBackendConnector connector,
  required String endpoint,
  required MiniProgramAuthStatus loadingStatus,
  required String email,
  required String password,
}) async {
  final appId = miniProgramId.trim();
  final normalizedEmail = email.trim();
  if (normalizedEmail.isEmpty || password.isEmpty) {
    final snapshot = const MiniProgramAuthSnapshot(
      status: MiniProgramAuthStatus.error,
      message: 'Email and password are required.',
      errorCode: 'auth_validation_failed',
    );
    controller._setSnapshot(appId, snapshot);
    return MiniProgramAuthResult(
      success: false,
      snapshot: snapshot,
      message: snapshot.message,
      errorCode: snapshot.errorCode,
    );
  }

  controller._setSnapshot(
    appId,
    MiniProgramAuthSnapshot(status: loadingStatus),
  );
  final result = await connector.call(
    MiniProgramBackendRequest(
      miniProgramId: appId,
      endpoint: endpoint,
      method: 'POST',
      body: <String, dynamic>{'email': normalizedEmail, 'password': password},
    ),
  );
  if (result.isFailure) {
    final snapshot = MiniProgramAuthSnapshot(
      status: MiniProgramAuthStatus.error,
      message: result.message ?? 'Email auth failed.',
      errorCode: result.errorCode ?? 'auth_failed',
    );
    controller._setSnapshot(appId, snapshot);
    return MiniProgramAuthResult(
      success: false,
      snapshot: snapshot,
      message: snapshot.message,
      errorCode: snapshot.errorCode,
      statusCode: result.statusCode,
    );
  }
  return _storeBackendAuthSession(controller, appId: appId, result: result);
}
