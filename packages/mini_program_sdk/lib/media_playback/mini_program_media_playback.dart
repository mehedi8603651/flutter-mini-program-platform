import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Host authority for streamed foreground audio and inline video playback.
@immutable
class MiniProgramMediaPlaybackPolicy {
  const MiniProgramMediaPlaybackPolicy({
    this.audioEnabled = false,
    this.videoEnabled = false,
    this.temporaryCacheEnabled = false,
    bool? audioTemporaryCacheEnabled,
    bool? videoTemporaryCacheEnabled,
  }) : audioTemporaryCacheEnabled =
           audioTemporaryCacheEnabled ?? temporaryCacheEnabled,
       videoTemporaryCacheEnabled =
           videoTemporaryCacheEnabled ?? temporaryCacheEnabled;

  final bool audioEnabled;
  final bool videoEnabled;
  final bool temporaryCacheEnabled;
  final bool audioTemporaryCacheEnabled;
  final bool videoTemporaryCacheEnabled;

  bool allows(MiniProgramMediaPlaybackKind kind) => switch (kind) {
    MiniProgramMediaPlaybackKind.audio => audioEnabled,
    MiniProgramMediaPlaybackKind.video => videoEnabled,
  };

  bool allowsTemporaryCache(MiniProgramMediaPlaybackKind kind) =>
      switch (kind) {
        MiniProgramMediaPlaybackKind.audio => audioTemporaryCacheEnabled,
        MiniProgramMediaPlaybackKind.video => videoTemporaryCacheEnabled,
      };
}

abstract interface class MiniProgramMediaPlaybackPolicyProvider {
  MiniProgramMediaPlaybackPolicy mediaPlaybackPolicyFor(String miniProgramId);
}

enum MiniProgramMediaCacheMode { streaming, temporary }

/// Trusted playback source resolved by the SDK and visible only to the host.
@immutable
class MiniProgramResolvedPlaybackSource {
  const MiniProgramResolvedPlaybackSource({
    required this.candidateUris,
    this.headers = const <String, String>{},
    this.timeout = const Duration(seconds: 10),
  });

  final List<Uri> candidateUris;
  final Map<String, String> headers;
  final Duration timeout;
}

/// Creation request passed to a trusted playback provider.
@immutable
class MiniProgramMediaPlaybackRequest {
  const MiniProgramMediaPlaybackRequest({
    required this.miniProgramId,
    required this.playerId,
    required this.kind,
    required this.sourceKey,
    required this.source,
    required this.cacheMode,
    required this.autoplay,
    required this.loop,
    required this.volume,
    required this.speed,
    required this.muted,
    this.maxCacheBytes,
    this.cacheTtl,
  });

  final String miniProgramId;
  final String playerId;
  final MiniProgramMediaPlaybackKind kind;
  final String sourceKey;
  final MiniProgramResolvedPlaybackSource source;
  final MiniProgramMediaCacheMode cacheMode;
  final bool autoplay;
  final bool loop;
  final double volume;
  final double speed;
  final bool muted;
  final int? maxCacheBytes;
  final Duration? cacheTtl;
}

/// One host-owned playback session. URLs and request headers stay private.
abstract interface class MiniProgramMediaPlaybackSession implements Listenable {
  String get sourceKey;

  MiniProgramMediaPlaybackSnapshot get snapshot;

