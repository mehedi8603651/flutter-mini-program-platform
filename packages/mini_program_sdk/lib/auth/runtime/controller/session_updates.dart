part of '../../mini_program_auth.dart';

Future<MiniProgramAuthResult> _storeBackendAuthSession(
  MiniProgramAuthController controller, {
  required String appId,
  required MiniProgramBackendResult result,
}) async {
  try {
    final session = MiniProgramAuthSession.fromBackendData(
      miniProgramId: appId,
      data: result.data,
      nowUtc: controller._clock(),
    );
    controller._sessions[appId] = session;
    await controller._store.write(appId, session);
    final snapshot = MiniProgramAuthSnapshot.fromSession(session);
    controller._setSnapshot(appId, snapshot);
    return MiniProgramAuthResult(
      success: true,
      snapshot: snapshot,
      message: result.message,
      statusCode: result.statusCode,
    );
  } on FormatException catch (error) {
    final snapshot = MiniProgramAuthSnapshot(
      status: MiniProgramAuthStatus.error,
      message: error.message,
      errorCode: 'invalid_auth_response',
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
}

Future<void> _clearAuthSession(
  MiniProgramAuthController controller,
  String appId,
) async {
  controller._sessions.remove(appId);
  await controller._store.delete(appId);
}
