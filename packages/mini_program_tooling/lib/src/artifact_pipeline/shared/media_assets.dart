import 'dart:io';

import 'package:path/path.dart' as path;

import '../models.dart';
import 'json_io.dart';
import 'paths.dart';

final RegExp _mediaAssetPathPattern = RegExp(
  r'^[A-Za-z0-9_-]+(?:/[A-Za-z0-9_.-]+)*\.(?:mp3|m4a|aac|mp4|m3u8)$',
  caseSensitive: false,
);

Future<void> validateReferencedArtifactMediaAssets({
  required List<File> screenFiles,
  required String assetsRoot,
}) async {
  final references = <String, String>{};
  for (final screenFile in screenFiles) {
    final screen = await readArtifactJsonMap(
      screenFile.path,
      code: MiniProgramArtifactErrorCodes.structureInvalid,
      label: 'Screen media reference source',
    );
    _collectArtifactMediaReferences(
      screen,
      sourcePath: screenFile.path,
      references: references,
    );
  }

  final normalizedAssetsRoot = path.normalize(path.absolute(assetsRoot));
  for (final reference in references.entries) {
    final asset = reference.key;
    if (asset.length > 256 ||
        !_mediaAssetPathPattern.hasMatch(asset) ||
        asset.split('/').contains('..')) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.pathUnsafe,
        message:
            'Unsafe media asset path "$asset" referenced by ${reference.value}.',
      );
    }
    final assetPath = path.normalize(
      path.absolute(
        path.joinAll(<String>[normalizedAssetsRoot, ...asset.split('/')]),
      ),
    );
    assertArtifactPathContained(assetPath, normalizedAssetsRoot);
    if (!await File(assetPath).exists()) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.fileMissing,
        message:
            'Referenced media asset was not found: $asset '
            '(from ${reference.value}).',
      );
    }
  }
}

void _collectArtifactMediaReferences(
  Object? value, {
  required String sourcePath,
  required Map<String, String> references,
  String jsonPath = r'$',
}) {
  if (value is Map) {
    final type = value['type'];
    if (type == 'videoView' ||
        type == 'audio.play' ||
        type == 'audio.preload') {
      final props = value['props'];
      final source = props is Map ? props['source'] : null;
      if (source is Map && source['kind'] == 'asset') {
        final asset = source['asset'];
        if (asset is! String || asset.trim().isEmpty) {
          throw MiniProgramArtifactException(
            code: MiniProgramArtifactErrorCodes.structureInvalid,
            message:
                '$type requires a static media asset path in '
                '$sourcePath at $jsonPath.',
          );
        }
        references.putIfAbsent(asset, () => '$sourcePath:$jsonPath');
      }
    }
    for (final entry in value.entries) {
      _collectArtifactMediaReferences(
        entry.value,
        sourcePath: sourcePath,
        references: references,
        jsonPath: '$jsonPath.${entry.key}',
      );
    }
  } else if (value is List) {
    for (var index = 0; index < value.length; index += 1) {
      _collectArtifactMediaReferences(
        value[index],
        sourcePath: sourcePath,
        references: references,
        jsonPath: '$jsonPath[$index]',
      );
    }
  }
}
