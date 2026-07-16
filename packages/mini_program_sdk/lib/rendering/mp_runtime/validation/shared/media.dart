part of '../../../mp_screen_renderer.dart';

Map<String, dynamic> _parseImageHeaders(Object? value, {required String path}) {
  if (value is! Map) {
    _fail('Mp image headers must be an object.', path: path);
  }
  final parsed = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      _fail('Mp image header names must be strings.', path: path);
    }
    parsed[_imageHeaderName(key, path: '$path.$key')] = _imageHeaderValue(
      entry.value,
      path: '$path.$key',
    );
  }
  return parsed;
}

String? _optionalImageSource(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  final value = _requiredStableString(json, key, path: path);
  if (!MpScreenValidator._imageSourceNames.contains(value)) {
    _fail(
      'Mp "$key" must be one of: ${MpScreenValidator._imageSourceNames.join(', ')}.',
      path: '$path.$key',
      details: <String, dynamic>{'source': value},
    );
  }
  return value;
}

String? _optionalImageFit(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  final value = _requiredStableString(json, key, path: path);
  if (!MpScreenValidator._imageFitNames.contains(value)) {
    _fail(
      'Mp "$key" must be one of: ${MpScreenValidator._imageFitNames.join(', ')}.',
      path: '$path.$key',
      details: <String, dynamic>{'fit': value},
    );
  }
  return value;
}

String _requiredImageSrc(Object? value, {required String path}) {
  if (value is! String || value.trim().isEmpty) {
    _fail('Mp image src must be a non-empty string.', path: path);
  }
  return value.trim();
}

String _imageHeaderName(String value, {required String path}) {
  if (value.trim().isEmpty || _MpBindingResolver.containsBinding(value)) {
    _fail(
      'Mp image header name must be a non-empty static string.',
      path: path,
    );
  }
  return value.trim();
}

String _imageHeaderValue(Object? value, {required String path}) {
  if (value is! String || value.trim().isEmpty) {
    _fail('Mp image header value must be a non-empty string.', path: path);
  }
  return value;
}

void _validateImageUrl(String src, {required String path}) {
  if (src.length > MpScreenValidator.maxUrlLength) {
    _fail(
      'Mp image URL exceeds the maximum length.',
      path: path,
      details: <String, dynamic>{
        'length': src.length,
        'MpScreenValidator.maxUrlLength': MpScreenValidator.maxUrlLength,
      },
    );
  }
  final uri = Uri.tryParse(src);
  if (uri == null || !uri.hasAuthority) {
    _fail('Mp image src must be an absolute URL.', path: path);
  }
  if (uri.scheme == 'https') {
    return;
  }
  if (uri.scheme == 'http' && _isLocalPreviewHost(uri.host)) {
    return;
  }
  _fail(
    'Mp image src must use https, except local preview loopback URLs.',
    path: path,
    details: <String, dynamic>{'scheme': uri.scheme, 'host': uri.host},
  );
}

void _validateImageSourceSrc(
  String src, {
  required String source,
  required String path,
}) {
  switch (source) {
    case 'network':
      _validateAsyncImageNetworkUrl(src, path: path);
    case 'base64':
      _validateBase64Image(src, path: path);
    case 'asset' || 'auto':
      return;
  }
}

void _validateAsyncImageNetworkUrl(String src, {required String path}) {
  if (src.length > MpScreenValidator.maxUrlLength) {
    _fail(
      'Mp image URL exceeds the maximum length.',
      path: path,
      details: <String, dynamic>{
        'length': src.length,
        'MpScreenValidator.maxUrlLength': MpScreenValidator.maxUrlLength,
      },
    );
  }
  final uri = Uri.tryParse(src);
  if (uri == null || !uri.hasAuthority) {
    _fail('Mp network image src must be an absolute URL.', path: path);
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    _fail(
      'Mp network image src must use http or https.',
      path: path,
      details: <String, dynamic>{'scheme': uri.scheme},
    );
  }
}

void _validateBase64Image(String src, {required String path}) {
  final payload = _base64ImagePayload(src);
  if (payload.replaceAll(RegExp(r'\s+'), '').isEmpty) {
    _fail('Mp base64 image src must be valid base64 data.', path: path);
  }
  try {
    base64Decode(_paddedBase64(payload));
  } on FormatException {
    _fail('Mp base64 image src must be valid base64 data.', path: path);
  }
}

String _base64ImagePayload(String value) {
  final trimmed = value.trim();
  final match = RegExp(
    r'^data:image\/[-+.\w]+;base64,',
    caseSensitive: false,
  ).firstMatch(trimmed);
  return match == null ? trimmed : trimmed.substring(match.end);
}

String _paddedBase64(String value) {
  final compact = value.replaceAll(RegExp(r'\s+'), '');
  final remainder = compact.length % 4;
  return remainder == 0
      ? compact
      : compact.padRight(compact.length + 4 - remainder, '=');
}

bool _isLocalPreviewHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized.startsWith('127.') ||
      normalized == '::1' ||
      normalized == '0.0.0.0' ||
      normalized == '10.0.2.2';
}
