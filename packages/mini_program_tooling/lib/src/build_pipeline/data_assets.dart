import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';

Future<void> validateMiniProgramBuildJsonDataAssets({
  required String screensDirectoryPath,
  required String assetsDirectoryPath,
}) async {
  const maxBytes = 2 * 1024 * 1024;
  const maxDepth = 32;
  const maxMembers = 50000;
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
    void visit(Object? value, String jsonPath) {
      if (value is Map) {
        if (value['type'] == 'data.loadJsonAsset') {
          final props = value['props'];
          final asset = props is Map ? props['asset'] : null;
          if (asset is! String || asset.trim().isEmpty) {
            throw MiniProgramBuildException(
              'data.loadJsonAsset requires a static asset path in '
              '${entity.path} at $jsonPath.',
            );
          }
          references.putIfAbsent(asset, () => '${entity.path}:$jsonPath');
        }
        for (final entry in value.entries) {
          visit(entry.value, '$jsonPath.${entry.key}');
        }
      } else if (value is List) {
        for (var index = 0; index < value.length; index += 1) {
          visit(value[index], '$jsonPath[$index]');
        }
      }
    }

    visit(decoded, r'$');
  }

  final assetsRoot = p.normalize(p.absolute(assetsDirectoryPath));
  for (final reference in references.entries) {
    final asset = reference.key;
    final validPath =
        asset.length <= 256 &&
        RegExp(
          r'^[A-Za-z0-9_-]+(?:/[A-Za-z0-9_.-]+)*\.json$',
        ).hasMatch(asset) &&
        !asset.contains('..');
    if (!validPath) {
      throw MiniProgramBuildException(
        'Unsafe JSON data asset path "$asset" referenced by '
        '${reference.value}.',
      );
    }
    final assetPath = p.normalize(
      p.absolute(p.joinAll(<String>[assetsRoot, ...asset.split('/')])),
    );
    if (!p.isWithin(assetsRoot, assetPath)) {
      throw MiniProgramBuildException(
        'JSON data asset escapes the assets directory: $asset',
      );
    }
    final file = File(assetPath);
    if (!await file.exists()) {
      throw MiniProgramBuildException(
        'Referenced JSON data asset was not found: $asset '
        '(from ${reference.value}).',
      );
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw MiniProgramBuildException(
        'JSON data asset "$asset" exceeds the $maxBytes byte limit.',
      );
    }
    late final Object? data;
    try {
      data = jsonDecode(utf8.decode(bytes));
    } catch (error) {
      throw MiniProgramBuildException(
        'Referenced JSON data asset is malformed: $asset\n$error',
      );
    }
    if (data is! Map && data is! List) {
      throw MiniProgramBuildException(
        'JSON data asset root must be an object or list: $asset',
      );
    }
    var members = 0;
    void validateValue(Object? value, int depth) {
      if (depth > maxDepth) {
        throw MiniProgramBuildException(
          'JSON data asset "$asset" exceeds depth $maxDepth.',
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
      if (members > maxMembers) {
        throw MiniProgramBuildException(
          'JSON data asset "$asset" exceeds $maxMembers members.',
        );
      }
    }

    validateValue(data, 1);
  }
}
