import '../../core/authoring_validation.dart';
import '../../core/binding_validation.dart';
import '../../core/mp_action.dart';

/// Host-controlled system sharing actions.
final class MpShareActions {
  const MpShareActions();

  /// Opens the platform share chooser after an explicit user gesture.
  ///
  /// [mediaRefs] accepts either a list of app-owned opaque media references or
  /// one full binding that resolves to such a list. Opening the chooser does
  /// not prove that the user completed a share.
  MpAction open({
    String? title,
    String? text,
    String? url,
    Object? mediaRefs,
    String? targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) {
    final normalizedTitle = title == null
        ? null
        : _shareString(title, 'title', maxLength: 200);
    final normalizedText = text == null
        ? null
        : _shareString(text, 'text', maxLength: 32768);
    final normalizedUrl = url == null ? null : _shareUrl(url);
    final normalizedMediaRefs = _shareMediaRefs(mediaRefs);
    if (normalizedText == null &&
        normalizedUrl == null &&
        normalizedMediaRefs == null) {
      throw ArgumentError(
        'Mp.share.open requires text, an HTTPS URL, or mediaRefs.',
      );
    }
    return MpAction(
      'share.open',
      props: <String, Object?>{
        if (normalizedTitle != null) 'title': normalizedTitle,
        if (normalizedText != null) 'text': normalizedText,
        if (normalizedUrl != null) 'url': normalizedUrl,
        if (normalizedMediaRefs != null) 'mediaRefs': normalizedMediaRefs,
        if (targetState != null)
          'targetState': requiredStateKey(targetState, 'targetState'),
        if (statusState != null)
          'statusState': requiredStateKey(statusState, 'statusState'),
        if (errorState != null)
          'errorState': requiredStateKey(errorState, 'errorState'),
        if (requestId != null)
          'requestId': stableAuthoringString(requestId, 'requestId'),
      },
    );
  }
}

String _shareString(String value, String name, {required int maxLength}) {
  final normalized = requiredAuthoringString(value, name);
  if (normalized.length > maxLength) {
    throw ArgumentError.value(
      value,
      name,
      'Value cannot exceed $maxLength characters.',
    );
  }
  return normalized;
}

String _shareUrl(String value) {
  final normalized = _shareString(value, 'url', maxLength: 2048);
  if (normalized.contains('{{')) {
    if (!isFullBinding(normalized)) {
      throw ArgumentError.value(
        value,
        'url',
        'URL must be an HTTPS literal or one full binding.',
      );
    }
    return normalized;
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw ArgumentError.value(value, 'url', 'URL must use HTTPS.');
  }
  return uri.toString();
}

Object? _shareMediaRefs(Object? value) {
  if (value == null) return null;
  if (isFullBinding(value)) return value;
  if (value is! List<String> || value.isEmpty || value.length > 10) {
    throw ArgumentError.value(
      value,
      'mediaRefs',
      'Provide 1-10 media references or one full binding.',
    );
  }
  final result = <String>[];
  for (final item in value) {
    final normalized = _shareString(item, 'mediaRefs', maxLength: 512);
    if (normalized.contains('{{') && !isFullBinding(normalized)) {
      throw ArgumentError.value(
        item,
        'mediaRefs',
        'Media references must be literals or full bindings.',
      );
    }
    if (!result.contains(normalized)) result.add(normalized);
  }
  return List<String>.unmodifiable(result);
}
