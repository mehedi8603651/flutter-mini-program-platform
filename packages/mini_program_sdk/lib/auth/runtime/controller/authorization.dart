part of '../../mini_program_auth.dart';

Future<MiniProgramBackendRequest> _authorizeAuthRequest(
  MiniProgramAuthController controller, {
  required MiniProgramBackendRequest request,
  required MiniProgramBackendConnector? connector,
}) async {
  final appId = request.miniProgramId.trim();
  var current =
      controller._sessions[appId] ?? await controller._store.read(appId);
  if (current == null) {
    return request;
  }
  if (current.isExpired(nowUtc: controller._clock()) && connector != null) {
    final refreshResult = await controller.refresh(
      miniProgramId: appId,
      connector: connector,
    );
    if (!refreshResult.success) {
      return request;
    }
    current = controller._sessions[appId];
  }
  if (current == null ||
      current.isExpired(nowUtc: controller._clock(), skew: Duration.zero)) {
    return request;
  }
  return request.copyWith(
    headers: <String, String>{
      ...request.headers,
      MiniProgramAuthHttpHeaders.authorization: 'Bearer ${current.idToken}',
    },
  );
}
