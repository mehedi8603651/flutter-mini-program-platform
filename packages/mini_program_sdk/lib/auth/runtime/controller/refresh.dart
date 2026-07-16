part of '../../mini_program_auth.dart';

Future<MiniProgramAuthResult> _refreshAuthSession(
  MiniProgramAuthController controller, {
  required String miniProgramId,
  required MiniProgramBackendConnector connector,
}) async {
  final appId = miniProgramId.trim();
  final current =
      controller._sessions[appId] ?? await controller._store.read(appId);
  if (current == null) {
    final snapshot = const MiniProgramAuthSnapshot.signedOut();
    controller._setSnapshot(appId, snapshot);
    return MiniProgramAuthResult(success: false, snapshot: snapshot);
  }

  controller._setSnapshot(
    appId,
    MiniProgramAuthSnapshot(
      status: MiniProgramAuthStatus.refreshing,
      user: current.user,
      expiresAtUtc: current.expiresAtUtc,
    ),
  );
  final result = await connector.call(
    MiniProgramBackendRequest(
      miniProgramId: appId,
      endpoint: controller.paths.refresh,
      method: 'POST',
      body: <String, dynamic>{'refreshToken': current.refreshToken},
    ),
  );
  if (result.isFailure) {
    await _clearAuthSession(controller, appId);
    final snapshot = MiniProgramAuthSnapshot(
      status: MiniProgramAuthStatus.error,
      message: result.message ?? 'Failed to refresh auth session.',
      errorCode: result.errorCode ?? 'auth_refresh_failed',
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

Future<MiniProgramAuthResult> _signOutAuthSession(
  MiniProgramAuthController controller, {
  required String miniProgramId,
  required MiniProgramBackendConnector? connector,
}) async {
  final appId = miniProgramId.trim();
  final current =
      controller._sessions[appId] ?? await controller._store.read(appId);
  await _clearAuthSession(controller, appId);
  if (connector != null && current != null) {
    await connector.call(
      MiniProgramBackendRequest(
        miniProgramId: appId,
        endpoint: controller.paths.signOut,
        method: 'POST',
        body: <String, dynamic>{'refreshToken': current.refreshToken},
      ),
    );
  }
  final snapshot = const MiniProgramAuthSnapshot.signedOut();
  controller._setSnapshot(appId, snapshot);
  return MiniProgramAuthResult(success: true, snapshot: snapshot);
}
