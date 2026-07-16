import 'dart:convert';

import '../../core/mp_node.dart';
import '../shared/presentation_validation.dart';
import 'image_models.dart';

MpNode buildImageNode({
  required String src,
  MpImageSource source = MpImageSource.auto,
  num? width,
  num? height,
  MpImageFit fit = MpImageFit.cover,
  MpNode? placeholder,
  MpNode? error,
  String? semanticLabel,
  Map<String, String>? headers,
  bool cache = true,
  String? cacheKey,
  Duration fadeInDuration = const Duration(milliseconds: 200),
  String? alt,
}) {
  final normalizedSrc = requiredWidgetString(src, 'src');
  if (source == MpImageSource.base64) {
    _validateBase64ImageSource(normalizedSrc, 'src');
  }
  final normalizedSemanticLabel = semanticLabel == null
      ? null
      : requiredWidgetString(semanticLabel, 'semanticLabel');
  final normalizedAlt = alt == null ? null : requiredWidgetString(alt, 'alt');
  final normalizedHeaders = _imageHeaders(headers);
  return MpNode(
    'image',
    props: <String, Object?>{
      'cache': cache,
      'fadeInDurationMs': nonNegativeWidgetNumber(
        fadeInDuration.inMilliseconds,
        'fadeInDuration',
      ),
      'fit': fit.wireName,
      'source': source.wireName,
      'src': normalizedSrc,
      if (cacheKey != null)
        'cacheKey': requiredWidgetString(cacheKey, 'cacheKey'),
      if (error != null) 'error': error,
      if (height != null) 'height': positiveWidgetNumber(height, 'height'),
      if (normalizedHeaders.isNotEmpty) 'headers': normalizedHeaders,
      if (placeholder != null) 'placeholder': placeholder,
      if (normalizedSemanticLabel != null)
        'semanticLabel': normalizedSemanticLabel
      else if (normalizedAlt != null)
        'semanticLabel': normalizedAlt,
      if (normalizedAlt != null) 'alt': normalizedAlt,
      if (width != null) 'width': positiveWidgetNumber(width, 'width'),
    },
  );
}

Map<String, Object?> _imageHeaders(Map<String, String>? headers) {
  if (headers == null || headers.isEmpty) {
    return const <String, Object?>{};
  }
  return <String, Object?>{
    for (final entry in headers.entries)
      requiredWidgetString(entry.key, 'headers.key'): requiredWidgetString(
        entry.value,
        'headers.${entry.key}',
      ),
  };
}

void _validateBase64ImageSource(String value, String name) {
  final payload = _base64Payload(value);
  if (payload.replaceAll(RegExp(r'\s+'), '').isEmpty) {
    throw ArgumentError.value(
      value,
      name,
      'Value must be valid base64 image data.',
    );
  }
  try {
    base64Decode(_paddedBase64(payload));
  } on FormatException {
    throw ArgumentError.value(
      value,
      name,
      'Value must be valid base64 image data.',
    );
  }
}

String _base64Payload(String value) {
  final trimmed = value.trim();
  final dataUri = RegExp(
    r'^data:image\/[-+.\w]+;base64,',
    caseSensitive: false,
  );
  final match = dataUri.firstMatch(trimmed);
  if (match == null) {
    return trimmed;
  }
  return trimmed.substring(match.end);
}

String _paddedBase64(String value) {
  final compact = value.replaceAll(RegExp(r'\s+'), '');
  final remainder = compact.length % 4;
  return remainder == 0
      ? compact
      : compact.padRight(compact.length + 4 - remainder, '=');
}
