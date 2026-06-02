part of '../../publisher_backend_starter.dart';

String _defaultAwsPublisherBackendStackName(
  String appId,
  String environmentName,
) {
  final safeAppId = _safeAwsSegment(appId);
  final safeEnv = _safeAwsSegment(environmentName);
  return 'mini-program-publisher-backend-$safeAppId-$safeEnv';
}

String _appPartitionKey(String appId) => 'APP#$appId';

String _redemptionsPartitionKey(String appId) => 'APP#$appId#REDEMPTIONS';

String _safeAwsSegment(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'default' : normalized;
}

String _safeNodePackageSegment(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
  return normalized.isEmpty ? 'mini-program' : normalized;
}

String? _readManifestIdSync(String miniProgramRootPath) {
  try {
    final file = File(p.join(miniProgramRootPath, 'manifest.json'));
    if (!file.existsSync()) {
      return null;
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map) {
      final id = decoded['id']?.toString().trim();
      return id == null || id.isEmpty ? null : id;
    }
  } catch (_) {
    return null;
  }
  return null;
}

String _titleFromAppId(String appId) => appId
    .split(RegExp(r'[_-]+'))
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

String _prettyJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);
