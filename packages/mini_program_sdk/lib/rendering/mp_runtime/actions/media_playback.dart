part of '../../mp_screen_renderer.dart';

abstract final class _MpMediaPlaybackActionHandler {
  static Future<HostActionResult> _run(
    MiniProgramSdkScope scope,
    String actionName,
    Map<String, dynamic> props,
  ) async {
    final requestId = _optionalStringProp(props, 'requestId');
    final playerId = _stringProp(props, 'playerId');
    final kind = actionName.startsWith('audio.')
        ? MiniProgramMediaPlaybackKind.audio
        : MiniProgramMediaPlaybackKind.video;
    if (!scope.mediaPlaybackPolicy.allows(kind)) {
      return _failure(
        scope,
        props,
        actionName,
        requestId,
        MiniProgramErrorCodes.mediaNotAccepted,
        '${kind.wireName} playback is not accepted by host policy.',
      );
    }
    final manager = scope.mediaPlaybackManager;
    if (manager == null) {
      return _failure(
        scope,
        props,
        actionName,
        requestId,
        MiniProgramErrorCodes.mediaProviderUnavailable,
        'The host does not provide media playback on this platform.',
      );
    }
    try {
      MiniProgramMediaPlaybackSession? session;
      Map<String, dynamic>? releasedSnapshot;
      if (actionName == ActionNames.audioPlay ||
          actionName == ActionNames.audioPreload) {
        _setMediaStatus(scope, props, 'loading');
        session = await _loadMediaSession(
          scope,
          playerId: playerId,
          kind: kind,
          source: _mapProp(props, 'source'),
          cacheMode: _mediaCacheModeFromName(_stringProp(props, 'cacheMode')),
          autoplay: actionName == ActionNames.audioPlay,
          loop: _boolProp(props, 'loop'),
          volume: _numProp(props, 'volume', fallback: 1).toDouble(),
          speed: 1,
          muted: false,
        );
      } else {
        session = manager.sessionFor(scope.miniProgramId, playerId);
        if (session == null) {
          throw const MiniProgramMediaPlaybackException(
            errorCode: MiniProgramErrorCodes.mediaPlayerNotFound,
            message: 'The requested media player is not loaded.',
          );
        }
        if (actionName == ActionNames.audioRelease ||
            actionName == ActionNames.videoRelease) {
          releasedSnapshot = session.snapshot.toJson();
          await manager.release(scope.miniProgramId, playerId);
        } else {
          await switch (actionName) {
            ActionNames.audioPause || ActionNames.videoPause => session.pause(),
            ActionNames.audioSeek || ActionNames.videoSeek => session.seek(
              Duration(
                milliseconds: _intProp(props, 'positionMs', fallback: 0),
              ),
            ),
            ActionNames.audioStop || ActionNames.videoStop => session.stop(),
            ActionNames.videoPlay => session.play(),
            ActionNames.videoSetMuted => session.setMuted(
              _boolProp(props, 'muted'),
            ),
            ActionNames.videoSetVolume => session.setVolume(
              _numProp(props, 'volume', fallback: 1).toDouble(),
            ),
            ActionNames.videoSetSpeed => session.setSpeed(
              _numProp(props, 'speed', fallback: 1).toDouble(),
            ),
            ActionNames.audioGetStatus ||
            ActionNames.videoGetStatus => Future<void>.value(),
            _ => throw const MiniProgramMediaPlaybackException(
              errorCode: MiniProgramErrorCodes.mediaPlaybackFailed,
              message: 'Unsupported media playback operation.',
            ),
          };
        }
      }
      final snapshot = releasedSnapshot ?? session.snapshot.toJson();
      final state = scope.stateManager;
      if (state != null) {
        state.batchUpdates(() {
          final target = _optionalStringProp(props, 'targetState');
          if (target != null) state.set(target, snapshot);
          _setMediaStatus(scope, props, 'success');
          final errorState = _optionalStringProp(props, 'errorState');
          if (errorState != null) state.remove(errorState);
        });
      }
      return HostActionResult.success(
        requestId: requestId,
        actionName: actionName,
        data: snapshot,
      );
    } on MiniProgramMediaPlaybackException catch (error) {
      return _failure(
        scope,
        props,
        actionName,
        requestId,
        error.errorCode,
        error.message,
        data: Map<String, dynamic>.from(error.details),
      );
    } on MiniProgramBackendTransferResolutionException catch (error) {
      return _failure(
        scope,
        props,
        actionName,
        requestId,
        error.errorCode,
        error.message,
      );
    } catch (error, stackTrace) {
      scope.logger.error(
        'Media playback operation failed.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'miniProgramId': scope.miniProgramId,
          'playerId': playerId,
          'action': actionName,
        },
      );
      return _failure(
        scope,
        props,
        actionName,
        requestId,
        MiniProgramErrorCodes.mediaPlaybackFailed,
        'The media playback operation failed.',
      );
    }
  }

  static HostActionResult _failure(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
    String actionName,
    String? requestId,
    String code,
    String message, {
    Map<String, dynamic> data = const <String, dynamic>{},
  }) {
    final state = scope.stateManager;
    if (state != null) {
      state.batchUpdates(() {
        _setMediaStatus(scope, props, 'error');
        final errorState = _optionalStringProp(props, 'errorState');
        if (errorState != null) {
          state.set(errorState, <String, dynamic>{
            'action': actionName,
            'code': code,
            'message': message,
          });
        }
      });
    }
    return HostActionResult.failed(
      requestId: requestId,
      actionName: actionName,
      message: message,
      errorCode: code,
      data: data,
    );
  }
}

