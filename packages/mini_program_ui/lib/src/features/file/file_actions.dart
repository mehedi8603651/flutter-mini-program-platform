import '../../core/authoring_validation.dart';
import '../../core/binding_validation.dart';
import '../../core/mp_action.dart';
import '../../core/value_normalization.dart';

/// Publisher file upload, download, and cancellation actions.
final class MpFileActions {
  /// Creates file transfer action helpers.
  const MpFileActions();

  /// Opens the host picker and streams selected files to Publisher API.
  MpAction upload({
    required String endpoint,
    List<String> mimeTypes = const <String>['*/*'],
    List<String> mediaRefs = const <String>[],
    bool multiple = false,
    String fieldName = 'file',
    Map<String, Object?> metadata = const <String, Object?>{},
    required String progressState,
    required String targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) => MpAction(
    'file.upload',
    props: <String, Object?>{
      'endpoint': _relativeEndpoint(endpoint),
      'mimeTypes': _mimeTypes(mimeTypes),
      if (mediaRefs.isNotEmpty) 'mediaRefs': _mediaRefs(mediaRefs),
      if (multiple) 'multiple': true,
      'fieldName': requiredFieldName(fieldName, 'fieldName'),
      if (metadata.isNotEmpty) 'metadata': metadata,
      'progressState': requiredStateKey(progressState, 'progressState'),
      'targetState': requiredStateKey(targetState, 'targetState'),
      if (statusState != null)
        'statusState': requiredStateKey(statusState, 'statusState'),
      if (errorState != null)
        'errorState': requiredStateKey(errorState, 'errorState'),
      if (requestId != null)
        'requestId': stableAuthoringString(requestId, 'requestId'),
    },
  );

  /// Streams a Publisher API response to an accepted host destination.
  MpAction download({
    required String endpoint,
    String method = 'GET',
    Map<String, Object?> request = const <String, Object?>{},
    String destination = 'downloads',
    String? suggestedName,
    String? expectedMimeType,
    required String progressState,
    required String targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) => MpAction(
    'file.download',
    props: <String, Object?>{
      'endpoint': _relativeEndpoint(endpoint),
      'method': allowedValue(method.toUpperCase(), 'method', const <String>{
        'GET',
        'POST',
      }),
      if (request.isNotEmpty) 'request': request,
      'destination': allowedValue(destination, 'destination', const <String>{
        'downloads',
        'choose',
        'temporary',
      }),
      if (suggestedName != null)
        'suggestedName': requiredAuthoringString(
          suggestedName,
          'suggestedName',
        ),
      if (expectedMimeType != null)
        'expectedMimeType': _mimeType(expectedMimeType, 'expectedMimeType'),
      'progressState': requiredStateKey(progressState, 'progressState'),
      'targetState': requiredStateKey(targetState, 'targetState'),
      if (statusState != null)
        'statusState': requiredStateKey(statusState, 'statusState'),
      if (errorState != null)
        'errorState': requiredStateKey(errorState, 'errorState'),
      if (requestId != null)
        'requestId': stableAuthoringString(requestId, 'requestId'),
    },
  );

  /// Cancels an active upload or download owned by this mini-program.
  MpAction cancel({
    required String transferId,
    String? statusState,
    String? errorState,
    String? requestId,
  }) => MpAction(
    'file.cancel',
    props: <String, Object?>{
      'transferId': requiredAuthoringString(transferId, 'transferId'),
      if (statusState != null)
        'statusState': requiredStateKey(statusState, 'statusState'),
      if (errorState != null)
        'errorState': requiredStateKey(errorState, 'errorState'),
      if (requestId != null)
        'requestId': stableAuthoringString(requestId, 'requestId'),
    },
  );
}

List<String> _mediaRefs(List<String> values) {
  if (values.isEmpty || values.length > 32) {
    throw ArgumentError.value(
      values,
      'mediaRefs',
      'Provide from 1 to 32 media references.',
    );
  }
  return values
      .map((value) {
        final normalized = requiredAuthoringString(value, 'mediaRefs');
        if (normalized.length > 512 ||
            (normalized.contains('{{') && !isFullBinding(normalized))) {
          throw ArgumentError.value(
            value,
            'mediaRefs',
            'Media references must be at most 512 characters and use only full bindings.',
          );
        }
        return normalized;
      })
      .toList(growable: false);
}

String _relativeEndpoint(String value) {
  final endpoint = stableAuthoringString(value, 'endpoint');
  final uri = Uri.tryParse(endpoint);
  if (uri == null || uri.hasScheme || uri.hasAuthority) {
    throw ArgumentError.value(
      value,
      'endpoint',
      'File transfer endpoints must be relative Publisher API paths.',
    );
  }
  final normalized = endpoint.replaceFirst(RegExp(r'^/+'), '');
  if (normalized.isEmpty || Uri.parse(normalized).pathSegments.contains('..')) {
    throw ArgumentError.value(value, 'endpoint', 'Endpoint is not safe.');
  }
  return normalized;
}

List<String> _mimeTypes(List<String> values) {
  if (values.isEmpty || values.length > 32) {
    throw ArgumentError.value(
      values,
      'mimeTypes',
      'Provide from 1 to 32 MIME types.',
    );
  }
  return values
      .map((value) => _mimeType(value, 'mimeTypes'))
      .toSet()
      .toList(growable: false);
}

String _mimeType(String value, String name) {
  final normalized = stableAuthoringString(value, name).toLowerCase();
  if (normalized == '*/*') {
    return normalized;
  }
  final parts = normalized.split('/');
  final token = RegExp(r'^[a-z0-9!#$&^_.+-]+$');
  if (parts.length != 2 ||
      !token.hasMatch(parts.first) ||
      (parts.last != '*' && !token.hasMatch(parts.last))) {
    throw ArgumentError.value(value, name, 'Invalid MIME type.');
  }
  return normalized;
}
