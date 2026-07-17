import 'dart:convert';
import 'dart:io';

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as path;

import '../../mini_program_builder.dart';
import 'models.dart';

Future<MiniProgramPreviewBundle> loadMiniProgramPreviewBundle(
  MiniProgramBuildResult buildResult,
) async {
  final manifestPath = path.join(
    buildResult.miniProgramRootPath,
    'manifest.json',
  );
  final manifestFile = File(manifestPath);
  if (!await manifestFile.exists()) {
    throw MiniProgramPreviewException(
      'Preview manifest was not found: $manifestPath',
    );
  }

  final manifestJson = await _readJsonMap(
    manifestFile,
    label: 'preview manifest',
  );
  final title = _resolveTitle(
    manifestJson: manifestJson,
    miniProgramId: buildResult.miniProgramId,
  );

  final screensDirectory = Directory(buildResult.screensDirectoryPath);
  if (!await screensDirectory.exists()) {
    throw MiniProgramPreviewException(
      'Preview screens directory was not found: '
      '${buildResult.screensDirectoryPath}',
    );
  }

  final screenJsonById = <String, Map<String, dynamic>>{};
  final files = await screensDirectory
      .list(followLinks: false)
      .where((entity) => entity is File)
      .cast<File>()
      .where((file) => path.extension(file.path).toLowerCase() == '.json')
      .toList();
  files.sort((left, right) => left.path.compareTo(right.path));

  for (final file in files) {
    final screenId = path.basenameWithoutExtension(file.path);
    screenJsonById[screenId] = await _readJsonMap(
      file,
      label: 'preview screen',
    );
  }

  if (screenJsonById.isEmpty) {
    throw MiniProgramPreviewException(
      'Preview build did not produce any screen JSON files under '
      '${buildResult.screensDirectoryPath}.',
    );
  }

  final assetRootPath = path.join(buildResult.miniProgramRootPath, 'assets');
  final hasAssetRoot = await Directory(assetRootPath).exists();
  final publisherBackendPath = path.join(
    buildResult.miniProgramRootPath,
    'publisher_backend.json',
  );
  Map<String, dynamic>? publisherBackendJson;
  if (await File(publisherBackendPath).exists()) {
    final rawContract = await _readJsonMap(
      File(publisherBackendPath),
      label: 'Publisher API contract',
    );
    try {
      final contract = MiniProgramPublisherBackendContract.fromJson(
        rawContract,
        allowLocalHttp: true,
      );
      if (contract.appId != buildResult.miniProgramId) {
        throw FormatException(
          'Contract appId "${contract.appId}" does not match '
          '"${buildResult.miniProgramId}".',
        );
      }
      publisherBackendJson = Map<String, dynamic>.from(contract.toJson());
    } catch (error) {
      throw MiniProgramPreviewException(
        'Publisher API contract is invalid: $publisherBackendPath\n$error',
      );
    }
  }

  return MiniProgramPreviewBundle(
    miniProgramId: buildResult.miniProgramId,
    title: title,
    manifestJson: manifestJson,
    screenJsonById: screenJsonById,
    assetRootPath: hasAssetRoot ? assetRootPath : null,
    publisherBackendJson: publisherBackendJson,
  );
}

Future<Map<String, dynamic>> _readJsonMap(
  File file, {
  required String label,
}) async {
  try {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw MiniProgramPreviewException(
        '$label is not a JSON object: ${file.path}',
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  } on FormatException catch (error) {
    throw MiniProgramPreviewException(
      'Failed to parse $label JSON: ${file.path}\n${error.message}',
    );
  } on FileSystemException catch (error) {
    throw MiniProgramPreviewException(
      'Failed to read $label file: ${file.path}\n$error',
    );
  }
}

String _resolveTitle({
  required Map<String, dynamic> manifestJson,
  required String miniProgramId,
}) {
  final rawTitle = '${manifestJson['title'] ?? ''}'.trim();
  if (rawTitle.isNotEmpty) {
    return rawTitle;
  }

  final words = miniProgramId
      .split('_')
      .where((segment) => segment.isNotEmpty)
      .map(
        (segment) =>
            '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
      );
  return words.isEmpty ? miniProgramId : words.join(' ');
}
