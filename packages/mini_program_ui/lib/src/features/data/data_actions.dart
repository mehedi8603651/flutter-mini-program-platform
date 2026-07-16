import '../../core/authoring_validation.dart';
import '../../core/binding_validation.dart';
import '../../core/mp_action.dart';
import '../../core/value_normalization.dart';

final RegExp _dataResourceIdPattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
final RegExp _dataFieldPathPattern = RegExp(
  r'^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$',
);
final RegExp _jsonAssetPathPattern = RegExp(
  r'^[A-Za-z0-9_-]+(?:/[A-Za-z0-9_.-]+)*\.json$',
);

final class MpDataActions {
  /// Creates artifact-local data helpers.
  const MpDataActions();

  /// Loads and indexes a JSON resource from the immutable artifact assets.
  MpAction loadJsonAsset({
    required String id,
    required String asset,
    Duration ttl = const Duration(days: 30),
    bool forceRefresh = false,
    String? statusState,
    String? errorState,
    String? requestId,
  }) {
    final ttlMs = ttl.inMilliseconds;
    if (ttlMs <= 0 || ttlMs > const Duration(days: 3650).inMilliseconds) {
      throw ArgumentError.value(
        ttl,
        'ttl',
        'Duration must be between 1 millisecond and 3650 days.',
      );
    }
    return MpAction(
      'data.loadJsonAsset',
      props: <String, Object?>{
        'id': _dataResourceId(id, 'id'),
        'asset': _jsonAssetPath(asset),
        'ttlMs': ttlMs,
        'forceRefresh': forceRefresh,
        if (statusState != null)
          'statusState': requiredStateKey(statusState, 'statusState'),
        if (errorState != null)
          'errorState': requiredStateKey(errorState, 'errorState'),
        if (requestId != null)
          'requestId': stableAuthoringString(requestId, 'requestId'),
      },
    );
  }

  /// Searches an already loaded artifact-local JSON resource.
  MpAction search({
    required String resourceId,
    required String query,
    required List<String> fields,
    String? itemsPath,
    int minQueryLength = 2,
    int limit = 20,
    required String targetState,
    String? statusState,
    String? errorState,
  }) {
    if (fields.isEmpty || fields.length > 8) {
      throw ArgumentError.value(
        fields,
        'fields',
        'Data search requires from 1 to 8 fields.',
      );
    }
    final normalizedFields = fields
        .map((field) => _dataFieldPath(field, 'fields'))
        .toList(growable: false);
    if (normalizedFields.toSet().length != normalizedFields.length) {
      throw ArgumentError.value(fields, 'fields', 'Fields must be unique.');
    }
    final normalizedQuery = query;
    if (!isFullBinding(normalizedQuery) && normalizedQuery.length > 256) {
      throw ArgumentError.value(
        query,
        'query',
        'Static query text cannot exceed 256 characters.',
      );
    }
    return MpAction(
      'data.search',
      props: <String, Object?>{
        'resourceId': _dataResourceId(resourceId, 'resourceId'),
        'query': normalizedQuery,
        'fields': normalizedFields,
        if (itemsPath != null)
          'itemsPath': _dataFieldPath(itemsPath, 'itemsPath'),
        'minQueryLength': boundedInt(
          minQueryLength,
          'minQueryLength',
          minimum: 0,
          maximum: 256,
        ),
        'limit': boundedInt(limit, 'limit', minimum: 1, maximum: 100),
        'targetState': requiredStateKey(targetState, 'targetState'),
        if (statusState != null)
          'statusState': requiredStateKey(statusState, 'statusState'),
        if (errorState != null)
          'errorState': requiredStateKey(errorState, 'errorState'),
      },
    );
  }
}

String _dataResourceId(String value, String name) {
  final normalized = stableAuthoringString(value, name);
  if (!_dataResourceIdPattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      name,
      'Resource IDs must be lowercase identifiers up to 64 characters.',
    );
  }
  return normalized;
}

String _jsonAssetPath(String value) {
  final normalized = stableAuthoringString(value, 'asset');
  if (normalized.length > 256 ||
      !_jsonAssetPathPattern.hasMatch(normalized) ||
      normalized.contains('..')) {
    throw ArgumentError.value(
      value,
      'asset',
      'Asset must be a relative JSON path under the artifact assets directory.',
    );
  }
  return normalized;
}

String _dataFieldPath(String value, String name) {
  final normalized = stableAuthoringString(value, name);
  if (!_dataFieldPathPattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      name,
      'Value must be a dotted field path.',
    );
  }
  return normalized;
}
