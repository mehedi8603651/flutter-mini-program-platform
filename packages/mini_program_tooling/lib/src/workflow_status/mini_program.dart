import 'dart:io';

import 'package:path/path.dart' as p;

import 'backend_usage.dart';
import 'metadata.dart';
import 'publisher_backend.dart';

Future<Map<String, Object?>> inspectWorkflowMiniProgram(
  String workspacePath,
  Map<String, Object?> workspace,
) async {
  if (workspace['type'] != 'mini_program') {
    return <String, Object?>{'detected': false};
  }

  final manifestPath = p.join(workspacePath, 'manifest.json');
  Map<String, dynamic>? manifest;
  Object? manifestError;
  try {
    manifest = await readWorkflowJsonObject(File(manifestPath));
  } catch (error) {
    manifestError = error;
  }
  final appId = manifest?['id']?.toString();
  final entry = manifest?['entry']?.toString();
  final version = manifest?['version']?.toString();
  final screenFormat = _resolveScreenFormat(manifest);
  final screenSchemaVersion = _resolveScreenSchemaVersion(manifest);
  final sourceRootPath = p.join(workspacePath, 'mp');
  final outputRootPath = _resolveBuildOutputPath(
    workspacePath: workspacePath,
    screenFormat: screenFormat,
  );
  final screensDirectory = Directory(p.join(outputRootPath, 'screens'));
  final buildScreens = await screensDirectory.exists()
      ? await screensDirectory
            .list()
            .where((entity) => entity is File && entity.path.endsWith('.json'))
            .length
      : 0;
  final entryScreenPath = entry == null
      ? null
      : p.join(screensDirectory.path, '$entry.json');
  final entryScreenExists = entryScreenPath == null
      ? false
      : await File(entryScreenPath).exists();
  final partnerPackages = await findWorkflowPartnerPackages(workspacePath);
  final backendUsage = await detectWorkflowBackendUsage(workspacePath);
  final publisherBackendStarter = await inspectWorkflowPublisherBackendStarter(
    workspacePath,
  );

  return <String, Object?>{
    'detected': true,
    'manifestPath': manifestPath,
    'manifestExists': manifest != null,
    if (manifestError != null) 'manifestError': manifestError.toString(),
    'appId': appId,
    'version': version,
    'entry': entry,
    'screenFormat': screenFormat,
    'screenSchemaVersion': screenSchemaVersion,
    'sourceRootPath': sourceRootPath,
    'sourceRootExists': await Directory(sourceRootPath).exists(),
    'outputRootPath': outputRootPath,
    'build': <String, Object?>{
      'screensDirectory': screensDirectory.path,
      'exists': buildScreens > 0,
      'screenCount': buildScreens,
      'entryScreenPath': entryScreenPath,
      'entryScreenExists': entryScreenExists,
    },
    'validation': <String, Object?>{
      'status': 'not_run',
      'reason': 'Validation has not been checked yet.',
    },
    'partnerPackages': partnerPackages,
    'backendUsage': backendUsage,
    'publisherBackendStarter': publisherBackendStarter,
  };
}

String _resolveScreenFormat(Map<String, dynamic>? manifest) {
  final rawScreenFormat = manifest?['screenFormat'];
  if (rawScreenFormat == null) {
    return 'mp';
  }
  final screenFormat = rawScreenFormat.toString().trim();
  return screenFormat.isEmpty ? 'mp' : screenFormat;
}

int? _resolveScreenSchemaVersion(Map<String, dynamic>? manifest) {
  final rawVersion = manifest?['screenSchemaVersion'];
  if (rawVersion is int) {
    return rawVersion;
  }
  if (rawVersion is num) {
    return rawVersion.toInt();
  }
  if (rawVersion is String) {
    return int.tryParse(rawVersion.trim());
  }
  return null;
}

String _resolveBuildOutputPath({
  required String workspacePath,
  required String screenFormat,
}) {
  if (screenFormat != 'mp') {
    return p.join(workspacePath, screenFormat, '.build');
  }
  return p.join(workspacePath, 'mp', '.build');
}
