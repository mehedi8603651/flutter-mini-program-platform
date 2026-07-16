part of '../../mini_program_auth.dart';

class MiniProgramAuthController extends ChangeNotifier {
  MiniProgramAuthController({
    required MiniProgramAuthStore store,
    this.paths = const MiniProgramAuthBackendPaths(),
    MiniProgramAuthClock? clock,
  }) : _store = store,
       _clock = clock ?? (() => DateTime.now().toUtc());

  factory MiniProgramAuthController.inMemory({
    MiniProgramAuthBackendPaths paths = const MiniProgramAuthBackendPaths(),
    MiniProgramAuthClock? clock,
  }) {
    return MiniProgramAuthController(
      store: InMemoryMiniProgramAuthStore(),
      paths: paths,
      clock: clock,
    );
  }

  factory MiniProgramAuthController.secure({
    MiniProgramAuthBackendPaths paths = const MiniProgramAuthBackendPaths(),
    FlutterSecureStorage? storage,
    MiniProgramAuthClock? clock,
  }) {
    return MiniProgramAuthController(
      store: SecureMiniProgramAuthStore(storage: storage),
      paths: paths,
      clock: clock,
    );
  }

  final MiniProgramAuthStore _store;
  final MiniProgramAuthClock _clock;
  final MiniProgramAuthBackendPaths paths;
  final Map<String, MiniProgramAuthSession> _sessions =
      <String, MiniProgramAuthSession>{};
  final Map<String, MiniProgramAuthSnapshot> _snapshots =
      <String, MiniProgramAuthSnapshot>{};

  MiniProgramAuthSnapshot snapshot(String miniProgramId) {
    return _snapshots[miniProgramId.trim()] ??
        const MiniProgramAuthSnapshot.unknown();
  }

  MiniProgramAuthSession? session(String miniProgramId) {
    return _sessions[miniProgramId.trim()];
  }

  Future<MiniProgramAuthResult> restore({
    required String miniProgramId,
    required MiniProgramBackendConnector? connector,
  }) {
    return _restoreAuthSession(
      this,
      miniProgramId: miniProgramId,
      connector: connector,
    );
  }

  Future<MiniProgramAuthResult> signInEmail({
    required String miniProgramId,
    required MiniProgramBackendConnector connector,
    required String email,
    required String password,
  }) {
    return _runEmailAuth(
      this,
      miniProgramId: miniProgramId,
      connector: connector,
      endpoint: paths.emailSignIn,
      loadingStatus: MiniProgramAuthStatus.signingIn,
      email: email,
      password: password,
    );
  }

  Future<MiniProgramAuthResult> signUpEmail({
    required String miniProgramId,
    required MiniProgramBackendConnector connector,
    required String email,
    required String password,
  }) {
    return _runEmailAuth(
      this,
      miniProgramId: miniProgramId,
      connector: connector,
      endpoint: paths.emailSignUp,
      loadingStatus: MiniProgramAuthStatus.signingUp,
      email: email,
      password: password,
    );
  }

  Future<MiniProgramAuthResult> refresh({
    required String miniProgramId,
    required MiniProgramBackendConnector connector,
  }) {
    return _refreshAuthSession(
      this,
      miniProgramId: miniProgramId,
      connector: connector,
    );
  }

  Future<MiniProgramAuthResult> signOut({
    required String miniProgramId,
    required MiniProgramBackendConnector? connector,
  }) {
    return _signOutAuthSession(
      this,
      miniProgramId: miniProgramId,
      connector: connector,
    );
  }

  Future<MiniProgramBackendRequest> authorizeRequest({
    required MiniProgramBackendRequest request,
    required MiniProgramBackendConnector? connector,
  }) {
    return _authorizeAuthRequest(this, request: request, connector: connector);
  }

  void _setSnapshot(String appId, MiniProgramAuthSnapshot snapshot) {
    _snapshots[appId] = snapshot;
    notifyListeners();
  }
}
