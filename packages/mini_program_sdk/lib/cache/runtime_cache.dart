import 'dart:convert';

import 'package:flutter/foundation.dart';

typedef MiniProgramCacheClock = DateTime Function();

enum MiniProgramCacheBucket { memory, data, image, video, session, state }

enum MiniProgramCacheStorage {
  disabled,
  memory,
  persistent,
  securePersistent,
  temporary,
}

enum MiniProgramCachePriority { low, normal, high, protected }

abstract interface class MiniProgramCachePolicyProvider {
  MiniProgramCachePolicy cachePolicyFor(String miniProgramId);
}

@immutable
class MiniProgramCachePolicy {
  const MiniProgramCachePolicy({
    this.enabled = true,
    this.memoryTtl = const Duration(hours: 2),
    this.dataTtl = const Duration(days: 30),
    this.imageTtl = const Duration(days: 14),
    this.videoTtl = const Duration(hours: 6),
    this.stateInactiveTtl = const Duration(days: 60),
    this.sessionInactiveTtl = const Duration(days: 60),
    this.maxBytes = 20 * 1024 * 1024,
    this.maxDataBytes = 10 * 1024 * 1024,
    this.maxImageBytes = 20 * 1024 * 1024,
    this.maxVideoBytes = 50 * 1024 * 1024,
    this.maxSessionBytes = 512 * 1024,
    this.clearMemoryOnExit = true,
    this.clearExpiredOnStartup = true,
    this.clearSessionOnLogout = true,
    this.clearStateOnInactiveExpiry = true,
    this.clearWhenOverLimit = true,
  });

  final bool enabled;
  final Duration memoryTtl;
  final Duration dataTtl;
  final Duration imageTtl;
  final Duration videoTtl;
  final Duration stateInactiveTtl;
  final Duration sessionInactiveTtl;
  final int maxBytes;
  final int maxDataBytes;
  final int maxImageBytes;
  final int maxVideoBytes;
  final int maxSessionBytes;
  final bool clearMemoryOnExit;
  final bool clearExpiredOnStartup;
  final bool clearSessionOnLogout;
  final bool clearStateOnInactiveExpiry;
  final bool clearWhenOverLimit;

  Duration ttlFor(MiniProgramCacheBucket bucket) {
    return switch (bucket) {
      MiniProgramCacheBucket.memory => memoryTtl,
      MiniProgramCacheBucket.data => dataTtl,
      MiniProgramCacheBucket.image => imageTtl,
      MiniProgramCacheBucket.video => videoTtl,
      MiniProgramCacheBucket.session => sessionInactiveTtl,
      MiniProgramCacheBucket.state => stateInactiveTtl,
    };
  }

  int? maxBytesFor(MiniProgramCacheBucket bucket) {
    return switch (bucket) {
      MiniProgramCacheBucket.data => maxDataBytes,
      MiniProgramCacheBucket.image => maxImageBytes,
      MiniProgramCacheBucket.video => maxVideoBytes,
      MiniProgramCacheBucket.session => maxSessionBytes,
      _ => null,
    };
  }
}

@immutable
class MiniProgramCacheEntry {
  const MiniProgramCacheEntry({
    required this.appId,
    required this.bucket,
    required this.key,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
    required this.lastAccessedAt,
    required this.expiresAt,
    required this.sizeBytes,
    required this.priority,
  });

  final String appId;
  final MiniProgramCacheBucket bucket;
  final String key;
  final Object? value;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastAccessedAt;
  final DateTime expiresAt;
  final int sizeBytes;
  final MiniProgramCachePriority priority;

  String get namespacedKey => MiniProgramCacheManager.namespacedKey(
    appId: appId,
    bucket: bucket,
    key: key,
  );

  bool isExpired(DateTime now) => !expiresAt.isAfter(now);

  MiniProgramCacheEntry copyWith({
    Object? value = _unset,
    DateTime? updatedAt,
    DateTime? lastAccessedAt,
    DateTime? expiresAt,
    int? sizeBytes,
    MiniProgramCachePriority? priority,
  }) {
    return MiniProgramCacheEntry(
      appId: appId,
      bucket: bucket,
      key: key,
      value: identical(value, _unset) ? this.value : value,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      priority: priority ?? this.priority,
    );
  }
}

