import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

@immutable
class CachedManifestEntry {
  const CachedManifestEntry({
    required this.miniProgramId,
    required this.manifest,
    required this.cachedAt,
  });

  final String miniProgramId;
  final MiniProgramManifest manifest;
  final DateTime cachedAt;
}

abstract interface class ManifestCache {
  CachedManifestEntry? read(String miniProgramId);

  void write(CachedManifestEntry entry);

  void remove(String miniProgramId);

  void clear();
}

class InMemoryManifestCache implements ManifestCache {
  InMemoryManifestCache();

  static final InMemoryManifestCache shared = InMemoryManifestCache();

  final Map<String, CachedManifestEntry> _entries =
      <String, CachedManifestEntry>{};

  @override
  CachedManifestEntry? read(String miniProgramId) => _entries[miniProgramId];

  @override
  void write(CachedManifestEntry entry) {
    _entries[entry.miniProgramId] = entry;
  }

  @override
  void remove(String miniProgramId) {
    _entries.remove(miniProgramId);
  }

  @override
  void clear() {
    _entries.clear();
  }
}
