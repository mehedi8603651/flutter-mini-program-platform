import '../../core/authoring_validation.dart';

const int _maxMediaAssetPathLength = 256;
const int _maxMediaEndpointLength = 1024;

final RegExp _mediaAssetPathPattern = RegExp(
  r'^[A-Za-z0-9_-]+(?:/[A-Za-z0-9_.-]+)*\.(?:mp3|m4a|aac|mp4|m3u8)$',
  caseSensitive: false,
);

/// Audio source declared without exposing an arbitrary URL.
final class MpAudioSource {
  MpAudioSource._(this._json);

  factory MpAudioSource.asset(String asset) => MpAudioSource._(
    <String, Object?>{'kind': 'asset', 'asset': _mediaAsset(asset)},
  );

  factory MpAudioSource.publisher({
    required String endpoint,
    Map<String, Object?> parameters = const <String, Object?>{},
  }) => MpAudioSource._(<String, Object?>{
    'kind': 'publisher',
    'endpoint': _relativeMediaEndpoint(endpoint),
    if (parameters.isNotEmpty) 'parameters': parameters,
  });

  final Map<String, Object?> _json;

  Map<String, Object?> toJson() => Map<String, Object?>.from(_json);
}

/// Video source declared without exposing an arbitrary URL.
final class MpVideoSource {
  MpVideoSource._(this._json);

  factory MpVideoSource.asset(String asset) => MpVideoSource._(
    <String, Object?>{'kind': 'asset', 'asset': _mediaAsset(asset)},
  );

  factory MpVideoSource.publisher({
    required String endpoint,
    Map<String, Object?> parameters = const <String, Object?>{},
  }) => MpVideoSource._(<String, Object?>{
    'kind': 'publisher',
    'endpoint': _relativeMediaEndpoint(endpoint),
    if (parameters.isNotEmpty) 'parameters': parameters,
  });

  final Map<String, Object?> _json;

  Map<String, Object?> toJson() => Map<String, Object?>.from(_json);
}

String _mediaAsset(String raw) {
  final value = stableAuthoringString(raw, 'asset');
  if (value.length > _maxMediaAssetPathLength ||
      !_mediaAssetPathPattern.hasMatch(value) ||
      value.split('/').any((segment) => segment == '..')) {
    throw ArgumentError.value(
      raw,
      'asset',
      'Media assets must be safe artifact-relative MP3, M4A, AAC, MP4, or M3U8 paths.',
    );
  }
  return value;
}

String _relativeMediaEndpoint(String raw) {
  final value = stableAuthoringString(raw, 'endpoint');
  final uri = Uri.tryParse(value);
  if (value.length > _maxMediaEndpointLength ||
      uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.pathSegments.any((segment) => segment == '..')) {
    throw ArgumentError.value(
      raw,
      'endpoint',
      'Publisher media endpoints must be safe relative paths.',
    );
  }
  return value.replaceFirst(RegExp(r'^/+'), '');
}