@immutable
class MiniProgramCacheMetadata {
  const MiniProgramCacheMetadata({
    required this.appId,
    required this.firstOpenedAt,
    required this.lastOpenedAt,
    required this.lastAccessedAt,
    required this.totalBytes,
    required this.dataBytes,
    required this.imageBytes,
    required this.videoBytes,
    required this.sessionBytes,
    required this.stateBytes,
  });

  final String appId;
  final DateTime firstOpenedAt;
  final DateTime lastOpenedAt;
  final DateTime lastAccessedAt;
  final int totalBytes;
  final int dataBytes;
  final int imageBytes;
  final int videoBytes;
  final int sessionBytes;
  final int stateBytes;

  MiniProgramCacheMetadata copyWith({
    DateTime? firstOpenedAt,
    DateTime? lastOpenedAt,
    DateTime? lastAccessedAt,
    int? totalBytes,
    int? dataBytes,
    int? imageBytes,
    int? videoBytes,
    int? sessionBytes,
    int? stateBytes,
  }) {
    return MiniProgramCacheMetadata(
      appId: appId,
      firstOpenedAt: firstOpenedAt ?? this.firstOpenedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      totalBytes: totalBytes ?? this.totalBytes,
      dataBytes: dataBytes ?? this.dataBytes,
      imageBytes: imageBytes ?? this.imageBytes,
      videoBytes: videoBytes ?? this.videoBytes,
      sessionBytes: sessionBytes ?? this.sessionBytes,
      stateBytes: stateBytes ?? this.stateBytes,
    );
  }
}

abstract interface class MiniProgramCacheStore {
  Future<void> set(MiniProgramCacheEntry entry);
  Future<MiniProgramCacheEntry?> get(String namespacedKey);
  Future<void> remove(String namespacedKey);
  Future<void> clearApp(String appId);
  Future<void> clearBucket(String appId, MiniProgramCacheBucket bucket);
  Future<List<MiniProgramCacheEntry>> entries(String appId);
  Future<int> totalBytes(String appId);
}

abstract interface class MiniProgramIndexedCacheStore
    implements MiniProgramCacheStore {
  Future<List<String>> appIds();
}

class MiniProgramMemoryCacheStore implements MiniProgramIndexedCacheStore {
  final Map<String, MiniProgramCacheEntry> _entries =
      <String, MiniProgramCacheEntry>{};

  @override
  Future<void> set(MiniProgramCacheEntry entry) async {
    _entries[entry.namespacedKey] = entry;
  }

  @override
  Future<MiniProgramCacheEntry?> get(String namespacedKey) async {
    return _entries[namespacedKey];
  }

  @override
  Future<void> remove(String namespacedKey) async {
    _entries.remove(namespacedKey);
  }

