import 'entry.dart';

abstract interface class ScreenCache {
  Future<CachedScreenEntry?> read({
    required String miniProgramId,
    required String version,
    required String screenId,
  });

  Future<void> write(CachedScreenEntry entry);

  Future<void> remove({
    required String miniProgramId,
    required String version,
    required String screenId,
  });

  Future<void> clear();
}