Future<MiniProgramMediaPlaybackSession> _loadMediaSession(
  MiniProgramSdkScope scope, {
  required String playerId,
  required MiniProgramMediaPlaybackKind kind,
  required Map<String, dynamic> source,
  required MiniProgramMediaCacheMode cacheMode,
  required bool autoplay,
  required bool loop,
  required double volume,
  required double speed,
  required bool muted,
}) async {
  final manager = scope.mediaPlaybackManager;
  if (manager == null) {
    throw const MiniProgramMediaPlaybackException(
      errorCode: MiniProgramErrorCodes.mediaProviderUnavailable,
      message: 'The host does not provide media playback on this platform.',
    );
  }
  if (cacheMode == MiniProgramMediaCacheMode.temporary &&
      !scope.mediaPlaybackPolicy.allowsTemporaryCache(kind)) {
    throw const MiniProgramMediaPlaybackException(
      errorCode: MiniProgramErrorCodes.mediaCacheUnavailable,
      message: 'Temporary media caching is not accepted by host policy.',
    );
  }
  final resolved = await _resolveMediaPlaybackSource(scope, source);
  final bucket = kind == MiniProgramMediaPlaybackKind.audio
      ? MiniProgramCacheBucket.audio
      : MiniProgramCacheBucket.video;
  return manager.load(
    MiniProgramMediaPlaybackRequest(
      miniProgramId: scope.miniProgramId,
      playerId: playerId,
      kind: kind,
      sourceKey: jsonEncode(source),
      source: resolved,
      cacheMode: cacheMode,
      autoplay: autoplay,
      loop: loop,
      volume: volume,
      speed: speed,
      muted: muted,
      maxCacheBytes: cacheMode == MiniProgramMediaCacheMode.temporary
          ? scope.cachePolicy.maxBytesFor(bucket)
          : null,
      cacheTtl: cacheMode == MiniProgramMediaCacheMode.temporary
          ? scope.cachePolicy.ttlFor(bucket)
          : null,
    ),
  );
}

Future<MiniProgramResolvedPlaybackSource> _resolveMediaPlaybackSource(
  MiniProgramSdkScope scope,
  Map<String, dynamic> source,
) async {
  switch (_stringProp(source, 'kind')) {
    case 'asset':
      final assetSource = scope.mediaAssetSource;
      final version = scope.miniProgramVersion;
      if (assetSource == null || version == null) {
        throw const MiniProgramMediaPlaybackException(
          errorCode: MiniProgramErrorCodes.mediaInvalidSource,
          message: 'The active artifact source cannot stream media assets.',
        );
      }
      final resolved = assetSource.resolveMediaAsset(
        miniProgramId: scope.miniProgramId,
        version: version,
        assetPath: _stringProp(source, 'asset'),
      );
      return MiniProgramResolvedPlaybackSource(
        candidateUris: resolved.candidateUris,
        headers: resolved.headers,
        timeout: resolved.timeout,
      );
    case 'publisher':
      final connector = scope.backendConnector;
      if (connector is! MiniProgramBackendTransferResolver) {
        throw const MiniProgramMediaPlaybackException(
          errorCode: MiniProgramErrorCodes.mediaInvalidSource,
          message: 'The accepted Publisher API cannot resolve media streams.',
        );
      }
      final resolver = connector as MiniProgramBackendTransferResolver;
      final endpoint = _publisherMediaEndpoint(
        _stringProp(source, 'endpoint'),
        _mapProp(source, 'parameters'),
      );
      var request = MiniProgramBackendRequest(
        miniProgramId: scope.miniProgramId,
        endpoint: endpoint,
        method: 'GET',
      );
      request = await _authorize(scope, request);
      final resolved = resolver.resolveTransfer(request);
      return MiniProgramResolvedPlaybackSource(
        candidateUris: resolved.candidateUris,
        headers: resolved.headers,
        timeout: resolved.timeout,
      );
  }
  throw const MiniProgramMediaPlaybackException(
    errorCode: MiniProgramErrorCodes.mediaInvalidSource,
    message: 'The media source kind is unsupported.',
  );
}

String _publisherMediaEndpoint(
  String endpoint,
  Map<String, dynamic> parameters,
) {
  if (parameters.isEmpty) return endpoint;
  final uri = Uri.parse(endpoint);
  final query = <String, String>{...uri.queryParameters};
  for (final entry in parameters.entries) {
    final value = entry.value;
    query[entry.key] = value is String || value is num || value is bool
        ? value.toString()
        : jsonEncode(value);
  }
  return uri.replace(queryParameters: query).toString();
}

MiniProgramMediaCacheMode _mediaCacheModeFromName(String value) =>
    value == 'temporary'
    ? MiniProgramMediaCacheMode.temporary
    : MiniProgramMediaCacheMode.streaming;

void _setMediaStatus(
  MiniProgramSdkScope scope,
  Map<String, dynamic> props,
  String value,
) {
  final key = _optionalStringProp(props, 'statusState');
  if (key != null) scope.stateManager?.set(key, value);
}