  @override
  Future<void> clearApp(String appId) async {
    final prefix = 'mp_cache/${_normalizeAppId(appId)}/';
    _entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<void> clearBucket(String appId, MiniProgramCacheBucket bucket) async {
    final prefix = 'mp_cache/${_normalizeAppId(appId)}/${bucket.name}/';
    _entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<List<MiniProgramCacheEntry>> entries(String appId) async {
    final normalizedAppId = _normalizeAppId(appId);
    return _entries.values
        .where((entry) => entry.appId == normalizedAppId)
        .toList(growable: false);
  }

  @override
  Future<int> totalBytes(String appId) async {
    return (await entries(
      appId,
    )).fold<int>(0, (total, entry) => total + entry.sizeBytes);
  }

  @override
  Future<List<String>> appIds() async {
    return _entries.values
        .map((entry) => entry.appId)
        .toSet()
        .toList(growable: false);
  }
}

class MiniProgramCacheManager {
  MiniProgramCacheManager({
    MiniProgramCacheStore? store,
    this.defaultPolicy = const MiniProgramCachePolicy(),
    MiniProgramCacheClock? clock,
  }) : store = store ?? MiniProgramMemoryCacheStore(),
       _clock = clock ?? DateTime.now;

  factory MiniProgramCacheManager.inMemory({
    MiniProgramCachePolicy defaultPolicy = const MiniProgramCachePolicy(),
    MiniProgramCacheClock? clock,
  }) {
    return MiniProgramCacheManager(
      store: MiniProgramMemoryCacheStore(),
      defaultPolicy: defaultPolicy,
      clock: clock,
    );
  }

  final MiniProgramCacheStore store;
  final MiniProgramCachePolicy defaultPolicy;
  final MiniProgramCacheClock _clock;
  final Map<String, MiniProgramCachePolicy> _policies =
      <String, MiniProgramCachePolicy>{};
  final Map<String, MiniProgramCacheMetadata> _metadata =
      <String, MiniProgramCacheMetadata>{};
  final Set<String> _knownAppIds = <String>{};

  static String namespacedKey({
    required String appId,
    required MiniProgramCacheBucket bucket,
    required String key,
  }) {
    return 'mp_cache/${_normalizeAppId(appId)}/${bucket.name}/${_normalizeKey(key)}';
  }

  MiniProgramAppCache forApp(String appId, {MiniProgramCachePolicy? policy}) {
    return MiniProgramAppCache._(
      manager: this,
      appId: _normalizeAppId(appId),
      policy: policy,
    );
  }

  Future<void> openApp(String appId, {MiniProgramCachePolicy? policy}) async {
    final normalizedAppId = _rememberApp(appId, policy: policy);
    final effectivePolicy = _policyFor(normalizedAppId, policy);
    final now = _clock();
    final existing = _metadata[normalizedAppId];
    _metadata[normalizedAppId] =
        existing?.copyWith(lastOpenedAt: now, lastAccessedAt: now) ??
        MiniProgramCacheMetadata(
          appId: normalizedAppId,
          firstOpenedAt: now,
          lastOpenedAt: now,
          lastAccessedAt: now,
          totalBytes: 0,
          dataBytes: 0,
          imageBytes: 0,
          videoBytes: 0,
          sessionBytes: 0,
          stateBytes: 0,
        );
    if (effectivePolicy.clearExpiredOnStartup) {
      await clearExpired(appId: normalizedAppId, policy: effectivePolicy);
    }
    await clearInactiveSessions(policy: effectivePolicy);
    if (effectivePolicy.clearStateOnInactiveExpiry) {
      await clearInactiveState(policy: effectivePolicy);
    }
    if (effectivePolicy.clearWhenOverLimit) {
      await _enforceLimits(normalizedAppId, effectivePolicy);
    }
  }

  Future<void> closeApp(String appId, {MiniProgramCachePolicy? policy}) async {
    final normalizedAppId = _rememberApp(appId, policy: policy);
    final effectivePolicy = _policyFor(normalizedAppId, policy);
    if (effectivePolicy.clearMemoryOnExit) {
      await clearBucket(
        appId: normalizedAppId,
        bucket: MiniProgramCacheBucket.memory,
        policy: effectivePolicy,
      );
    }
  }

  Future<void> set({
    required String appId,
    required String key,
    required Object? value,
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
    Duration? ttl,
    MiniProgramCachePriority priority = MiniProgramCachePriority.normal,
    int? sizeBytes,
    MiniProgramCachePolicy? policy,
  }) {
    return _set(
      appId: appId,
      key: key,
      value: value,
      bucket: bucket,
      ttl: ttl,
      priority: priority,
      sizeBytes: sizeBytes,
      policy: policy,
      hostOwned: true,
    );
  }

  Future<T?> get<T>({
    required String appId,
    required String key,
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
    MiniProgramCachePolicy? policy,
  }) async {
    final normalizedAppId = _rememberApp(appId, policy: policy);
    final normalizedKey = _normalizeKey(key);
    final effectivePolicy = _policyFor(normalizedAppId, policy);
    if (!effectivePolicy.enabled) {
      return null;
    }
    final namespacedKey = MiniProgramCacheManager.namespacedKey(
      appId: normalizedAppId,
      bucket: bucket,
      key: normalizedKey,
    );
    final entry = await store.get(namespacedKey);
    if (entry == null) {
      return null;
    }
    final now = _clock();
    if (entry.isExpired(now)) {
      await store.remove(namespacedKey);
      await _refreshMetadata(normalizedAppId);
      return null;
    }
    await store.set(entry.copyWith(lastAccessedAt: now));
    await _touchApp(normalizedAppId);
    final value = entry.value;
    return value is T ? value : null;
  }

  Future<bool> has({
    required String appId,
    required String key,
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
    MiniProgramCachePolicy? policy,
  }) async {
    final normalizedAppId = _rememberApp(appId, policy: policy);
    final normalizedKey = _normalizeKey(key);
    final effectivePolicy = _policyFor(normalizedAppId, policy);
    if (!effectivePolicy.enabled) {
      return false;
    }
    final namespacedKey = MiniProgramCacheManager.namespacedKey(
      appId: normalizedAppId,
      bucket: bucket,
      key: normalizedKey,
    );
    final entry = await store.get(namespacedKey);
    if (entry == null) {
      return false;
    }
    final now = _clock();
    if (entry.isExpired(now)) {
      await store.remove(namespacedKey);
      await _refreshMetadata(normalizedAppId);
      return false;
    }
    await store.set(entry.copyWith(lastAccessedAt: now));
    await _touchApp(normalizedAppId);
    return true;
  }

  Future<void> remove({
    required String appId,
    required String key,
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
    MiniProgramCachePolicy? policy,
  }) async {
    final normalizedAppId = _rememberApp(appId, policy: policy);
    final namespacedKey = MiniProgramCacheManager.namespacedKey(
      appId: normalizedAppId,
      bucket: bucket,
      key: key,
    );
    await store.remove(namespacedKey);
    await _refreshMetadata(normalizedAppId);
  }

  Future<void> clear({
    required String appId,
    MiniProgramCacheBucket? bucket,
    MiniProgramCachePolicy? policy,
  }) async {
    if (bucket == null) {
      await clearApp(appId, policy: policy);
      return;
    }
    await clearBucket(appId: appId, bucket: bucket, policy: policy);
  }

  Future<void> clearApp(String appId, {MiniProgramCachePolicy? policy}) async {
    final normalizedAppId = _rememberApp(appId, policy: policy);
    await store.clearApp(normalizedAppId);
    await _refreshMetadata(normalizedAppId);
  }

  Future<void> clearBucket({
    required String appId,
    required MiniProgramCacheBucket bucket,
    MiniProgramCachePolicy? policy,
  }) async {
    final normalizedAppId = _rememberApp(appId, policy: policy);
    await store.clearBucket(normalizedAppId, bucket);
    await _refreshMetadata(normalizedAppId);
  }

  Future<void> clearExpired({
    String? appId,
    MiniProgramCachePolicy? policy,
  }) async {
    final now = _clock();
    final appIds = await _trackedAppIds(appId: appId, policy: policy);
    for (final candidate in appIds) {
      final normalizedAppId = _rememberApp(candidate, policy: policy);
      final entries = await store.entries(normalizedAppId);
      for (final entry in entries) {
        if (entry.isExpired(now)) {
          await store.remove(entry.namespacedKey);
        }
      }
      await _refreshMetadata(normalizedAppId);
    }
  }

  Future<void> clearLowPriority({String? appId}) async {
    final appIds = await _trackedAppIds(appId: appId);
    for (final candidate in appIds) {
      final normalizedAppId = _rememberApp(candidate);
      final entries = await store.entries(normalizedAppId);
      for (final entry in entries) {
        if (entry.priority == MiniProgramCachePriority.low) {
          await store.remove(entry.namespacedKey);
        }
      }
      await _refreshMetadata(normalizedAppId);
    }
  }

  Future<void> clearAllThirdParty() async {
    for (final appId in await _trackedAppIds()) {
      final entries = await store.entries(appId);
      for (final entry in entries) {
        if (entry.priority != MiniProgramCachePriority.protected) {
          await store.remove(entry.namespacedKey);
        }
      }
      await _refreshMetadata(appId);
    }
  }

  Future<void> clearOnLogout(
    String appId, {
    MiniProgramCachePolicy? policy,
  }) async {
    final normalizedAppId = _rememberApp(appId, policy: policy);
    final effectivePolicy = _policyFor(normalizedAppId, policy);
    if (!effectivePolicy.clearSessionOnLogout) {
      return;
    }
    await clearBucket(
      appId: normalizedAppId,
      bucket: MiniProgramCacheBucket.session,
      policy: effectivePolicy,
    );
  }

  Future<void> clearInactiveSessions({MiniProgramCachePolicy? policy}) async {
    final now = _clock();
    for (final metadata in _metadata.values.toList()) {
      final effectivePolicy = _policyFor(metadata.appId, policy);
      if (now.difference(metadata.lastOpenedAt) >
          effectivePolicy.sessionInactiveTtl) {
        await clearBucket(
          appId: metadata.appId,
          bucket: MiniProgramCacheBucket.session,
          policy: effectivePolicy,
        );
      }
    }
  }

  Future<void> clearInactiveState({MiniProgramCachePolicy? policy}) async {
    final now = _clock();
    for (final metadata in _metadata.values.toList()) {
      final effectivePolicy = _policyFor(metadata.appId, policy);
      if (now.difference(metadata.lastOpenedAt) >
          effectivePolicy.stateInactiveTtl) {
        await clearBucket(
          appId: metadata.appId,
          bucket: MiniProgramCacheBucket.state,
          policy: effectivePolicy,
        );
      }
    }
  }

  MiniProgramCacheMetadata? getMetadata(String appId) {
    return _metadata[_normalizeAppId(appId)];
  }

  Future<int> getTotalBytes({String? appId}) async {
    if (appId != null) {
      return store.totalBytes(_normalizeAppId(appId));
    }
    var total = 0;
    for (final knownAppId in await _trackedAppIds()) {
      total += await store.totalBytes(knownAppId);
    }
    return total;
  }

  Future<void> _set({
    required String appId,
    required String key,
    required Object? value,
    required MiniProgramCacheBucket bucket,
    required Duration? ttl,
    required MiniProgramCachePriority priority,
    required int? sizeBytes,
    required MiniProgramCachePolicy? policy,
    required bool hostOwned,
  }) async {
    final normalizedAppId = _rememberApp(appId, policy: policy);
    final normalizedKey = _normalizeKey(key);
    final effectivePolicy = _policyFor(normalizedAppId, policy);
    if (!effectivePolicy.enabled) {
      return;
    }
    if (!hostOwned && bucket == MiniProgramCacheBucket.session) {
      throw ArgumentError.value(
        bucket,
        'bucket',
        'The session cache bucket is host-controlled.',
      );
    }
    if (!hostOwned && priority == MiniProgramCachePriority.protected) {
      throw ArgumentError.value(
        priority,
        'priority',
        'Protected cache priority is host-controlled.',
      );
    }
    final normalizedValue = _normalizeCacheValue(value);
    final normalizedSize = sizeBytes ?? _encodedSize(normalizedValue);
    if (normalizedSize < 0) {
      throw ArgumentError.value(
        sizeBytes,
        'sizeBytes',
        'Cache size must be non-negative.',
      );
    }
    final resolvedTtl = _clampTtl(ttl, bucket: bucket, policy: effectivePolicy);
    final now = _clock();
    final namespacedKey = MiniProgramCacheManager.namespacedKey(
      appId: normalizedAppId,
      bucket: bucket,
      key: normalizedKey,
    );
    final existing = await store.get(namespacedKey);
    await store.set(
      MiniProgramCacheEntry(
        appId: normalizedAppId,
        bucket: bucket,
        key: normalizedKey,
        value: normalizedValue,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        lastAccessedAt: now,
        expiresAt: now.add(resolvedTtl),
        sizeBytes: normalizedSize,
        priority: priority,
      ),
    );
    await _touchApp(normalizedAppId);
    await _refreshMetadata(normalizedAppId);
    if (effectivePolicy.clearWhenOverLimit) {
      await _enforceLimits(normalizedAppId, effectivePolicy);
    }
  }

  Duration _clampTtl(
    Duration? requested, {
    required MiniProgramCacheBucket bucket,
    required MiniProgramCachePolicy policy,
  }) {
    final maxTtl = policy.ttlFor(bucket);
    if (requested == null) {
      return maxTtl;
    }
    if (requested <= Duration.zero) {
      throw ArgumentError.value(
        requested,
        'ttl',
        'Cache TTL must be positive.',
      );
    }
    return requested <= maxTtl ? requested : maxTtl;
  }

  Future<void> _enforceLimits(
    String appId,
    MiniProgramCachePolicy policy,
  ) async {
    await clearExpired(appId: appId, policy: policy);
    for (final bucket in MiniProgramCacheBucket.values) {
      final bucketLimit = policy.maxBytesFor(bucket);
      if (bucketLimit == null) {
        continue;
      }
      await _enforceBucketLimit(appId, bucket, bucketLimit);
    }
    await _enforceTotalLimit(appId, policy.maxBytes);
    await _refreshMetadata(appId);
  }

  Future<void> _enforceBucketLimit(
    String appId,
    MiniProgramCacheBucket bucket,
    int limit,
  ) async {
    var entries = (await store.entries(appId))
        .where(
          (entry) =>
              entry.bucket == bucket &&
              entry.priority != MiniProgramCachePriority.protected,
        )
        .toList();
    entries.sort(_cleanupCompare);
    var total = entries.fold<int>(0, (sum, entry) => sum + entry.sizeBytes);
    for (final entry in entries) {
      if (total <= limit) {
        return;
      }
      await store.remove(entry.namespacedKey);
      total -= entry.sizeBytes;
    }
  }

  Future<void> _enforceTotalLimit(String appId, int limit) async {
    var entries = (await store.entries(appId))
        .where((entry) => entry.priority != MiniProgramCachePriority.protected)
        .toList();
    entries.sort(_cleanupCompare);
    var total = (await store.entries(
      appId,
    )).fold<int>(0, (sum, entry) => sum + entry.sizeBytes);
    for (final entry in entries) {
      if (total <= limit) {
        return;
      }
      await store.remove(entry.namespacedKey);
      total -= entry.sizeBytes;
    }
  }

  int _cleanupCompare(MiniProgramCacheEntry a, MiniProgramCacheEntry b) {
    final priorityCompare = _priorityRank(
      a.priority,
    ).compareTo(_priorityRank(b.priority));
    if (priorityCompare != 0) {
      return priorityCompare;
    }
    final bucketCompare = _bucketCleanupRank(
      a.bucket,
    ).compareTo(_bucketCleanupRank(b.bucket));
    if (bucketCompare != 0) {
      return bucketCompare;
    }
    return a.lastAccessedAt.compareTo(b.lastAccessedAt);
  }

  int _priorityRank(MiniProgramCachePriority priority) {
    return switch (priority) {
      MiniProgramCachePriority.low => 0,
      MiniProgramCachePriority.normal => 1,
      MiniProgramCachePriority.high => 2,
      MiniProgramCachePriority.protected => 3,
    };
  }

  int _bucketCleanupRank(MiniProgramCacheBucket bucket) {
    return switch (bucket) {
      MiniProgramCacheBucket.video => 0,
      MiniProgramCacheBucket.image => 1,
      MiniProgramCacheBucket.data => 2,
      MiniProgramCacheBucket.state => 3,
      MiniProgramCacheBucket.memory => 4,
      MiniProgramCacheBucket.session => 5,
    };
  }

  String _rememberApp(String appId, {MiniProgramCachePolicy? policy}) {
    final normalizedAppId = _normalizeAppId(appId);
    _knownAppIds.add(normalizedAppId);
    if (policy != null) {
      _policies[normalizedAppId] = policy;
    }
    return normalizedAppId;
  }

  MiniProgramCachePolicy _policyFor(
    String appId,
    MiniProgramCachePolicy? override,
  ) {
    return override ?? _policies[appId] ?? defaultPolicy;
  }

  Future<List<String>> _trackedAppIds({
    String? appId,
    MiniProgramCachePolicy? policy,
  }) async {
    if (appId != null) {
      return <String>[_rememberApp(appId, policy: policy)];
    }
    final appIds = <String>{..._knownAppIds};
    final indexedStore = store;
    if (indexedStore is MiniProgramIndexedCacheStore) {
      appIds.addAll(await indexedStore.appIds());
    }
    return appIds.toList(growable: false);
  }

  Future<void> _touchApp(String appId) async {
    final now = _clock();
    final existing = _metadata[appId];
    if (existing == null) {
      _metadata[appId] = MiniProgramCacheMetadata(
        appId: appId,
        firstOpenedAt: now,
        lastOpenedAt: now,
        lastAccessedAt: now,
        totalBytes: 0,
        dataBytes: 0,
        imageBytes: 0,
        videoBytes: 0,
        sessionBytes: 0,
        stateBytes: 0,
      );
      return;
    }
    _metadata[appId] = existing.copyWith(lastAccessedAt: now);
  }

  Future<void> _refreshMetadata(String appId) async {
    final normalizedAppId = _normalizeAppId(appId);
    final entries = await store.entries(normalizedAppId);
    final existing = _metadata[normalizedAppId];
    final now = _clock();
    final firstOpenedAt = existing?.firstOpenedAt ?? now;
    final lastOpenedAt = existing?.lastOpenedAt ?? now;
    final lastAccessedAt = existing?.lastAccessedAt ?? now;
    _metadata[normalizedAppId] = MiniProgramCacheMetadata(
      appId: normalizedAppId,
      firstOpenedAt: firstOpenedAt,
      lastOpenedAt: lastOpenedAt,
      lastAccessedAt: lastAccessedAt,
      totalBytes: entries.fold<int>(0, (sum, entry) => sum + entry.sizeBytes),
      dataBytes: _bytesFor(entries, MiniProgramCacheBucket.data),
      imageBytes: _bytesFor(entries, MiniProgramCacheBucket.image),
      videoBytes: _bytesFor(entries, MiniProgramCacheBucket.video),
      sessionBytes: _bytesFor(entries, MiniProgramCacheBucket.session),
      stateBytes: _bytesFor(entries, MiniProgramCacheBucket.state),
    );
  }

  static int _bytesFor(
    List<MiniProgramCacheEntry> entries,
    MiniProgramCacheBucket bucket,
  ) {
    return entries
        .where((entry) => entry.bucket == bucket)
        .fold<int>(0, (sum, entry) => sum + entry.sizeBytes);
  }
}

class MiniProgramAppCache {
  const MiniProgramAppCache._({
    required MiniProgramCacheManager manager,
    required String appId,
    MiniProgramCachePolicy? policy,
  }) : _manager = manager,
       _appId = appId,
       _policy = policy;

  final MiniProgramCacheManager _manager;
  final String _appId;
  final MiniProgramCachePolicy? _policy;

  String get appId => _appId;

  Future<void> set(
    String key,
    Object? value, {
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
    Duration? ttl,
    MiniProgramCachePriority priority = MiniProgramCachePriority.normal,
  }) {
    return _manager._set(
      appId: _appId,
      key: key,
      value: value,
      bucket: bucket,
      ttl: ttl,
      priority: priority,
      sizeBytes: null,
      policy: _policy,
      hostOwned: false,
    );
  }

  Future<T?> get<T>(
    String key, {
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
  }) {
    return _manager.get<T>(
      appId: _appId,
      key: key,
      bucket: bucket,
      policy: _policy,
    );
  }

  Future<bool> has(
    String key, {
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
  }) {
    return _manager.has(
      appId: _appId,
      key: key,
      bucket: bucket,
      policy: _policy,
    );
  }

  Future<void> remove(
    String key, {
    MiniProgramCacheBucket bucket = MiniProgramCacheBucket.data,
  }) {
    return _manager.remove(
      appId: _appId,
      key: key,
      bucket: bucket,
      policy: _policy,
    );
  }

  Future<void> clear({MiniProgramCacheBucket? bucket}) {
    return _manager.clear(appId: _appId, bucket: bucket, policy: _policy);
  }
}

const Object _unset = Object();

String _normalizeAppId(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, 'appId', 'appId must not be blank.');
  }
  if (_unsafeKeyPattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      'appId',
      'appId cannot contain path traversal or separators.',
    );
  }
  return normalized;
}

String _normalizeKey(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, 'key', 'Cache key must not be blank.');
  }
  if (_unsafeKeyPattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      'key',
      'Cache key cannot contain path traversal or separators.',
    );
  }
  return normalized;
}

final RegExp _unsafeKeyPattern = RegExp(r'(^\.)|(\.\.)|[\\/]');

Object? _normalizeCacheValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is List) {
    return value.map(_normalizeCacheValue).toList(growable: false);
  }
  if (value is Map) {
    final normalized = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String || key.trim().isEmpty) {
        throw ArgumentError.value(
          key,
          'key',
          'Cache map keys must be non-empty strings.',
        );
      }
      normalized[key] = _normalizeCacheValue(entry.value);
    }
    return normalized;
  }
  throw ArgumentError.value(value, 'value', 'Unsupported cache value.');
}

int _encodedSize(Object? value) => utf8.encode(jsonEncode(value)).length;
