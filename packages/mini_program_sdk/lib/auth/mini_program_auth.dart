import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/mini_program_backend_connector.dart';

typedef MiniProgramAuthClock = DateTime Function();

abstract final class MiniProgramAuthHttpHeaders {
  static const String authorization = 'authorization';
}

@immutable
class MiniProgramAuthBackendPaths {
  const MiniProgramAuthBackendPaths({
    this.emailSignIn = 'auth/email/sign-in',
    this.emailSignUp = 'auth/email/sign-up',
    this.refresh = 'auth/refresh',
    this.signOut = 'auth/sign-out',
    this.session = 'auth/session',
  });

  final String emailSignIn;
  final String emailSignUp;
  final String refresh;
  final String signOut;
  final String session;
}

@immutable
class MiniProgramAuthUser {
  const MiniProgramAuthUser({required this.uid, this.email});

  final String uid;
  final String? email;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'uid': uid,
    if (email != null) 'email': email,
  };

  Map<String, dynamic> toBindingData() => toJson();

  factory MiniProgramAuthUser.fromJson(Map<String, dynamic> json) {
    final uid = json['uid'];
    if (uid is! String || uid.trim().isEmpty) {
      throw const FormatException('Auth user requires a non-empty uid.');
    }
    final email = json['email'];
    if (email != null && email is! String) {
      throw const FormatException('Auth user email must be a string.');
    }
    return MiniProgramAuthUser(
      uid: uid.trim(),
      email: email == null || email.trim().isEmpty ? null : email.trim(),
    );
  }
}

@immutable
class MiniProgramAuthSession {
  const MiniProgramAuthSession({
    required this.miniProgramId,
    required this.user,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAtUtc,
  });

  final String miniProgramId;
  final MiniProgramAuthUser user;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAtUtc;

  bool isExpired({
    DateTime? nowUtc,
    Duration skew = const Duration(seconds: 30),
  }) {
    final now = (nowUtc ?? DateTime.now().toUtc()).toUtc();
    return !expiresAtUtc.toUtc().isAfter(now.add(skew));
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'miniProgramId': miniProgramId,
    'user': user.toJson(),
    'idToken': idToken,
    'refreshToken': refreshToken,
    'expiresAtUtc': expiresAtUtc.toUtc().toIso8601String(),
  };

  Map<String, dynamic> toBindingData() => <String, dynamic>{
    'miniProgramId': miniProgramId,
    'user': user.toBindingData(),
    'expiresAtUtc': expiresAtUtc.toUtc().toIso8601String(),
  };

  factory MiniProgramAuthSession.fromJson(Map<String, dynamic> json) {
    final miniProgramId = json['miniProgramId'];
    final user = json['user'];
    final idToken = json['idToken'];
    final refreshToken = json['refreshToken'];
    final expiresAtUtc = json['expiresAtUtc'];
    if (miniProgramId is! String || miniProgramId.trim().isEmpty) {
      throw const FormatException('Auth session requires a miniProgramId.');
    }
    if (user is! Map) {
      throw const FormatException('Auth session requires a user object.');
    }
    if (idToken is! String || idToken.trim().isEmpty) {
      throw const FormatException('Auth session requires an idToken.');
    }
    if (refreshToken is! String || refreshToken.trim().isEmpty) {
      throw const FormatException('Auth session requires a refreshToken.');
    }
    if (expiresAtUtc is! String || expiresAtUtc.trim().isEmpty) {
      throw const FormatException('Auth session requires expiresAtUtc.');
    }
    final parsedExpiry = DateTime.tryParse(expiresAtUtc);
    if (parsedExpiry == null) {
      throw const FormatException('Auth session expiresAtUtc is invalid.');
    }
    return MiniProgramAuthSession(
      miniProgramId: miniProgramId.trim(),
      user: MiniProgramAuthUser.fromJson(Map<String, dynamic>.from(user)),
      idToken: idToken.trim(),
      refreshToken: refreshToken.trim(),
      expiresAtUtc: parsedExpiry.toUtc(),
    );
  }

