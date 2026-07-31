part of '../../mp_screen_renderer.dart';

abstract final class _MpFileActionHandler {
  static const Duration _progressInterval = Duration(milliseconds: 150);
  static const int _maxProviderDataBytes = 1024 * 1024;
  static final RegExp _invalidFileNameCharacters = RegExp(
    r'[/\\\x00-\x1F\x7F]',
  );
  static final RegExp _mimeToken = RegExp(r'^[a-z0-9!#$&^_.+-]+$');

  static Future<HostActionResult> _upload(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) => _runTransfer(
    scope: scope,
    props: props,
    actionName: ActionNames.fileUpload,
    direction: MiniProgramFileTransferDirection.upload,
  );

  static Future<HostActionResult> _download(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) => _runTransfer(
    scope: scope,
    props: props,
    actionName: ActionNames.fileDownload,
    direction: MiniProgramFileTransferDirection.download,
  );

  static Future<HostActionResult> _runTransfer({
    required MiniProgramSdkScope scope,
    required Map<String, dynamic> props,
    required String actionName,
    required MiniProgramFileTransferDirection direction,
  }) async {
    final requestId = _optionalStringProp(props, 'requestId');
    final state = scope.stateManager;
    if (state == null) {
      return _MpStateActionHandler._stateUnavailable(
        actionName,
        requestId: requestId,
      );
    }

    final policy = scope.filePolicy;
    final accepted =
        policy.enabled &&
        (direction == MiniProgramFileTransferDirection.upload
            ? policy.allowUpload
            : policy.allowDownload);
    if (!accepted) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.fileNotAccepted,
        message: direction == MiniProgramFileTransferDirection.upload
            ? 'File uploads are not accepted by host policy for this mini-program.'
            : 'File downloads are not accepted by host policy for this mini-program.',
      );
    }

    final manager = scope.fileTransferManager;
    final connector = scope.backendConnector;
    if (manager == null || connector is! MiniProgramBackendTransferResolver) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.fileTransferUnavailable,
        message:
            'The host does not provide Publisher API file transfers on this platform.',
      );
    }
    final transferResolver = connector as MiniProgramBackendTransferResolver;
    if (manager.activeCountFor(scope.miniProgramId) >=
        policy.maxConcurrentTransfers) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.fileTransferLimitExceeded,
        message: 'The accepted concurrent file transfer limit was reached.',
        data: <String, dynamic>{
          'maxConcurrentTransfers': policy.maxConcurrentTransfers,
        },
      );
    }

    final transferId = manager.createTransferId(scope.miniProgramId);
    final queued = MiniProgramFileTransferProgress(
      transferId: transferId,
      direction: direction,
      status: MiniProgramFileTransferStatus.queued,
      bytesTransferred: 0,
    );
    try {
      state.batchUpdates(() {
        state.set(_stringProp(props, 'progressState'), queued.toJson());
        _setStatus(state, props, 'loading');
        _clearError(state, props);
      });
    } on MiniProgramStateLimitException catch (error) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.stateLimitExceeded,
        message: error.toString(),
        data: error.details,
      );
    }

    final progress = _FileProgressWriter(
      state: state,
      key: _stringProp(props, 'progressState'),
      transferId: transferId,
      direction: direction,
      maxFileBytes: direction == MiniProgramFileTransferDirection.download
          ? policy.maxFileBytes
          : null,
      interval: _progressInterval,
    );
    try {
      var backendRequest = MiniProgramBackendRequest(
        miniProgramId: scope.miniProgramId,
        endpoint: _stringProp(props, 'endpoint'),
        requestId: requestId,
        method: direction == MiniProgramFileTransferDirection.upload
            ? 'POST'
            : _stringProp(props, 'method'),
        body: direction == MiniProgramFileTransferDirection.upload
            ? _mapProp(props, 'metadata')
            : _mapProp(props, 'request'),
      );
      backendRequest = await _authorize(scope, backendRequest);
      final backend = transferResolver.resolveTransfer(backendRequest);
      final downloadDestination =
          direction == MiniProgramFileTransferDirection.download
          ? _downloadDestination(props, policy)
          : null;
      final expectedDownloadMimeType =
          direction == MiniProgramFileTransferDirection.download
          ? _acceptedDownloadMimeType(props, policy)
          : null;

      final result = direction == MiniProgramFileTransferDirection.upload
          ? await manager.upload(
              MiniProgramFileUploadRequest(
                transferId: transferId,
                miniProgramId: scope.miniProgramId,
                backend: backend,
                mimeTypes: _acceptedUploadMimeTypes(props, policy),
                multiple: _boolProp(props, 'multiple'),
                maxFiles: _boolProp(props, 'multiple')
                    ? policy.maxFilesPerUpload
                    : 1,
                fieldName: _stringProp(props, 'fieldName'),
                metadata: _mapProp(props, 'metadata'),
                maxFileBytes: policy.maxFileBytes,
                minimumFreeBytes: policy.minimumFreeBytes,
                maxConcurrentTransfers: policy.maxConcurrentTransfers,
              ),
              onProgress: progress.add,
            )
          : await manager.download(
              MiniProgramFileDownloadRequest(
                transferId: transferId,
                miniProgramId: scope.miniProgramId,
                backend: backend,
                request: _mapProp(props, 'request'),
                destination: downloadDestination!,
                suggestedName: _optionalStringProp(props, 'suggestedName'),
                expectedMimeType: expectedDownloadMimeType,
                maxFileBytes: policy.maxFileBytes,
                minimumFreeBytes: policy.minimumFreeBytes,
                maxConcurrentTransfers: policy.maxConcurrentTransfers,
              ),
              onProgress: progress.add,
            );
      progress.flush();
      _validateResult(
        result: result,
        transferId: transferId,
        direction: direction,
        policy: policy,
        expectedDestination: downloadDestination,
        expectedMimeType: expectedDownloadMimeType,
      );
      final data = result.toJson();
      state.batchUpdates(() {
        state.set(_stringProp(props, 'targetState'), data);
        state.set(
          _stringProp(props, 'progressState'),
          MiniProgramFileTransferProgress(
            transferId: transferId,
            direction: direction,
            status: MiniProgramFileTransferStatus.completed,
            bytesTransferred: result.bytesTransferred,
            totalBytes: result.bytesTransferred,
            fileName: result.fileName,
          ).toJson(),
        );
        _setStatus(state, props, 'success');
        _clearError(state, props);
      });
      return HostActionResult.success(
        requestId: requestId,
        actionName: actionName,
        data: data,
      );
    } on MiniProgramStateLimitException catch (error) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.stateLimitExceeded,
        message: error.toString(),
        data: error.details,
      );
    } on MiniProgramFileException catch (error) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: error.errorCode,
        message: error.message,
        data: Map<String, dynamic>.from(error.details),
      );
    } on MiniProgramBackendTransferResolutionException catch (error) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.fileTransferUnavailable,
        message: error.message,
        data: <String, dynamic>{'backendErrorCode': error.errorCode},
      );
    } on TimeoutException {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: _operationFailureCode(direction),
        message: 'The file transfer timed out.',
      );
    } catch (error, stackTrace) {
      scope.logger.error(
        'Publisher file transfer failed.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'miniProgramId': scope.miniProgramId,
          'direction': direction.wireValue,
        },
      );
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: _operationFailureCode(direction),
        message: direction == MiniProgramFileTransferDirection.upload
            ? 'The file upload failed.'
            : 'The file download failed.',
      );
    } finally {
      progress.dispose();
    }
  }

  static Future<HostActionResult> _cancel(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = ActionNames.fileCancel;
    final requestId = _optionalStringProp(props, 'requestId');
    final state = scope.stateManager;
    if (state == null) {
      return _MpStateActionHandler._stateUnavailable(
        actionName,
        requestId: requestId,
      );
    }
    if (!scope.filePolicy.enabled) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.fileNotAccepted,
        message: 'File transfers are not accepted by host policy.',
      );
    }
    final manager = scope.fileTransferManager;
    if (manager == null) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.fileTransferUnavailable,
        message: 'The host does not provide file transfer cancellation.',
      );
    }
    final transferId = _stringProp(props, 'transferId');
    try {
      final cancelled = await manager.cancel(scope.miniProgramId, transferId);
      if (!cancelled) {
        return _failure(
          state: state,
          props: props,
          actionName: actionName,
          requestId: requestId,
          code: MiniProgramErrorCodes.fileTransferNotFound,
          message: 'The active file transfer was not found.',
        );
      }
      state.batchUpdates(() {
        _setStatus(state, props, 'cancelled');
        _clearError(state, props);
      });
      return HostActionResult.success(
        requestId: requestId,
        actionName: actionName,
        data: <String, dynamic>{
          'transferId': transferId,
          'status': 'cancelled',
        },
      );
    } on MiniProgramFileException catch (error) {
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: error.errorCode,
        message: error.message,
        data: Map<String, dynamic>.from(error.details),
      );
    } catch (error, stackTrace) {
      scope.logger.error(
        'File transfer cancellation failed.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'miniProgramId': scope.miniProgramId},
      );
      return _failure(
        state: state,
        props: props,
        actionName: actionName,
        requestId: requestId,
        code: MiniProgramErrorCodes.fileTransferUnavailable,
        message: 'The file transfer could not be cancelled.',
      );
    }
  }

  static List<String> _acceptedUploadMimeTypes(
    Map<String, dynamic> props,
    MiniProgramFilePolicy policy,
  ) {
    final requested = List<String>.from(props['mimeTypes'] as List);
    if (requested.contains('*/*')) {
      return policy.allowedMimeTypes.toList(growable: false)..sort();
    }
    final accepted = requested.where(policy.acceptsMimeType).toList();
    if (accepted.length != requested.length) {
      throw const MiniProgramFileException(
        errorCode: MiniProgramErrorCodes.fileTypeNotAccepted,
        message:
            'One or more requested file types are not accepted by host policy.',
      );
    }
    return accepted;
  }

  static String? _acceptedDownloadMimeType(
    Map<String, dynamic> props,
    MiniProgramFilePolicy policy,
  ) {
    final expected = _optionalStringProp(props, 'expectedMimeType');
    if (expected != null && !policy.acceptsMimeType(expected)) {
      throw const MiniProgramFileException(
        errorCode: MiniProgramErrorCodes.fileTypeNotAccepted,
        message: 'The expected download type is not accepted by host policy.',
      );
    }
    return expected;
  }

  static MiniProgramFileDownloadDestination _downloadDestination(
    Map<String, dynamic> props,
    MiniProgramFilePolicy policy,
  ) {
    final destination = switch (_stringProp(props, 'destination')) {
      'downloads' => MiniProgramFileDownloadDestination.downloads,
      'choose' => MiniProgramFileDownloadDestination.choose,
      'temporary' => MiniProgramFileDownloadDestination.temporary,
      _ => throw const MiniProgramFileException(
        errorCode: MiniProgramErrorCodes.fileNotAccepted,
        message: 'The download destination is unsupported.',
      ),
    };
    if (!policy.allowedDestinations.contains(destination)) {
      throw const MiniProgramFileException(
        errorCode: MiniProgramErrorCodes.fileNotAccepted,
        message: 'The download destination is not accepted by host policy.',
      );
    }
    return destination;
  }

  static void _validateResult({
    required MiniProgramFileTransferResult result,
    required String transferId,
    required MiniProgramFileTransferDirection direction,
    required MiniProgramFilePolicy policy,
    required MiniProgramFileDownloadDestination? expectedDestination,
    required String? expectedMimeType,
  }) {
    final fileName = result.fileName;
    final mimeType = result.mimeType?.trim().toLowerCase();
    final invalidFileName =
        fileName != null &&
        (fileName.trim().isEmpty ||
            fileName.length > 255 ||
            _invalidFileNameCharacters.hasMatch(fileName));
    final invalidMimeType =
        (direction == MiniProgramFileTransferDirection.download &&
            mimeType == null) ||
        (mimeType != null &&
            (!_isMimeType(mimeType) ||
                !policy.acceptsMimeType(mimeType) ||
                (expectedMimeType != null &&
                    !_mimeMatches(expectedMimeType, mimeType))));
    final missingDownloadName =
        direction == MiniProgramFileTransferDirection.download &&
        fileName == null;
    final invalidDestination =
        direction == MiniProgramFileTransferDirection.upload
        ? result.destination != null
        : result.destination != expectedDestination?.name;
    var invalidData = false;
    try {
      invalidData =
          utf8.encode(jsonEncode(result.data)).length > _maxProviderDataBytes;
    } on Object {
      invalidData = true;
    }
    if (result.transferId != transferId ||
        result.direction != direction ||
        result.statusCode < 200 ||
        result.statusCode >= 300 ||
        result.bytesTransferred < 0 ||
        (direction == MiniProgramFileTransferDirection.download &&
            policy.maxFileBytes != null &&
            result.bytesTransferred > policy.maxFileBytes!) ||
        invalidFileName ||
        missingDownloadName ||
        invalidMimeType ||
        invalidDestination ||
        invalidData) {
      throw const MiniProgramFileException(
        errorCode: MiniProgramErrorCodes.fileInvalidResult,
        message: 'The host file provider returned an invalid result.',
      );
    }
  }

  static bool _isMimeType(String value) {
    if (value == '*/*') {
      return true;
    }
    final parts = value.split('/');
    return parts.length == 2 &&
        _mimeToken.hasMatch(parts.first) &&
        (parts.last == '*' || _mimeToken.hasMatch(parts.last));
  }

  static bool _mimeMatches(String expected, String actual) {
    final normalizedExpected = expected.trim().toLowerCase();
    final normalizedActual = actual.trim().toLowerCase();
    if (normalizedExpected == '*/*' || normalizedExpected == normalizedActual) {
      return true;
    }
    return normalizedExpected.endsWith('/*') &&
        normalizedActual.startsWith(
          normalizedExpected.substring(0, normalizedExpected.length - 1),
        );
  }

  static String _operationFailureCode(
    MiniProgramFileTransferDirection direction,
  ) => direction == MiniProgramFileTransferDirection.upload
      ? MiniProgramErrorCodes.fileUploadFailed
      : MiniProgramErrorCodes.fileDownloadFailed;

  static HostActionResult _failure({
    required MpStateManager state,
    required Map<String, dynamic> props,
    required String actionName,
    required String? requestId,
    required String code,
    required String message,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) {
    try {
      state.batchUpdates(() {
        _setStatus(
          state,
          props,
          code == MiniProgramErrorCodes.fileTransferCancelled
              ? 'cancelled'
              : 'error',
        );
        final errorState = _optionalStringProp(props, 'errorState');
        if (errorState != null) {
          state.set(errorState, <String, dynamic>{
            'action': actionName,
            'code': code,
            'message': message,
          });
        }
      });
    } on MiniProgramStateLimitException {
      // Preserve the transfer failure when error reporting exceeds state quota.
    }
    return HostActionResult.failed(
      requestId: requestId,
      actionName: actionName,
      message: message,
      errorCode: code,
      data: data,
    );
  }

  static void _setStatus(
    MpStateManager state,
    Map<String, dynamic> props,
    String value,
  ) {
    final key = _optionalStringProp(props, 'statusState');
    if (key != null) {
      state.set(key, value);
    }
  }

  static void _clearError(MpStateManager state, Map<String, dynamic> props) {
    final key = _optionalStringProp(props, 'errorState');
    if (key != null) {
      state.remove(key);
    }
  }
}

