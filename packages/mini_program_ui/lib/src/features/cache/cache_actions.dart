import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';
import '../../core/value_normalization.dart';

final RegExp _unsafeCacheKeyPattern = RegExp(r'(^\.)|(\.\.)|[\\/:]');

const Set<String> _allowedCacheBuckets = <String>{
  'memory',
  'data',
  'image',
  'state',
  'video',
};

const Set<String> _allowedCachePriorities = <String>{'low', 'normal', 'high'};

/// Mini-program cache action builders.
final class MpCacheActions {
  /// Creates cache action helpers.
  const MpCacheActions();

  /// Runtime-only cache. Hosts usually clear this when the mini-program exits.
  MpCacheBucketActions get memory => const MpCacheBucketActions._('memory');

  /// General persistent data cache.
  MpCacheBucketActions get data => const MpCacheBucketActions._('data');

  /// Image metadata or image-related cache controlled by host policy.
  MpCacheBucketActions get image => const MpCacheBucketActions._('image');

  /// Mini-program UI state cache, such as calculator history or selected tabs.
  MpCacheBucketActions get state => const MpCacheBucketActions._('state');

  /// Video metadata or video-related cache controlled by host policy.
  MpCacheBucketActions get video => const MpCacheBucketActions._('video');

  /// Writes [value] to the selected cache [bucket].
  MpAction set(
    String key,
    Object? value, {
    String bucket = 'data',
    String? requestId,
    Duration? ttl,
    String priority = 'normal',
  }) => MpCacheBucketActions._(
    _cacheBucket(bucket),
  ).set(key, value, requestId: requestId, ttl: ttl, priority: priority);

  /// Reads [key] from the selected cache [bucket].
  MpAction get(
    String key, {
    String bucket = 'data',
    String? targetState,
    bool skipMissing = false,
    String? requestId,
  }) => MpCacheBucketActions._(_cacheBucket(bucket)).get(
    key,
    targetState: targetState,
    skipMissing: skipMissing,
    requestId: requestId,
  );

  /// Checks whether [key] exists in the selected cache [bucket].
  MpAction has(
    String key, {
    String bucket = 'data',
    String? targetState,
    String? requestId,
  }) => MpCacheBucketActions._(
    _cacheBucket(bucket),
  ).has(key, targetState: targetState, requestId: requestId);

  /// Removes [key] from the selected cache [bucket].
  MpAction remove(String key, {String bucket = 'data', String? requestId}) =>
      MpCacheBucketActions._(
        _cacheBucket(bucket),
      ).remove(key, requestId: requestId);

  /// Clears one selected cache [bucket], or all allowed buckets when omitted.
  MpAction clear({String? bucket, String? requestId}) {
    if (bucket == null) {
      return MpAction(
        'cache.clear',
        props: <String, Object?>{
          if (requestId != null)
            'requestId': requiredAuthoringString(requestId, 'requestId'),
        },
      );
    }
    return MpCacheBucketActions._(
      _cacheBucket(bucket),
    ).clear(requestId: requestId);
  }

  /// Reads app-scoped cache usage and accepted limits into state.
  MpAction info({required String targetState, String? requestId}) => MpAction(
    'cache.info',
    props: <String, Object?>{
      'targetState': requiredStateKey(targetState, 'targetState'),
      if (requestId != null)
        'requestId': requiredAuthoringString(requestId, 'requestId'),
    },
  );
}

/// Mini-program cache action builders for a fixed bucket.
final class MpCacheBucketActions {
  const MpCacheBucketActions._(this._bucket);

  final String _bucket;

  /// Writes [value] to [key] in this bucket.
  MpAction set(
    String key,
    Object? value, {
    String? requestId,
    Duration? ttl,
    String priority = 'normal',
  }) => MpAction(
    'cache.set',
    props: <String, Object?>{
      if (requestId != null)
        'requestId': requiredAuthoringString(requestId, 'requestId'),
      'key': _requiredCacheKey(key, 'key'),
      'bucket': _bucket,
      'value': value,
      if (ttl != null) 'ttlMs': positiveDurationMs(ttl, 'ttl'),
      'priority': _cachePriority(priority),
    },
  );

  /// Reads [key] and optionally writes the result to [targetState].
  MpAction get(
    String key, {
    String? targetState,
    bool skipMissing = false,
    String? requestId,
  }) => MpAction(
    'cache.get',
    props: <String, Object?>{
      if (requestId != null)
        'requestId': requiredAuthoringString(requestId, 'requestId'),
      'key': _requiredCacheKey(key, 'key'),
      'bucket': _bucket,
      if (targetState != null)
        'targetState': requiredStateKey(targetState, 'targetState'),
      if (skipMissing) 'skipMissing': true,
    },
  );

  /// Checks whether [key] exists and optionally writes the result to state.
  MpAction has(String key, {String? targetState, String? requestId}) =>
      MpAction(
        'cache.has',
        props: <String, Object?>{
          if (requestId != null)
            'requestId': requiredAuthoringString(requestId, 'requestId'),
          'key': _requiredCacheKey(key, 'key'),
          'bucket': _bucket,
          if (targetState != null)
            'targetState': requiredStateKey(targetState, 'targetState'),
        },
      );

  /// Removes [key] from this bucket.
  MpAction remove(String key, {String? requestId}) => MpAction(
    'cache.remove',
    props: <String, Object?>{
      if (requestId != null)
        'requestId': requiredAuthoringString(requestId, 'requestId'),
      'key': _requiredCacheKey(key, 'key'),
      'bucket': _bucket,
    },
  );

  /// Clears this bucket.
  MpAction clear({String? requestId}) => MpAction(
    'cache.clear',
    props: <String, Object?>{
      if (requestId != null)
        'requestId': requiredAuthoringString(requestId, 'requestId'),
      'bucket': _bucket,
    },
  );
}

String _requiredCacheKey(String value, String name) {
  final normalized = stableAuthoringString(value, name);
  if (_unsafeCacheKeyPattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      name,
      'Mp cache keys cannot contain path traversal, separators, or file path markers.',
    );
  }
  return normalized;
}

String _cacheBucket(String value) {
  final normalized = stableAuthoringString(value, 'bucket');
  if (!_allowedCacheBuckets.contains(normalized)) {
    throw ArgumentError.value(
      value,
      'bucket',
      'Mp cache bucket must be memory, data, image, state, or video.',
    );
  }
  return normalized;
}

String _cachePriority(String value) {
  final normalized = stableAuthoringString(value, 'priority');
  if (!_allowedCachePriorities.contains(normalized)) {
    throw ArgumentError.value(
      value,
      'priority',
      'Mp cache priority must be low, normal, or high.',
    );
  }
  return normalized;
}
