import 'entry.dart';
import 'keys.dart';
import 'store.dart';

class InMemoryScreenCache implements ScreenCache {
  InMemoryScreenCache();

  static final InMemoryScreenCache shared = InMemoryScreenCache();

  final Map<String, CachedScreenEntry> _entries = <String, CachedScreenEntry>{};

  @override
  Future<CachedScreenEntry?> read({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    return _entries[buildScreenCacheKey(
      miniProgramId: miniProgramId,
      version: version,
      screenId: screenId,
    )];
  }

  @override
  Future<void> write(CachedScreenEntry entry) async {
    _entries[entry.cacheKey] = entry;
  }

  @override
  Future<void> remove({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    _entries.remove(
      buildScreenCacheKey(
        miniProgramId: miniProgramId,
        version: version,
        screenId: screenId,
      ),
    );
  }

  @override
  Future<void> clear() async {
    _entries.clear();
  }
}