  static MiniProgramAuthSession fromBackendData({
    required String miniProgramId,
    required Map<String, dynamic> data,
    required DateTime nowUtc,
  }) {
    final authenticated = data['authenticated'];
    if (authenticated == false) {
      throw const FormatException('Auth response is not authenticated.');
    }
    final rawUser = data['user'];
    final idToken = data['idToken'];
    final refreshToken = data['refreshToken'];
    if (rawUser is! Map) {
      throw const FormatException('Auth response requires a user object.');
    }
    if (idToken is! String || idToken.trim().isEmpty) {
      throw const FormatException('Auth response requires an idToken.');
    }
    if (refreshToken is! String || refreshToken.trim().isEmpty) {
      throw const FormatException('Auth response requires a refreshToken.');
    }

    final expiresAtUtc = _parseExpiry(data, nowUtc);
    return MiniProgramAuthSession(
      miniProgramId: miniProgramId.trim(),
      user: MiniProgramAuthUser.fromJson(Map<String, dynamic>.from(rawUser)),
      idToken: idToken.trim(),
      refreshToken: refreshToken.trim(),
      expiresAtUtc: expiresAtUtc,
    );
  }

  static DateTime _parseExpiry(Map<String, dynamic> data, DateTime nowUtc) {
    final expiresAtUtc = data['expiresAtUtc'];
    if (expiresAtUtc is String && expiresAtUtc.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(expiresAtUtc);
      if (parsed != null) {
        return parsed.toUtc();
      }
    }

    final expiresIn = data['expiresIn'];
    final seconds = switch (expiresIn) {
      int value => value,
      String value => int.tryParse(value),
      _ => null,
    };
    if (seconds == null || seconds <= 0) {
      throw const FormatException(
        'Auth response requires expiresIn or expiresAtUtc.',
      );
    }
    return nowUtc.toUtc().add(Duration(seconds: seconds));
  }
}

enum MiniProgramAuthStatus {
  unknown,
  restoring,
  signedOut,
  signingIn,
  signingUp,
  refreshing,
  signedIn,
  error,
}

@immutable
class MiniProgramAuthSnapshot {
  const MiniProgramAuthSnapshot({
    required this.status,
    this.user,
    this.message,
    this.errorCode,
    this.expiresAtUtc,
  });

  const MiniProgramAuthSnapshot.unknown()
    : status = MiniProgramAuthStatus.unknown,
      user = null,
      message = null,
      errorCode = null,
      expiresAtUtc = null;

  const MiniProgramAuthSnapshot.signedOut({this.message})
    : status = MiniProgramAuthStatus.signedOut,
      user = null,
      errorCode = null,
      expiresAtUtc = null;

  MiniProgramAuthSnapshot.fromSession(MiniProgramAuthSession session)
    : status = MiniProgramAuthStatus.signedIn,
      user = session.user,
      message = null,
      errorCode = null,
      expiresAtUtc = session.expiresAtUtc;

  final MiniProgramAuthStatus status;
  final MiniProgramAuthUser? user;
  final String? message;
  final String? errorCode;
  final DateTime? expiresAtUtc;

  bool get authenticated => status == MiniProgramAuthStatus.signedIn;
  bool get loading =>
      status == MiniProgramAuthStatus.restoring ||
      status == MiniProgramAuthStatus.signingIn ||
      status == MiniProgramAuthStatus.signingUp ||
      status == MiniProgramAuthStatus.refreshing;
  bool get signedOut => status == MiniProgramAuthStatus.signedOut;
  bool get hasError => status == MiniProgramAuthStatus.error;

  Map<String, dynamic> toBindingData() => <String, dynamic>{
    'status': status.name,
    'authenticated': authenticated,
    'loading': loading,
    'signedOut': signedOut,
    'error': hasError,
    if (user != null) 'user': user!.toBindingData(),
    if (message != null) 'message': message,
    if (errorCode != null) 'errorCode': errorCode,
    if (expiresAtUtc != null)
      'expiresAtUtc': expiresAtUtc!.toUtc().toIso8601String(),
  };
}

@immutable
class MiniProgramAuthResult {
  const MiniProgramAuthResult({
    required this.success,
    required this.snapshot,
    this.message,
    this.errorCode,
    this.statusCode,
  });

