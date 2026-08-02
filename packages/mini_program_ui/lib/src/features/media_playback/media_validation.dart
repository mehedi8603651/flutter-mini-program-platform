import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';

String normalizeMediaPlayerId(String value) {
  final normalized = stableAuthoringString(value, 'playerId');
  if (!RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, 'playerId', 'Invalid media player ID.');
  }
  return normalized;
}

MpAction buildMediaControlAction(
  String type,
  String playerId, {
  String? requestId,
  Map<String, Object?> extra = const <String, Object?>{},
}) => MpAction(
  type,
  props: <String, Object?>{
    ...extra,
    'playerId': normalizeMediaPlayerId(playerId),
    if (requestId != null)
      'requestId': stableAuthoringString(requestId, 'requestId'),
  },
);
