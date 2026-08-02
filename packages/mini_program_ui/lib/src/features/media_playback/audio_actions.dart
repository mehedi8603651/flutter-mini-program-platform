import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';
import '../../core/value_normalization.dart';
import 'media_sources.dart';
import 'media_validation.dart';

/// Headless foreground audio playback actions.
final class MpAudioActions {
  const MpAudioActions();

  MpAction play({
    required String audioId,
    required MpAudioSource source,
    double volume = 1,
    bool loop = false,
    String cacheMode = 'streaming',
    String? statusState,
    String? errorState,
    String? requestId,
  }) => _sourceAction(
    'audio.play',
    playerId: audioId,
    source: source.toJson(),
    volume: volume,
    loop: loop,
    cacheMode: cacheMode,
    statusState: statusState,
    errorState: errorState,
    requestId: requestId,
  );

  MpAction preload({
    required String audioId,
    required MpAudioSource source,
    String cacheMode = 'streaming',
    String? statusState,
    String? errorState,
    String? requestId,
  }) => _sourceAction(
    'audio.preload',
    playerId: audioId,
    source: source.toJson(),
    cacheMode: cacheMode,
    statusState: statusState,
    errorState: errorState,
    requestId: requestId,
  );

  MpAction pause({required String audioId, String? requestId}) =>
      buildMediaControlAction('audio.pause', audioId, requestId: requestId);

  MpAction seek({
    required String audioId,
    required Duration position,
    String? requestId,
  }) => buildMediaControlAction(
    'audio.seek',
    audioId,
    requestId: requestId,
    extra: <String, Object?>{
      'positionMs': nonNegativeInt(position.inMilliseconds, 'position'),
    },
  );

  MpAction stop({required String audioId, String? requestId}) =>
      buildMediaControlAction('audio.stop', audioId, requestId: requestId);

  MpAction setVolume({
    required String audioId,
    required double volume,
    String? requestId,
  }) {
    final normalized = finiteNumber(volume, 'volume').toDouble();
    if (normalized < 0 || normalized > 1) {
      throw ArgumentError.value(
        volume,
        'volume',
        'Volume must be from 0 to 1.',
      );
    }
    return buildMediaControlAction(
      'audio.setVolume',
      audioId,
      requestId: requestId,
      extra: <String, Object?>{'volume': normalized},
    );
  }

  MpAction setSpeed({
    required String audioId,
    required double speed,
    String? requestId,
  }) {
    final normalized = finiteNumber(speed, 'speed').toDouble();
    if (normalized < 0.25 || normalized > 3) {
      throw ArgumentError.value(
        speed,
        'speed',
        'Speed must be from 0.25 to 3.',
      );
    }
    return buildMediaControlAction(
      'audio.setSpeed',
      audioId,
      requestId: requestId,
      extra: <String, Object?>{'speed': normalized},
    );
  }

  MpAction getStatus({
    required String audioId,
    required String targetState,
    String? requestId,
  }) => buildMediaControlAction(
    'audio.getStatus',
    audioId,
    requestId: requestId,
    extra: <String, Object?>{
      'targetState': requiredStateKey(targetState, 'targetState'),
    },
  );

  MpAction release({required String audioId, String? requestId}) =>
      buildMediaControlAction('audio.release', audioId, requestId: requestId);
}

MpAction _sourceAction(
  String type, {
  required String playerId,
  required Map<String, Object?> source,
  double volume = 1,
  bool loop = false,
  required String cacheMode,
  String? statusState,
  String? errorState,
  String? requestId,
}) {
  final normalizedVolume = finiteNumber(volume, 'volume').toDouble();
  if (normalizedVolume < 0 || normalizedVolume > 1) {
    throw ArgumentError.value(volume, 'volume', 'Volume must be from 0 to 1.');
  }
  return MpAction(
    type,
    props: <String, Object?>{
      'playerId': normalizeMediaPlayerId(playerId),
      'source': source,
      'cacheMode': allowedValue(cacheMode, 'cacheMode', const <String>{
        'streaming',
        'temporary',
      }),
      'loop': loop,
      'volume': normalizedVolume,
      if (statusState != null)
        'statusState': requiredStateKey(statusState, 'statusState'),
      if (errorState != null)
        'errorState': requiredStateKey(errorState, 'errorState'),
      if (requestId != null)
        'requestId': stableAuthoringString(requestId, 'requestId'),
    },
  );
}