  final bool success;
  final MiniProgramAuthSnapshot snapshot;
  final String? message;
  final String? errorCode;
  final int? statusCode;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'success': success,
    'authenticated': snapshot.authenticated,
    'status': snapshot.status.name,
    if (message != null) 'message': message,
    if (errorCode != null) 'errorCode': errorCode,
    if (statusCode != null) 'statusCode': statusCode,
    'auth': snapshot.toBindingData(),
  };
}

abstract interface class MiniProgramAuthStore {
  Future<MiniProgramAuthSession?> read(String miniProgramId);
  Future<void> write(String miniProgramId, MiniProgramAuthSession session);
  Future<void> delete(String miniProgramId);
}

class InMemoryMiniProgramAuthStore implements MiniProgramAuthStore {
  final Map<String, MiniProgramAuthSession> _sessions =
      <String, MiniProgramAuthSession>{};

  @override
  Future<MiniProgramAuthSession?> read(String miniProgramId) async {
    return _sessions[miniProgramId.trim()];
  }

  @override
  Future<void> write(
    String miniProgramId,
    MiniProgramAuthSession session,
  ) async {
    _sessions[miniProgramId.trim()] = session;
  }

  @override
  Future<void> delete(String miniProgramId) async {
    _sessions.remove(miniProgramId.trim());
  }
}

class SecureMiniProgramAuthStore implements MiniProgramAuthStore {
  SecureMiniProgramAuthStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<MiniProgramAuthSession?> read(String miniProgramId) async {
    final raw = await _storage.read(key: _key(miniProgramId));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      await delete(miniProgramId);
      return null;
    }
    try {
      return MiniProgramAuthSession.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on FormatException {
      await delete(miniProgramId);
      return null;
    }
  }

  @override
  Future<void> write(String miniProgramId, MiniProgramAuthSession session) {
    return _storage.write(key: _key(miniProgramId), value: jsonEncode(session));
  }

  @override
  Future<void> delete(String miniProgramId) {
    return _storage.delete(key: _key(miniProgramId));
  }

