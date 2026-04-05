import 'package:flutter/foundation.dart';

@immutable
class CachedScreenEntry {
  const CachedScreenEntry({
    required this.miniProgramId,
    required this.version,
    required this.screenId,
    required this.screenJson,
    required this.cachedAt,
  });

  final String miniProgramId;
  final String version;
  final String screenId;
  final Map<String, dynamic> screenJson;
  final DateTime cachedAt;

  String get cacheKey => _buildScreenCacheKey(
    miniProgramId: miniProgramId,
    version: version,
    screenId: screenId,
  );
}

abstract interface class ScreenCache {
  CachedScreenEntry? read({
    required String miniProgramId,
    required String version,
    required String screenId,
  });

  void write(CachedScreenEntry entry);

  void remove({
    required String miniProgramId,
    required String version,
    required String screenId,
  });

  void clear();
}

class InMemoryScreenCache implements ScreenCache {
  InMemoryScreenCache();

  static final InMemoryScreenCache shared = InMemoryScreenCache();

  final Map<String, CachedScreenEntry> _entries = <String, CachedScreenEntry>{};

  @override
  CachedScreenEntry? read({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) {
    return _entries[_buildScreenCacheKey(
      miniProgramId: miniProgramId,
      version: version,
      screenId: screenId,
    )];
  }

  @override
  void write(CachedScreenEntry entry) {
    _entries[entry.cacheKey] = entry;
  }

  @override
  void remove({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) {
    _entries.remove(
      _buildScreenCacheKey(
        miniProgramId: miniProgramId,
        version: version,
        screenId: screenId,
      ),
    );
  }

  @override
  void clear() {
    _entries.clear();
  }
}

String _buildScreenCacheKey({
  required String miniProgramId,
  required String version,
  required String screenId,
}) => '$miniProgramId::$version::$screenId';
