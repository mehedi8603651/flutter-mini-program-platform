import '../errors.dart';
import 'json_values.dart';

const Set<String> allowedPartnerHandoffCacheBuckets = <String>{
  'memory',
  'data',
  'image',
  'state',
  'video',
};

Map<String, Object?> normalizePartnerHandoffRequestedCache(Object? raw) {
  if (raw == null) {
    return const <String, Object?>{};
  }
  if (raw is! Map) {
    throw const MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff requestedCache must be an object.',
    );
  }
  final normalized = <String, Object?>{};
  for (final entry in raw.entries) {
    final bucket = entry.key;
    if (bucket is! String || bucket.trim().isEmpty) {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff requestedCache bucket names must be strings.',
      );
    }
    final bucketName = bucket.trim();
    validatePartnerHandoffRequestedCacheBucket(bucketName);
    if (entry.value is! Map) {
      throw MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff requestedCache.$bucketName must be an object.',
      );
    }
    normalized[bucketName] = normalizePartnerHandoffJsonObject(
      entry.value as Map,
      'requestedCache.$bucketName',
    );
  }
  return Map<String, Object?>.unmodifiable(normalized);
}

void validatePartnerHandoffRequestedCacheBucket(String bucket) {
  if (isSensitivePartnerHandoffPolicyKey(bucket)) {
    throw MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff requestedCache.$bucket is not allowed.',
    );
  }
  if (!allowedPartnerHandoffCacheBuckets.contains(bucket)) {
    throw MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff requestedCache.$bucket is not supported.',
    );
  }
}
