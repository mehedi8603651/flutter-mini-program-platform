import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';

final RegExp _mediaAssetPathPattern = RegExp(
  r'^[A-Za-z0-9_-]+(?:/[A-Za-z0-9_.-]+)*\.(?:mp3|m4a|aac|mp4|m3u8)$',
  caseSensitive: false,
);

Future<void> validateMiniProgramBuildMediaAssets({
  required String screensDirectoryPath,
  required String assetsDirectoryPath,
}) async {
  final references = <String, String>{};
  await for (final entity in Directory(
    screensDirectoryPath,
  ).list(followLinks: false)) {
    if (entity is! File || p.extension(entity.path).toLowerCase() != '.json') {
      continue;
    }
    late final Object? decoded;
    try {
      decoded = jsonDecode(await entity.readAsString());
    } catch (error) {
      throw MiniProgramBuildException(
        'Built screen JSON could not be parsed: ${entity.path}\n$error',
      );
    }
    _collectMediaAssetReferences(
      decoded,
      sourcePath: entity.path,
      references: references,
    );
  }

  final assetsRoot = p.normalize(p.absolute(assetsDirectoryPath));
  for (final reference in references.entries) {
    final asset = reference.key;
    if (asset.length > 256 ||
        !_mediaAssetPathPattern.hasMatch(asset) ||
        asset.split('/').contains('..')) {
      throw MiniProgramBuildException(
        'Unsafe media asset path "$asset" referenced by ${reference.value}.',
      );
    }
    final assetPath = p.normalize(
      p.absolute(p.joinAll(<String>[assetsRoot, ...asset.split('/')])),
    );
    if (!p.isWithin(assetsRoot, assetPath)) {
      throw MiniProgramBuildException(
        'Media asset escapes the assets directory: $asset',
      );
    }
    if (!await File(assetPath).exists()) {
      throw MiniProgramBuildException(
        'Referenced media asset was not found: $asset '
        '(from ${reference.value}).',
      );
    }
  }
}

void _collectMediaAssetReferences(
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
          throw MiniProgramBuildException(
            '$type requires a static media asset path in '
            '$sourcePath at $jsonPath.',
          );
        }
        references.putIfAbsent(asset, () => '$sourcePath:$jsonPath');
      }
    }
    for (final entry in value.entries) {
      _collectMediaAssetReferences(
        entry.value,
        sourcePath: sourcePath,
        references: references,
        jsonPath: '$jsonPath.${entry.key}',
      );
    }
  } else if (value is List) {
    for (var index = 0; index < value.length; index += 1) {
      _collectMediaAssetReferences(
        value[index],
        sourcePath: sourcePath,
        references: references,
        jsonPath: '$jsonPath[$index]',
      );
    }
  }
}