final class _FileProgressWriter {
  _FileProgressWriter({
    required this.state,
    required this.key,
    required this.transferId,
    required this.direction,
    required this.maxFileBytes,
    required this.interval,
  });

  final MpStateManager state;
  final String key;
  final String transferId;
  final MiniProgramFileTransferDirection direction;
  final int? maxFileBytes;
  final Duration interval;

  MiniProgramFileTransferProgress? _pending;
  Timer? _timer;
  Object? _pendingError;
  bool _disposed = false;

  void add(MiniProgramFileTransferProgress value) {
    if (_disposed) {
      return;
    }
    if (value.transferId != transferId ||
        value.direction != direction ||
        (maxFileBytes != null && value.bytesTransferred > maxFileBytes!)) {
      _pendingError ??= const MiniProgramFileException(
        errorCode: MiniProgramErrorCodes.fileInvalidResult,
        message: 'The host file provider returned invalid progress.',
      );
      return;
    }
    _pending = value;
    _timer ??= Timer(interval, _writePending);
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    _writePending();
    final error = _pendingError;
    if (error != null) {
      Error.throwWithStackTrace(error, StackTrace.current);
    }
  }

  void _writePending() {
    if (_disposed) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    final value = _pending;
    _pending = null;
    if (value != null) {
      try {
        state.set(key, value.toJson());
      } catch (error) {
        _pendingError ??= error;
      }
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _pendingError = null;
  }
}
