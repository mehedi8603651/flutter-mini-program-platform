/// Media category owned by one host playback session.
enum MiniProgramMediaPlaybackKind {
  audio('audio'),
  video('video');

  const MiniProgramMediaPlaybackKind(this.wireName);

  final String wireName;
}

/// Stable foreground playback lifecycle exposed to mini-program state.
enum MiniProgramMediaPlaybackStatus {
  idle,
  loading,
  ready,
  playing,
  paused,
  buffering,
  completed,
  error,
}

/// JSON-safe playback snapshot. It intentionally contains no URL or headers.
final class MiniProgramMediaPlaybackSnapshot {
  MiniProgramMediaPlaybackSnapshot({
    required this.playerId,
    required this.kind,
    required this.status,
    this.position = Duration.zero,
    this.duration,
    this.buffered = Duration.zero,
    this.volume = 1,
    this.speed = 1,
    this.muted = false,
  }) {
    validate();
  }

  factory MiniProgramMediaPlaybackSnapshot.fromJson(Map<String, dynamic> json) {
    final playerId = json['playerId'];
    final kind = json['kind'];
    final status = json['status'];
    final positionMs = json['positionMs'];
    final durationMs = json['durationMs'];
    final bufferedMs = json['bufferedMs'];
    final volume = json['volume'];
    final speed = json['speed'];
    final muted = json['muted'];
    if (playerId is! String ||
        kind is! String ||
        status is! String ||
        positionMs is! int ||
        (durationMs != null && durationMs is! int) ||
        bufferedMs is! int ||
        volume is! num ||
        speed is! num ||
        muted is! bool) {
      throw const FormatException(
        'Invalid mini-program media playback snapshot.',
      );
    }
    return MiniProgramMediaPlaybackSnapshot(
      playerId: playerId,
      kind: _playbackKind(kind),
      status: _playbackStatus(status),
      position: Duration(milliseconds: positionMs),
      duration: durationMs == null ? null : Duration(milliseconds: durationMs),
      buffered: Duration(milliseconds: bufferedMs),
      volume: volume.toDouble(),
      speed: speed.toDouble(),
      muted: muted,
    );
  }

  final String playerId;
  final MiniProgramMediaPlaybackKind kind;
  final MiniProgramMediaPlaybackStatus status;
  final Duration position;
  final Duration? duration;
  final Duration buffered;
  final double volume;
  final double speed;
  final bool muted;

  void validate() {
    if (!RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(playerId)) {
      throw const FormatException('Invalid media playback playerId.');
    }
    if (position.isNegative ||
        duration?.isNegative == true ||
        buffered.isNegative) {
      throw const FormatException(
        'Media playback durations must not be negative.',
      );
    }
    if (!volume.isFinite || volume < 0 || volume > 1) {
      throw const FormatException('Media playback volume must be 0-1.');
    }
    if (!speed.isFinite || speed < 0.25 || speed > 3) {
      throw const FormatException('Media playback speed must be 0.25-3.');
    }
  }

  Map<String, Object?> toJson() {
    validate();
    return <String, Object?>{
      'playerId': playerId,
      'kind': kind.wireName,
      'status': status.name,
      'positionMs': position.inMilliseconds,
      if (duration != null) 'durationMs': duration!.inMilliseconds,
      'bufferedMs': buffered.inMilliseconds,
      'volume': volume,
      'speed': speed,
      'muted': muted,
    };
  }
}

MiniProgramMediaPlaybackKind _playbackKind(String value) {
  for (final kind in MiniProgramMediaPlaybackKind.values) {
    if (kind.wireName == value) return kind;
  }
  throw FormatException('Unsupported media playback kind "$value".');
}

MiniProgramMediaPlaybackStatus _playbackStatus(String value) {
  for (final status in MiniProgramMediaPlaybackStatus.values) {
    if (status.name == value) return status;
  }
  throw FormatException('Unsupported media playback status "$value".');
}
