import 'dart:io';

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as path;

import '../delivery_validation.dart';
import 'json_reader.dart';
import 'manifest_validation.dart';
import 'validation_context.dart';

Future<Map<String, Set<String>>> validatePublishedManifests({
  required DeliveryValidationContext context,
}) async {
  final publishedVersionsByMiniProgram = <String, Set<String>>{};
  final artifactsRoot = Directory(
    path.join(context.backendApiRootPath, 'artifacts'),
  );
  if (!await artifactsRoot.exists()) {
    return publishedVersionsByMiniProgram;
  }

  final miniProgramDirectories = await artifactsRoot
      .list()
      .where((entity) => entity is Directory)
      .cast<Directory>()
      .toList();
  miniProgramDirectories.sort((a, b) => a.path.compareTo(b.path));

  for (final miniProgramDirectory in miniProgramDirectories) {
    final currentMiniProgramId = path.basename(miniProgramDirectory.path);
    if (context.miniProgramId != null &&
        currentMiniProgramId != context.miniProgramId) {
      continue;
    }

    final publishedVersions = <String>{};
    publishedVersionsByMiniProgram[currentMiniProgramId] = publishedVersions;

    final latestFile = File(
      path.join(miniProgramDirectory.path, 'latest.json'),
    );
    if (await latestFile.exists()) {
      final latestManifest = await _validatePublishedManifestFile(
        manifestFile: latestFile,
        expectedMiniProgramId: currentMiniProgramId,
        expectedVersion: null,
        context: context,
      );
      if (latestManifest != null) {
        publishedVersions.add(latestManifest.version);
      }
    } else {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.warning,
          code: 'latest_manifest_missing',
          path: context.relativePath(miniProgramDirectory.path),
          message: 'Published manifest directory does not contain latest.json.',
        ),
      );
    }

    final versionDirectories = await miniProgramDirectory
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .where((directory) => !path.basename(directory.path).startsWith('.'))
        .toList();
    versionDirectories.sort((a, b) => a.path.compareTo(b.path));

    for (final versionDirectory in versionDirectories) {
      final expectedVersion = path.basename(versionDirectory.path);
      final manifestFile = File(
        path.join(versionDirectory.path, 'manifest.json'),
      );
      if (!await manifestFile.exists()) {
        context.messages.add(
          DeliveryValidationMessage(
            severity: ValidationSeverity.error,
            code: 'version_manifest_missing',
            path: context.relativePath(versionDirectory.path),
            message:
                'Artifact version directory does not contain manifest.json.',
          ),
        );
        continue;
      }
      final manifest = await _validatePublishedManifestFile(
        manifestFile: manifestFile,
        expectedMiniProgramId: currentMiniProgramId,
        expectedVersion: expectedVersion,
        context: context,
      );
      if (manifest != null) {
        publishedVersions.add(manifest.version);
      }
    }
  }

  return publishedVersionsByMiniProgram;
}

Future<MiniProgramManifest?> _validatePublishedManifestFile({
  required File manifestFile,
  required String expectedMiniProgramId,
  required String? expectedVersion,
  required DeliveryValidationContext context,
}) async {
  final manifestJson = await readDeliveryJsonMap(
    manifestFile,
    context: context,
  );
  if (manifestJson == null) {
    return null;
  }

  final manifest = parseDeliveryManifest(
    manifestJson,
    manifestFile.path,
    context: context,
  );
  if (manifest == null) {
    return null;
  }

  validateDeliveryManifestSemantics(
    context: context,
    manifest: manifest,
    manifestPath: manifestFile.path,
  );

  if (manifest.id != expectedMiniProgramId) {
    context.messages.add(
      DeliveryValidationMessage(
        severity: ValidationSeverity.error,
        code: 'published_manifest_id_mismatch',
        path: context.relativePath(manifestFile.path),
        message:
            'Published manifest id "${manifest.id}" must match backend directory "$expectedMiniProgramId".',
      ),
    );
  }

  if (expectedVersion != null && manifest.version != expectedVersion) {
    context.messages.add(
      DeliveryValidationMessage(
        severity: ValidationSeverity.error,
        code: 'published_manifest_version_mismatch',
        path: context.relativePath(manifestFile.path),
        message:
            'Published manifest version "${manifest.version}" must match directory "$expectedVersion".',
      ),
    );
  }

  final entryScreenFile = File(
    path.join(
      context.backendApiRootPath,
      'artifacts',
      manifest.id,
      manifest.version,
      'screens',
      '${manifest.entry}.json',
    ),
  );
  if (!await entryScreenFile.exists()) {
    context.messages.add(
      DeliveryValidationMessage(
        severity: ValidationSeverity.error,
        code: 'entry_screen_missing',
        path: context.relativePath(manifestFile.path),
        message:
            'Entry screen "${manifest.entry}.json" was not found under backend/api/artifacts/${manifest.id}/${manifest.version}/screens/.',
      ),
    );
  }

  return manifest;
}
