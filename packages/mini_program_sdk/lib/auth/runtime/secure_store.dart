part of '../mini_program_auth.dart';

class SecureMiniProgramAuthStore implements MiniProgramAuthStore {
  SecureMiniProgramAuthStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<MiniProgramAuthSession?> read(String miniProgramId) async {
    final raw = await _storage.read(key: _secureAuthStorageKey(miniProgramId));
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
    return _storage.write(
      key: _secureAuthStorageKey(miniProgramId),
      value: jsonEncode(session),
    );
  }

  @override
  Future<void> delete(String miniProgramId) {
    return _storage.delete(key: _secureAuthStorageKey(miniProgramId));
  }
}

String _secureAuthStorageKey(String miniProgramId) {
  final normalized = miniProgramId.trim();
  final encoded = base64Url.encode(utf8.encode(normalized));
  return 'mini_program_auth_session::$encoded';
}