  Widget buildVideoView({
    required BoxFit fit,
    required bool controls,
    required String semanticLabel,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> setMuted(bool muted);
  Future<void> setVolume(double volume);
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}

/// Optional session surface for providers that support native fullscreen video.
///
/// Keeping this separate preserves source compatibility for Phase 1 provider
/// implementations while allowing the runtime to expose fullscreen actions.
abstract interface class MiniProgramFullscreenMediaPlaybackSession {
  Future<void> enterFullscreen();
  Future<void> exitFullscreen();
}

/// Platform adapter for foreground streamed media playback.
abstract interface class MiniProgramMediaPlaybackProvider {
  Future<MiniProgramMediaPlaybackSession> createSession(
    MiniProgramMediaPlaybackRequest request,
  );
}

/// Stable provider failure mapped to a contract error code.
class MiniProgramMediaPlaybackException implements Exception {
  const MiniProgramMediaPlaybackException({
    required this.errorCode,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final String errorCode;
  final String message;
  final Map<String, Object?> details;

  @override
  String toString() => message;
}

/// App-scoped session owner shared by actions and inline video nodes.
class MiniProgramMediaPlaybackManager {
  MiniProgramMediaPlaybackManager(this._provider);

  final MiniProgramMediaPlaybackProvider _provider;
  final Map<String, MiniProgramMediaPlaybackSession> _sessions =
      <String, MiniProgramMediaPlaybackSession>{};
  final Map<String, _PendingMediaPlaybackLoad> _pending =
      <String, _PendingMediaPlaybackLoad>{};
  final Map<String, int> _generations = <String, int>{};
  bool _disposed = false;

  String _key(String appId, String playerId) => '$appId\u0000$playerId';

  MiniProgramMediaPlaybackSession? sessionFor(String appId, String playerId) =>
      _sessions[_key(appId, playerId)];

  Future<MiniProgramMediaPlaybackSession> load(
    MiniProgramMediaPlaybackRequest request,
  ) async {
    if (_disposed) {
      throw const MiniProgramMediaPlaybackException(
        errorCode: MiniProgramErrorCodes.mediaProviderUnavailable,
        message: 'The media playback manager has been disposed.',
      );
    }
    final key = _key(request.miniProgramId, request.playerId);
    final existing = _sessions[key];
    if (existing != null && existing.sourceKey == request.sourceKey) {
      if (request.autoplay) await existing.play();
      return existing;
    }
    final pending = _pending[key];
    if (pending != null) {
      if (pending.sourceKey == request.sourceKey) return pending.future;
      throw const MiniProgramMediaPlaybackException(
        errorCode: MiniProgramErrorCodes.mediaRequestInProgress,
        message: 'Another media source is loading for this player.',
      );
    }
    final generation = (_generations[key] ?? 0) + 1;
    _generations[key] = generation;
    _sessions.remove(key);
    final future = _replaceSession(key, existing, request, generation);
    _pending[key] = _PendingMediaPlaybackLoad(
      sourceKey: request.sourceKey,
      future: future,
    );
    try {
      return await future;
    } finally {
      if (identical(_pending[key]?.future, future)) {
        _pending.remove(key);
      }
    }
  }

  Future<MiniProgramMediaPlaybackSession> _replaceSession(
    String key,
    MiniProgramMediaPlaybackSession? existing,
    MiniProgramMediaPlaybackRequest request,
    int generation,
  ) async {
    await existing?.dispose();
    final session = await _provider.createSession(request);
    if (_disposed || _generations[key] != generation) {
      await session.dispose();
      throw const MiniProgramMediaPlaybackException(
        errorCode: MiniProgramErrorCodes.mediaSourceExpired,
        message: 'The media playback request is no longer active.',
      );
    }
    _sessions[key] = session;
    return session;
  }

  Future<bool> release(String appId, String playerId) async {
    final key = _key(appId, playerId);
    _generations[key] = (_generations[key] ?? 0) + 1;
    final hadPending = _pending.containsKey(key);
    final session = _sessions.remove(key);
    if (session == null) return hadPending;
    await session.dispose();
    return true;
  }

  Future<void> releaseAllFor(String appId) async {
    final prefix = '$appId\u0000';
    final keys = <String>{
      ..._sessions.keys.where((key) => key.startsWith(prefix)),
      ..._pending.keys.where((key) => key.startsWith(prefix)),
    };
    for (final key in keys) {
      _generations[key] = (_generations[key] ?? 0) + 1;
      await _sessions.remove(key)?.dispose();
    }
  }

  /// Pauses all active foreground sessions owned by [appId].
  Future<void> pauseAllFor(String appId) async {
    final prefix = '$appId\u0000';
    final sessions = _sessions.entries
        .where((entry) => entry.key.startsWith(prefix))
        .map((entry) => entry.value)
        .toList(growable: false);
    for (final session in sessions) {
      await session.pause();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final key in _pending.keys) {
      _generations[key] = (_generations[key] ?? 0) + 1;
    }
    final sessions = _sessions.values.toList(growable: false);
    _sessions.clear();
    for (final session in sessions) {
      await session.dispose();
    }
  }
}

final class _PendingMediaPlaybackLoad {
  const _PendingMediaPlaybackLoad({
    required this.sourceKey,
    required this.future,
  });

  final String sourceKey;
  final Future<MiniProgramMediaPlaybackSession> future;
}
