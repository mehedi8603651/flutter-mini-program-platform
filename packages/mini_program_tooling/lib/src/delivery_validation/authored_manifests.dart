import 'dart:io';

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as path;

import '../delivery_validation.dart';
import 'json_reader.dart';
import 'manifest_validation.dart';
import 'validation_context.dart';

Future<Map<String, MiniProgramManifest>> loadAuthoredManifests({
  required DeliveryValidationContext context,
  required Directory miniProgramsRoot,
}) async {
  final manifests = <String, MiniProgramManifest>{};
  final directories = await miniProgramsRoot
      .list()
      .where((entity) => entity is Directory)
      .cast<Directory>()
      .toList();
  directories.sort((a, b) => a.path.compareTo(b.path));

  for (final directory in directories) {
    final folderName = path.basename(directory.path);
    if (context.miniProgramId != null && folderName != context.miniProgramId) {
      continue;
    }

    final manifestFile = File(path.join(directory.path, 'manifest.json'));
    if (!await manifestFile.exists()) {
      continue;
    }

    final manifestJson = await readDeliveryJsonMap(
      manifestFile,
      context: context,
    );
    if (manifestJson == null) {
      continue;
    }

    final manifest = parseDeliveryManifest(
      manifestJson,
      manifestFile.path,
      context: context,
    );
    if (manifest == null) {
      continue;
    }

    manifests[manifest.id] = manifest;

    if (manifest.id != folderName) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'manifest_directory_mismatch',
          path: context.relativePath(manifestFile.path),
          message:
              'Manifest id "${manifest.id}" must match mini-program folder "$folderName".',
        ),
      );
    }

    validateDeliveryManifestSemantics(
      manifest: manifest,
      manifestPath: manifestFile.path,
      context: context,
    );

    final publishedManifestFile = File(
      path.join(
        context.backendApiRootPath,
        'artifacts',
        manifest.id,
        manifest.version,
        'manifest.json',
      ),
    );
    if (!await publishedManifestFile.exists()) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.warning,
          code: 'authored_manifest_not_published',
          path: context.relativePath(manifestFile.path),
          message:
              'No published backend manifest exists yet for version "${manifest.version}".',
        ),
      );
    }
  }

  return manifests;
}

Future<MiniProgramManifest?> loadExternalAuthoredManifest({
  required DeliveryValidationContext context,
  required String miniProgramRootPath,
}) async {
  final normalizedRootPath = path.normalize(path.absolute(miniProgramRootPath));
  final rootDirectory = Directory(normalizedRootPath);
  if (!await rootDirectory.exists()) {
    context.messages.add(
      DeliveryValidationMessage(
        severity: ValidationSeverity.error,
        code: 'external_mini_program_root_missing',
        path: normalizedRootPath,
        message: 'Standalone mini-program root was not found.',
      ),
    );
    return null;
  }

  final manifestFile = File(path.join(normalizedRootPath, 'manifest.json'));
  if (!await manifestFile.exists()) {
    context.messages.add(
      DeliveryValidationMessage(
        severity: ValidationSeverity.error,
        code: 'external_manifest_missing',
        path: normalizedRootPath,
        message: 'Standalone mini-program root does not contain manifest.json.',
      ),
    );
    return null;
  }

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

  if (context.miniProgramId != null && manifest.id != context.miniProgramId) {
    return null;
  }

  validateDeliveryManifestSemantics(
    manifest: manifest,
    manifestPath: manifestFile.path,
    context: context,
  );

  return manifest;
}
