import 'entry.dart';

abstract interface class ManifestCache {
  Future<CachedManifestEntry?> read(String miniProgramId);

  Future<void> write(CachedManifestEntry entry);

  Future<void> remove(String miniProgramId);

  Future<void> clear();
}
