part of '../mini_program_auth.dart';

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
