part of '../../mp_screen_renderer.dart';

abstract final class _MpDataActionHandler {
  static Future<HostActionResult> _loadJsonDataAsset(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = 'data.loadJsonAsset';
    final requestId = _optionalStringProp(props, 'requestId');
    final manager = scope.dataResourceManager;
    final version = scope.miniProgramVersion;
    if (manager == null || version == null) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: actionName,
        message: 'Artifact-local JSON data is unavailable in this runtime.',
        errorCode: MiniProgramErrorCodes.dataAssetUnavailable,
      );
    }
    final state = scope.stateManager;
    if (state == null &&
        (props.containsKey('statusState') || props.containsKey('errorState'))) {
      return _MpStateActionHandler._stateUnavailable(actionName);
    }
    _writeDataStatus(state, props, 'loading');
    try {
      final loaded = await manager.load(
        appId: scope.miniProgramId,
        version: version,
        resourceId: _stringProp(props, 'id'),
        assetPath: _stringProp(props, 'asset'),
        ttl: Duration(milliseconds: _intProp(props, 'ttlMs', fallback: 1)),
        forceRefresh: _boolProp(props, 'forceRefresh'),
        source: scope.jsonAssetSource,
        cacheManager: scope.cacheManager,
        cachePolicy: scope.cachePolicy,
      );
      if (state != null) {
        state.batchUpdates(() {
          _writeDataStatus(state, props, 'success');
          _clearDataError(state, props);
        });
      }
      return HostActionResult.success(
        requestId: requestId,
        actionName: actionName,
        data: loaded.toJson(),
      );
    } on MiniProgramStateLimitException catch (error) {
      _writeDataFailure(
        state,
        props,
        actionName,
        MiniProgramErrorCodes.stateLimitExceeded,
        error.toString(),
      );
      return HostActionResult.failed(
        requestId: requestId,
        actionName: actionName,
        message: error.toString(),
        errorCode: MiniProgramErrorCodes.stateLimitExceeded,
        data: error.details,
      );
    } on MiniProgramDataException catch (error) {
      _writeDataFailure(state, props, actionName, error.code, error.message);
      return HostActionResult.failed(
        requestId: requestId,
        actionName: actionName,
        message: error.message,
        errorCode: error.code,
        data: error.details,
      );
    } on MiniProgramSourceException catch (error) {
      final code =
          error.errorCode ?? MiniProgramErrorCodes.dataAssetUnavailable;
      _writeDataFailure(state, props, actionName, code, error.message);
      return HostActionResult.failed(
        requestId: requestId,
        actionName: actionName,
        message: error.message,
        errorCode: code,
        data: error.details,
      );
    }
  }

  static Future<HostActionResult> _searchJsonData(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = 'data.search';
    final state = scope.stateManager;
    if (state == null) {
      return _MpStateActionHandler._stateUnavailable(actionName);
    }
    final manager = scope.dataResourceManager;
    final version = scope.miniProgramVersion;
    if (manager == null || version == null) {
      return HostActionResult.failed(
        actionName: actionName,
        message: 'Artifact-local JSON data is unavailable in this runtime.',
        errorCode: MiniProgramErrorCodes.dataAssetUnavailable,
      );
    }
    _writeDataStatus(state, props, 'loading');
    try {
      final query = props['query'] as String;
      final minQueryLength = _intProp(props, 'minQueryLength', fallback: 2);
      final result = await manager.search(
        appId: scope.miniProgramId,
        version: version,
        resourceId: _stringProp(props, 'resourceId'),
        query: query,
        fields: List<String>.from(props['fields'] as List),
        itemsPath: _optionalStringProp(props, 'itemsPath'),
        minQueryLength: minQueryLength,
        limit: _intProp(props, 'limit', fallback: 20),
        targetState: _stringProp(props, 'targetState'),
      );
      if (result == null) {
        return HostActionResult.success(
          actionName: actionName,
          data: const <String, dynamic>{'stale': true},
        );
      }
      final status =
          query.trim().isEmpty || query.trim().length < minQueryLength
          ? 'idle'
          : (result['matchCount'] as int) == 0
          ? 'empty'
          : 'success';
      state.batchUpdates(() {
        state.set(_stringProp(props, 'targetState'), result);
        _writeDataStatus(state, props, status);
        _clearDataError(state, props);
      });
      return HostActionResult.success(actionName: actionName, data: result);
    } on MiniProgramStateLimitException catch (error) {
      _writeDataFailure(
        state,
        props,
        actionName,
        MiniProgramErrorCodes.stateLimitExceeded,
        error.toString(),
      );
      return HostActionResult.failed(
        actionName: actionName,
        message: error.toString(),
        errorCode: MiniProgramErrorCodes.stateLimitExceeded,
        data: error.details,
      );
    } on MiniProgramDataException catch (error) {
      _writeDataFailure(state, props, actionName, error.code, error.message);
      return HostActionResult.failed(
        actionName: actionName,
        message: error.message,
        errorCode: error.code,
        data: error.details,
      );
    } catch (error) {
      const message = 'Failed to search the JSON data resource.';
      _writeDataFailure(
        state,
        props,
        actionName,
        MiniProgramErrorCodes.dataSearchFailed,
        message,
      );
      return HostActionResult.failed(
        actionName: actionName,
        message: message,
        errorCode: MiniProgramErrorCodes.dataSearchFailed,
        data: <String, dynamic>{'error': error.toString()},
      );
    }
  }

  static void _writeDataStatus(
    MpStateManager? state,
    Map<String, dynamic> props,
    String value,
  ) {
    final key = _optionalStringProp(props, 'statusState');
    if (state != null && key != null) {
      state.set(key, value);
    }
  }

  static void _clearDataError(
    MpStateManager state,
    Map<String, dynamic> props,
  ) {
    final key = _optionalStringProp(props, 'errorState');
    if (key != null) {
      state.remove(key);
    }
  }

  static void _writeDataFailure(
    MpStateManager? state,
    Map<String, dynamic> props,
    String action,
    String code,
    String message,
  ) {
    if (state == null) {
      return;
    }
    state.batchUpdates(() {
      _writeDataStatus(state, props, 'error');
      final key = _optionalStringProp(props, 'errorState');
      if (key != null) {
        state.set(key, <String, dynamic>{
          'action': action,
          'code': code,
          'message': message,
        });
      }
    });
  }
}
