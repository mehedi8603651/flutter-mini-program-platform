import 'constants.dart';
import 'errors.dart';
import 'requested_policy/cache.dart';
import 'requested_policy/permissions.dart';
import 'requested_policy/publisher_api.dart';
import 'validation.dart';

class MiniProgramPartnerHandoff {
  MiniProgramPartnerHandoff({
    this.schemaVersion = currentSchemaVersion,
    required String appId,
    required String title,
    Uri? artifactBaseUri,
    Uri? apiBaseUri,
    required String generatedAtUtc,
    Map<String, Object?> requestedCache = const <String, Object?>{},
    Map<String, Object?> requestedPublisherApi = const <String, Object?>{},
    Map<String, Object?> requestedPermissions = const <String, Object?>{},
  }) : appId = appId.trim(),
       title = title.trim(),
       artifactBaseUri = normalizePartnerHandoffArtifactBaseUri(
         artifactBaseUri ?? apiBaseUri,
       ),
       generatedAtUtc = generatedAtUtc.trim(),
       requestedCache = normalizePartnerHandoffRequestedCache(requestedCache),
       requestedPublisherApi = normalizePartnerHandoffRequestedPublisherApi(
         requestedPublisherApi,
       ),
       requestedPermissions = normalizePartnerHandoffRequestedPermissions(
         requestedPermissions,
       ) {
    validatePartnerHandoffSchemaVersion(schemaVersion);
    validatePartnerHandoffSafeIdentifier(appId, 'appId');
    validatePartnerHandoffTitle(title);
    validatePartnerHandoffTimestamp(this.generatedAtUtc);
  }

  factory MiniProgramPartnerHandoff.fromJson(Object? decoded) {
    if (decoded is! Map) {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff file must contain a JSON object.',
      );
    }
    final type = readPartnerHandoffString(decoded, 'type');
    if (type != documentType) {
      throw MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff type must be "$documentType".',
      );
    }
    final schemaVersion = readPartnerHandoffInt(decoded, 'schemaVersion');
    final rawArtifactBaseUrl =
        readOptionalPartnerHandoffString(decoded, 'artifactBaseUrl') ??
        readOptionalPartnerHandoffString(decoded, 'apiBaseUrl');
    if (rawArtifactBaseUrl == null) {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff is missing "artifactBaseUrl".',
      );
    }
    final artifactBaseUri = Uri.tryParse(rawArtifactBaseUrl);
    if (artifactBaseUri == null) {
      throw const MiniProgramPartnerHandoffException(
        'MiniProgram partner handoff artifactBaseUrl is invalid.',
      );
    }
    return MiniProgramPartnerHandoff(
      schemaVersion: schemaVersion,
      appId: readPartnerHandoffString(decoded, 'appId'),
      title: readPartnerHandoffString(decoded, 'title'),
      artifactBaseUri: artifactBaseUri,
      generatedAtUtc: readPartnerHandoffString(decoded, 'generatedAtUtc'),
      requestedCache: normalizePartnerHandoffRequestedCache(
        decoded['requestedCache'],
      ),
      requestedPublisherApi: normalizePartnerHandoffRequestedPublisherApi(
        decoded['requestedPublisherApi'],
      ),
      requestedPermissions: normalizePartnerHandoffRequestedPermissions(
        decoded['requestedPermissions'],
      ),
    );
  }

  static const int legacySchemaVersion =
      legacyMiniProgramPartnerHandoffSchemaVersion;
  static const int currentSchemaVersion =
      currentMiniProgramPartnerHandoffSchemaVersion;
  static const String documentType = miniProgramPartnerHandoffDocumentType;

  final int schemaVersion;
  final String appId;
  final String title;
  final Uri artifactBaseUri;
  final String generatedAtUtc;
  final Map<String, Object?> requestedCache;
  final Map<String, Object?> requestedPublisherApi;
  final Map<String, Object?> requestedPermissions;

  Uri get apiBaseUri => artifactBaseUri;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'type': documentType,
    'appId': appId,
    'title': title,
    'artifactBaseUrl': artifactBaseUri.toString(),
    'generatedAtUtc': generatedAtUtc,
    if (requestedCache.isNotEmpty) 'requestedCache': requestedCache,
    if (requestedPublisherApi.isNotEmpty)
      'requestedPublisherApi': requestedPublisherApi,
    if (requestedPermissions.isNotEmpty)
      'requestedPermissions': requestedPermissions,
  };
}
