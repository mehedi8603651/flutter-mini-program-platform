import 'entry.dart';
import 'store.dart';

class InMemoryManifestCache implements ManifestCache {
  InMemoryManifestCache();

  static final InMemoryManifestCache shared = InMemoryManifestCache();

  final Map<String, CachedManifestEntry> _entries =
      <String, CachedManifestEntry>{};

  @override
  Future<CachedManifestEntry?> read(String miniProgramId) async {
    return _entries[miniProgramId];
  }

  @override
  Future<void> write(CachedManifestEntry entry) async {
    _entries[entry.miniProgramId] = entry;
  }

  @override
  Future<void> remove(String miniProgramId) async {
    _entries.remove(miniProgramId);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }
}
