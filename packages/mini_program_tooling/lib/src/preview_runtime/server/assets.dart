import 'dart:io';

import 'package:path/path.dart' as path;

import 'models.dart';

String resolvePreviewAssetPath({
  required String assetRootPath,
  required String rawRelativePath,
}) {
  final normalizedAssetRoot = path.normalize(path.absolute(assetRootPath));
  var normalizedRelativePath = rawRelativePath.replaceAll('\\', '/');
  if (normalizedRelativePath.startsWith('assets/')) {
    normalizedRelativePath = normalizedRelativePath.substring('assets/'.length);
  }
  while (normalizedRelativePath.startsWith('/')) {
    normalizedRelativePath = normalizedRelativePath.substring(1);
  }

  final candidatePath = path.normalize(
    path.join(normalizedAssetRoot, normalizedRelativePath),
  );
  if (candidatePath != normalizedAssetRoot &&
      !path.isWithin(normalizedAssetRoot, candidatePath)) {
    throw const MiniProgramPreviewException(
      'Preview asset path escapes the mini-program asset root.',
    );
  }
  return candidatePath;
}

Map<String, dynamic> rewritePreviewScreenJson(
  Map<String, dynamic> screenJson, {
  required MiniProgramPreviewBundle bundle,
  required Uri baseUri,
}) {
  final rewritten = _rewriteValue(screenJson, bundle: bundle, baseUri: baseUri);
  return Map<String, dynamic>.from(rewritten as Map);
}

Object? _rewriteValue(
  Object? value, {
  required MiniProgramPreviewBundle bundle,
  required Uri baseUri,
}) {
  if (value is List) {
    return value
        .map((entry) => _rewriteValue(entry, bundle: bundle, baseUri: baseUri))
        .toList();
  }

  if (value is! Map) {
    return value;
  }

  final json = value.map((key, entry) => MapEntry(key.toString(), entry));
  final rewrittenImage = _rewriteLocalAssetImage(
    json,
    bundle: bundle,
    baseUri: baseUri,
  );
  if (rewrittenImage != null) {
    return rewrittenImage;
  }

  return json.map(
    (key, entry) =>
        MapEntry(key, _rewriteValue(entry, bundle: bundle, baseUri: baseUri)),
  );
}

Map<String, dynamic>? _rewriteLocalAssetImage(
  Map<String, dynamic> json, {
  required MiniProgramPreviewBundle bundle,
  required Uri baseUri,
}) {
  if (bundle.assetRootPath == null || json['type'] != 'image') {
    return null;
  }

  final rawTopLevelSource = json['src'];
  if (rawTopLevelSource is String &&
      _isLocalAssetSource(rawTopLevelSource, bundle: bundle)) {
    return <String, dynamic>{
      ...json,
      'imageType': 'network',
      'src': baseUri
          .resolve('assets/${normalizePreviewAssetPath(rawTopLevelSource)}')
          .toString(),
    };
  }

  final props = json['props'];
  if (props is Map) {
    final normalizedProps = props.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final rawPropsSource = normalizedProps['src'];
    if (rawPropsSource is String &&
        _isLocalAssetSource(rawPropsSource, bundle: bundle)) {
      return <String, dynamic>{
        ...json,
        'props': <String, dynamic>{
          ...normalizedProps,
          'src': baseUri
              .resolve('assets/${normalizePreviewAssetPath(rawPropsSource)}')
              .toString(),
        },
      };
    }
  }

  return null;
}

bool _isLocalAssetSource(
  String rawSource, {
  required MiniProgramPreviewBundle bundle,
}) {
  if (rawSource.trim().isEmpty || bundle.assetRootPath == null) {
    return false;
  }

  final source = rawSource.trim();
  final uri = Uri.tryParse(source);
  if (uri != null && uri.scheme.isNotEmpty) {
    return false;
  }

  if (source.startsWith('{') || source.startsWith(r'$')) {
    return false;
  }

  try {
    final assetPath = resolvePreviewAssetPath(
      assetRootPath: bundle.assetRootPath!,
      rawRelativePath: source,
    );
    return File(assetPath).existsSync();
  } on MiniProgramPreviewException {
    return false;
  }
}

String normalizePreviewAssetPath(String rawSource) {
  var value = rawSource.replaceAll('\\', '/').trim();
  if (value.startsWith('assets/')) {
    value = value.substring('assets/'.length);
  }
  while (value.startsWith('/')) {
    value = value.substring(1);
  }
  return value
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('/');
}

String? previewAssetContentType(String filePath) {
  switch (path.extension(filePath).toLowerCase()) {
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.webp':
      return 'image/webp';
    case '.svg':
      return 'image/svg+xml';
    case '.gif':
      return 'image/gif';
    case '.json':
      return 'application/json';
    default:
      return null;
  }
}
