import 'handoff.dart';

class MiniProgramPartnerPackageRequest {
  const MiniProgramPartnerPackageRequest({
    required this.appId,
    required this.title,
    this.schemaVersion = MiniProgramPartnerHandoff.currentSchemaVersion,
    this.artifactBaseUri,
    this.apiBaseUri,
    this.outputPath,
    this.generatedAtUtc,
    this.requestedCache = const <String, Object?>{},
    this.requestedPublisherApi = const <String, Object?>{},
    this.requestedPermissions = const <String, Object?>{},
  });

  final String appId;
  final String title;
  final int schemaVersion;
  final Uri? artifactBaseUri;
  final Uri? apiBaseUri;
  final String? outputPath;
  final DateTime? generatedAtUtc;
  final Map<String, Object?> requestedCache;
  final Map<String, Object?> requestedPublisherApi;
  final Map<String, Object?> requestedPermissions;
}

class MiniProgramPartnerPackageResult {
  const MiniProgramPartnerPackageResult({
    required this.filePath,
    required this.handoff,
  });

  final String filePath;
  final MiniProgramPartnerHandoff handoff;
}
