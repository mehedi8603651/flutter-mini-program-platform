import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';
import '../../core/mp_node.dart';
import '../../core/value_normalization.dart';
import '../content/image_models.dart';
import 'media_sources.dart';
import 'media_validation.dart';

/// Controls an inline video player declared with [Mp.videoView].
final class MpVideoActions {
  const MpVideoActions();

  MpAction play({required String playerId, String? requestId}) =>
      buildMediaControlAction('video.play', playerId, requestId: requestId);

  MpAction pause({required String playerId, String? requestId}) =>
      buildMediaControlAction('video.pause', playerId, requestId: requestId);

  MpAction seek({
    required String playerId,
    required Duration position,
    String? requestId,
  }) => buildMediaControlAction(
    'video.seek',
    playerId,
    requestId: requestId,
    extra: <String, Object?>{
      'positionMs': nonNegativeInt(position.inMilliseconds, 'position'),
    },
  );

  MpAction stop({required String playerId, String? requestId}) =>
      buildMediaControlAction('video.stop', playerId, requestId: requestId);

  MpAction setMuted({
    required String playerId,
    required bool muted,
    String? requestId,
  }) => buildMediaControlAction(
    'video.setMuted',
    playerId,
    requestId: requestId,
    extra: <String, Object?>{'muted': muted},
  );

  MpAction setVolume({
    required String playerId,
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
      'video.setVolume',
      playerId,
      requestId: requestId,
      extra: <String, Object?>{'volume': normalized},
    );
  }

  MpAction setSpeed({
    required String playerId,
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
      'video.setSpeed',
      playerId,
      requestId: requestId,
      extra: <String, Object?>{'speed': normalized},
    );
  }

  MpAction getStatus({
    required String playerId,
    required String targetState,
    String? requestId,
  }) => buildMediaControlAction(
    'video.getStatus',
    playerId,
    requestId: requestId,
    extra: <String, Object?>{
      'targetState': requiredStateKey(targetState, 'targetState'),
    },
  );

  MpAction release({required String playerId, String? requestId}) =>
      buildMediaControlAction('video.release', playerId, requestId: requestId);
}

MpNode buildVideoViewNode({
  required String playerId,
  required MpVideoSource source,
  String? poster,
  MpImageSource posterSource = MpImageSource.auto,
  bool controls = true,
  bool autoplay = false,
  bool loop = false,
  bool muted = false,
  double volume = 1,
  double speed = 1,
  String cacheMode = 'streaming',
  double aspectRatio = 16 / 9,
  MpImageFit fit = MpImageFit.contain,
  String? statusState,
  String? errorState,
  String semanticLabel = 'Video player',
}) {
  final normalizedVolume = finiteNumber(volume, 'volume').toDouble();
  final normalizedSpeed = finiteNumber(speed, 'speed').toDouble();
  final normalizedRatio = finiteNumber(aspectRatio, 'aspectRatio').toDouble();
  if (normalizedVolume < 0 || normalizedVolume > 1) {
    throw ArgumentError.value(volume, 'volume', 'Volume must be from 0 to 1.');
  }
  if (normalizedSpeed < 0.25 || normalizedSpeed > 3) {
    throw ArgumentError.value(speed, 'speed', 'Speed must be from 0.25 to 3.');
  }
  if (normalizedRatio < 0.25 || normalizedRatio > 4) {
    throw ArgumentError.value(
      aspectRatio,
      'aspectRatio',
      'Aspect ratio must be from 0.25 to 4.',
    );
  }
  return MpNode(
    'videoView',
    props: <String, Object?>{
      'aspectRatio': normalizedRatio,
      'autoplay': autoplay,
      'cacheMode': allowedValue(cacheMode, 'cacheMode', const <String>{
        'streaming',
        'temporary',
      }),
      'controls': controls,
      'fit': fit.wireName,
      'loop': loop,
      'muted': muted,
      'playerId': normalizeMediaPlayerId(playerId),
      if (poster != null) 'poster': requiredAuthoringString(poster, 'poster'),
      if (poster != null) 'posterSource': posterSource.wireName,
      'semanticLabel': requiredAuthoringString(semanticLabel, 'semanticLabel'),
      'source': source.toJson(),
      'speed': normalizedSpeed,
      'volume': normalizedVolume,
      if (statusState != null)
        'statusState': requiredStateKey(statusState, 'statusState'),
      if (errorState != null)
        'errorState': requiredStateKey(errorState, 'errorState'),
    },
  );
}