  String _key(String miniProgramId) {
    final normalized = miniProgramId.trim();
    final encoded = base64Url.encode(utf8.encode(normalized));
    return 'mini_program_auth_session::$encoded';
  }
}

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
  }) async {
    final appId = miniProgramId.trim();
    _setSnapshot(
      appId,
      const MiniProgramAuthSnapshot(status: MiniProgramAuthStatus.restoring),
    );
    final stored = await _store.read(appId);
    if (stored == null) {
      _sessions.remove(appId);
      final snapshot = const MiniProgramAuthSnapshot.signedOut();
      _setSnapshot(appId, snapshot);
      return MiniProgramAuthResult(success: true, snapshot: snapshot);
    }

    _sessions[appId] = stored;
    if (!stored.isExpired(nowUtc: _clock())) {
      final snapshot = MiniProgramAuthSnapshot.fromSession(stored);
      _setSnapshot(appId, snapshot);
      return MiniProgramAuthResult(success: true, snapshot: snapshot);
    }

    if (connector == null) {
      await _clear(appId);
      final snapshot = const MiniProgramAuthSnapshot.signedOut(
        message: 'Cached session expired.',
      );
      _setSnapshot(appId, snapshot);
      return MiniProgramAuthResult(success: false, snapshot: snapshot);
    }

    return refresh(miniProgramId: appId, connector: connector);
  }

  Future<MiniProgramAuthResult> signInEmail({
    required String miniProgramId,
    required MiniProgramBackendConnector connector,
    required String email,
    required String password,
  }) {
    return _emailAuth(
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
    return _emailAuth(
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
  }) async {
    final appId = miniProgramId.trim();
    final current = _sessions[appId] ?? await _store.read(appId);
    if (current == null) {
      final snapshot = const MiniProgramAuthSnapshot.signedOut();
      _setSnapshot(appId, snapshot);
      return MiniProgramAuthResult(success: false, snapshot: snapshot);
    }

    _setSnapshot(
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
        endpoint: paths.refresh,
        method: 'POST',
        body: <String, dynamic>{'refreshToken': current.refreshToken},
      ),
    );
    if (result.isFailure) {
      await _clear(appId);
      final snapshot = MiniProgramAuthSnapshot(
        status: MiniProgramAuthStatus.error,
        message: result.message ?? 'Failed to refresh auth session.',
        errorCode: result.errorCode ?? 'auth_refresh_failed',
      );
      _setSnapshot(appId, snapshot);
      return MiniProgramAuthResult(
        success: false,
        snapshot: snapshot,
        message: snapshot.message,
        errorCode: snapshot.errorCode,
        statusCode: result.statusCode,
      );
    }

    return _storeBackendSession(appId: appId, result: result);
  }

  Future<MiniProgramAuthResult> signOut({
    required String miniProgramId,
    required MiniProgramBackendConnector? connector,
  }) async {
    final appId = miniProgramId.trim();
    final current = _sessions[appId] ?? await _store.read(appId);
    await _clear(appId);
    if (connector != null && current != null) {
      await connector.call(
        MiniProgramBackendRequest(
          miniProgramId: appId,
          endpoint: paths.signOut,
          method: 'POST',
          body: <String, dynamic>{'refreshToken': current.refreshToken},
        ),
      );
    }
    final snapshot = const MiniProgramAuthSnapshot.signedOut();
    _setSnapshot(appId, snapshot);
    return MiniProgramAuthResult(success: true, snapshot: snapshot);
  }

  Future<MiniProgramBackendRequest> authorizeRequest({
    required MiniProgramBackendRequest request,
    required MiniProgramBackendConnector? connector,
  }) async {
    final appId = request.miniProgramId.trim();
    var current = _sessions[appId] ?? await _store.read(appId);
    if (current == null) {
      return request;
    }
    if (current.isExpired(nowUtc: _clock()) && connector != null) {
      final refreshResult = await refresh(
        miniProgramId: appId,
        connector: connector,
      );
      if (!refreshResult.success) {
        return request;
      }
      current = _sessions[appId];
    }
    if (current == null ||
        current.isExpired(nowUtc: _clock(), skew: Duration.zero)) {
      return request;
    }
    return request.copyWith(
      headers: <String, String>{
        ...request.headers,
        MiniProgramAuthHttpHeaders.authorization: 'Bearer ${current.idToken}',
      },
    );
  }

  Future<MiniProgramAuthResult> _emailAuth({
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
      _setSnapshot(appId, snapshot);
      return MiniProgramAuthResult(
        success: false,
        snapshot: snapshot,
        message: snapshot.message,
        errorCode: snapshot.errorCode,
      );
    }

    _setSnapshot(appId, MiniProgramAuthSnapshot(status: loadingStatus));
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
      _setSnapshot(appId, snapshot);
      return MiniProgramAuthResult(
        success: false,
        snapshot: snapshot,
        message: snapshot.message,
        errorCode: snapshot.errorCode,
        statusCode: result.statusCode,
      );
    }
    return _storeBackendSession(appId: appId, result: result);
  }

  Future<MiniProgramAuthResult> _storeBackendSession({
    required String appId,
    required MiniProgramBackendResult result,
  }) async {
    try {
      final session = MiniProgramAuthSession.fromBackendData(
        miniProgramId: appId,
        data: result.data,
        nowUtc: _clock(),
      );
      _sessions[appId] = session;
      await _store.write(appId, session);
      final snapshot = MiniProgramAuthSnapshot.fromSession(session);
      _setSnapshot(appId, snapshot);
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
      _setSnapshot(appId, snapshot);
      return MiniProgramAuthResult(
        success: false,
        snapshot: snapshot,
        message: snapshot.message,
        errorCode: snapshot.errorCode,
        statusCode: result.statusCode,
      );
    }
  }

  Future<void> _clear(String appId) async {
    _sessions.remove(appId);
    await _store.delete(appId);
  }

  void _setSnapshot(String appId, MiniProgramAuthSnapshot snapshot) {
    _snapshots[appId] = snapshot;
    notifyListeners();
  }
}
