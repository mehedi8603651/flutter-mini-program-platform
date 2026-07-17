import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../models.dart';
import 'constants.dart';
import 'json_io.dart';
import 'paths.dart';

Future<void> validateReferencedArtifactJsonAssets({
  required List<File> screenFiles,
  required String assetsRoot,
}) async {
  final references = <String, String>{};
  for (final screenFile in screenFiles) {
    final screen = await readArtifactJsonMap(
      screenFile.path,
      code: MiniProgramArtifactErrorCodes.structureInvalid,
      label: 'Screen data reference source',
    );
    void visit(Object? value, String jsonPath) {
      if (value is Map) {
        final map = value.map((key, item) => MapEntry(key.toString(), item));
        if (map['type'] == 'data.loadJsonAsset') {
          final props = map['props'];
          final asset = props is Map ? props['asset'] : null;
          if (asset is! String || asset.trim().isEmpty) {
            throw MiniProgramArtifactException(
              code: MiniProgramArtifactErrorCodes.structureInvalid,
              message:
                  'data.loadJsonAsset requires a static asset path in '
                  '${screenFile.path} at $jsonPath.',
            );
          }
          references.putIfAbsent(asset, () => '${screenFile.path}:$jsonPath');
        }
        for (final entry in map.entries) {
          visit(entry.value, '$jsonPath.${entry.key}');
        }
      } else if (value is List) {
        for (var index = 0; index < value.length; index += 1) {
          visit(value[index], '$jsonPath[$index]');
        }
      }
    }

    visit(screen, r'$');
  }

  final normalizedAssetsRoot = path.normalize(path.absolute(assetsRoot));
  for (final entry in references.entries) {
    final asset = entry.key;
    final validPath =
        asset.length <= jsonDataAssetPathMaxLength &&
        RegExp(
          r'^[A-Za-z0-9_-]+(?:/[A-Za-z0-9_.-]+)*\.json$',
        ).hasMatch(asset) &&
        !asset.contains('..');
    if (!validPath) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.pathUnsafe,
        message:
            'Unsafe JSON data asset path "$asset" referenced by ${entry.value}.',
      );
    }
    final assetPath = path.normalize(
      path.absolute(
        path.joinAll(<String>[normalizedAssetsRoot, ...asset.split('/')]),
      ),
    );
    assertArtifactPathContained(assetPath, normalizedAssetsRoot);
    final file = File(assetPath);
    if (!await file.exists()) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.fileMissing,
        message:
            'Referenced JSON data asset was not found: $asset '
            '(from ${entry.value}).',
      );
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > jsonDataAssetMaxBytes) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message:
            'JSON data asset "$asset" exceeds the '
            '$jsonDataAssetMaxBytes byte limit.',
      );
    }
    late final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (error) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'Referenced JSON data asset is malformed: $asset\n$error',
      );
    }
    if (decoded is! Map && decoded is! List) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'JSON data asset root must be an object or list: $asset',
      );
    }
    var members = 0;
    void validateValue(Object? value, int depth) {
      if (depth > jsonDataAssetMaxDepth) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.structureInvalid,
          message:
              'JSON data asset "$asset" exceeds depth '
              '$jsonDataAssetMaxDepth.',
        );
      }
      if (value is Map) {
        members += value.length;
        for (final nested in value.values) {
          validateValue(nested, depth + 1);
        }
      } else if (value is List) {
        members += value.length;
        for (final nested in value) {
          validateValue(nested, depth + 1);
        }
      }
      if (members > jsonDataAssetMaxMembers) {
        throw MiniProgramArtifactException(
          code: MiniProgramArtifactErrorCodes.structureInvalid,
          message:
              'JSON data asset "$asset" exceeds '
              '$jsonDataAssetMaxMembers members.',
        );
      }
    }

    validateValue(decoded, 1);
  }
}
