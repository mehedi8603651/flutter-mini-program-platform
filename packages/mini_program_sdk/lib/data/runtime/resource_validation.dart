part of '../mini_program_data_resource.dart';

void _ensureDataCacheEnabled(MiniProgramCachePolicy policy) {
  if (!policy.enabled ||
      !policy.allowsMiniProgramBucket(MiniProgramCacheBucket.data)) {
    throw const MiniProgramDataException(
      code: 'cache_bucket_disabled',
      message: 'The data cache bucket is disabled by host policy.',
    );
  }
}

void _validateResourceId(String value) {
  if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(value)) {
    throw const MiniProgramDataException(
      code: MiniProgramErrorCodes.dataAssetUnavailable,
      message: 'Data resource ID is invalid.',
    );
  }
}

void _validateJsonAssetPath(String value) {
  final valid =
      value.length <= miniProgramJsonAssetPathMaxLength &&
      RegExp(r'^[A-Za-z0-9_-]+(?:/[A-Za-z0-9_.-]+)*\.json$').hasMatch(value) &&
      !value.contains('..');
  if (!valid) {
    throw const MiniProgramDataException(
      code: MiniProgramErrorCodes.dataAssetUnavailable,
      message: 'JSON asset path is invalid or unsafe.',
    );
  }
}

void _validateJsonValue(
  Object? value,
  int bytes,
  MiniProgramCachePolicy policy,
) {
  final maxBytes = _effectiveMaxBytes(policy);
  if (bytes > maxBytes) {
    throw MiniProgramDataException(
      code: MiniProgramErrorCodes.dataResourceTooLarge,
      message: 'JSON data resource exceeds the accepted size limit.',
      details: <String, dynamic>{'actualBytes': bytes, 'maxBytes': maxBytes},
    );
  }
  if (value is! Map && value is! List) {
    throw const MiniProgramDataException(
      code: MiniProgramErrorCodes.dataInvalidJson,
      message: 'JSON data resource root must be an object or list.',
    );
  }
  var members = 0;
  void visit(Object? current, int depth) {
    if (depth > miniProgramJsonAssetMaxDepth) {
      throw const MiniProgramDataException(
        code: MiniProgramErrorCodes.dataResourceTooLarge,
        message: 'JSON data resource exceeds the maximum nesting depth.',
      );
    }
    if (current is Map) {
      members += current.length;
      for (final entry in current.entries) {
        visit(entry.value, depth + 1);
      }
    } else if (current is List) {
      members += current.length;
      for (final item in current) {
        visit(item, depth + 1);
      }
    }
    if (members > miniProgramJsonAssetMaxMembers) {
      throw const MiniProgramDataException(
        code: MiniProgramErrorCodes.dataResourceTooLarge,
        message: 'JSON data resource contains too many values.',
      );
    }
  }

  visit(value, 1);
}

int _effectiveMaxBytes(MiniProgramCachePolicy policy) => math.min(
  miniProgramJsonAssetMaxBytes,
  math.min(policy.maxDataBytes, policy.maxBytes),
);
