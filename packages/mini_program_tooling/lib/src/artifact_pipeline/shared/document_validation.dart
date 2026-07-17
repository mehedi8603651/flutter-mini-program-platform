import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:pub_semver/pub_semver.dart';

import '../models.dart';
import 'constants.dart';
import 'json_io.dart';

MiniProgramManifest parseArtifactManifest(
  Map<String, dynamic> json,
  String manifestPath,
) {
  try {
    return MiniProgramManifest.fromJson(json);
  } catch (error) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.manifestInvalid,
      message: 'Manifest could not be parsed: $manifestPath\n$error',
    );
  }
}

Future<MiniProgramPublisherBackendContract> readArtifactPublisherBackend(
  String contractPath, {
  required String expectedAppId,
}) async {
  final json = await readArtifactJsonMap(
    contractPath,
    code: MiniProgramArtifactErrorCodes.publisherBackendInvalid,
    label: 'Publisher API contract',
  );
  try {
    final contract = MiniProgramPublisherBackendContract.fromJson(json);
    if (contract.appId != expectedAppId) {
      throw FormatException(
        'Publisher API contract appId "${contract.appId}" does not match '
        'artifact appId "$expectedAppId".',
      );
    }
    return contract;
  } catch (error) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.publisherBackendInvalid,
      message: 'Publisher API contract is invalid: $contractPath\n$error',
    );
  }
}

Version parseArtifactVersion(String rawVersion, String sourcePath) {
  final value = rawVersion.trim();
  try {
    return Version.parse(value);
  } on FormatException {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.versionInvalid,
      message: 'Invalid semantic version "$value": $sourcePath',
    );
  }
}

void validateArtifactLayout(Map<String, dynamic> json, String sourcePath) {
  if (json['artifactLayoutVersion'] != artifactLayoutVersion) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.structureInvalid,
      message:
          'Expected artifactLayoutVersion '
          '$artifactLayoutVersion: $sourcePath',
    );
  }
}

void validateArtifactScreen(
  Map<String, dynamic> json, {
  required String expectedScreenId,
  required int expectedSchemaVersion,
  required String path,
}) {
  if (json['schemaVersion'] != expectedSchemaVersion ||
      json['screenId'] != expectedScreenId ||
      json['root'] is! Map) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.structureInvalid,
      message: 'Screen identity, schemaVersion, or root is invalid: $path',
    );
  }
}
