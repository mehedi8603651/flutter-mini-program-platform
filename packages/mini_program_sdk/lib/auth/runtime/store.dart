part of '../mini_program_auth.dart';

abstract interface class MiniProgramAuthStore {
  Future<MiniProgramAuthSession?> read(String miniProgramId);
  Future<void> write(String miniProgramId, MiniProgramAuthSession session);
  Future<void> delete(String miniProgramId);
}
