part of '../../mini_program_auth.dart';

Future<MiniProgramAuthResult> _restoreAuthSession(
  MiniProgramAuthController controller, {
  required String miniProgramId,
  required MiniProgramBackendConnector? connector,
}) async {
  final appId = miniProgramId.trim();
  controller._setSnapshot(
    appId,
    const MiniProgramAuthSnapshot(status: MiniProgramAuthStatus.restoring),
  );
  final stored = await controller._store.read(appId);
  if (stored == null) {
    controller._sessions.remove(appId);
    final snapshot = const MiniProgramAuthSnapshot.signedOut();
    controller._setSnapshot(appId, snapshot);
    return MiniProgramAuthResult(success: true, snapshot: snapshot);
  }

  controller._sessions[appId] = stored;
  if (!stored.isExpired(nowUtc: controller._clock())) {
    final snapshot = MiniProgramAuthSnapshot.fromSession(stored);
    controller._setSnapshot(appId, snapshot);
    return MiniProgramAuthResult(success: true, snapshot: snapshot);
  }

  if (connector == null) {
    await _clearAuthSession(controller, appId);
    final snapshot = const MiniProgramAuthSnapshot.signedOut(
      message: 'Cached session expired.',
    );
    controller._setSnapshot(appId, snapshot);
    return MiniProgramAuthResult(success: false, snapshot: snapshot);
  }

  return controller.refresh(miniProgramId: appId, connector: connector);
}
