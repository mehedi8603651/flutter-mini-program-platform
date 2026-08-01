import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../media/mini_program_media.dart';

/// Host authority for delegated still-photo capture.
@immutable
class MiniProgramCameraPolicy {
  const MiniProgramCameraPolicy({
    this.enabled = false,
    this.allowPhotoCapture = false,
  });

  final bool enabled;
  final bool allowPhotoCapture;

  @override
  bool operator ==(Object other) =>
      other is MiniProgramCameraPolicy &&
      enabled == other.enabled &&
      allowPhotoCapture == other.allowPhotoCapture;

  @override
  int get hashCode => Object.hash(enabled, allowPhotoCapture);
}

/// Resolves accepted camera policy for one mini-program endpoint.
abstract interface class MiniProgramCameraPolicyProvider {
  MiniProgramCameraPolicy cameraPolicyFor(String miniProgramId);
}

/// Trusted request passed to a host camera implementation.
@immutable
class MiniProgramCameraCaptureRequest {
  const MiniProgramCameraCaptureRequest({
    required this.captureId,
    required this.miniProgramId,
    required this.quality,
    this.maxWidth,
    this.maxHeight,
  });

  final String captureId;
  final String miniProgramId;
  final int quality;
  final int? maxWidth;
  final int? maxHeight;
}

/// Delegates photo capture to trusted host platform UI.
///
/// Implementations must keep native paths, content URIs, and bytes private.
/// Returned media references remain valid until [release] is called.
abstract interface class MiniProgramCameraProvider {
  Future<MiniProgramCameraPhotoResult> capturePhoto(
    MiniProgramCameraCaptureRequest request,
  );

  Future<bool> cancel(String captureId);

  Future<void> release(String mediaRef);
}

/// Structured camera provider failure mapped to a stable contract error.
class MiniProgramCameraException implements Exception {
  const MiniProgramCameraException({
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

/// Owns camera request identity and temporary media lifetime per app.
class MiniProgramCameraManager {
  MiniProgramCameraManager(this.provider, {this.mediaManager});

  final MiniProgramCameraProvider provider;
  final MiniProgramMediaManager? mediaManager;
  final Map<String, String> _activeByApp = <String, String>{};
  final Set<String> _cancelledCaptureIds = <String>{};
  final Map<String, String> _mediaOwners = <String, String>{};
  int _sequence = 0;
  bool _disposed = false;

  Future<MiniProgramCameraPhotoResult> capturePhoto({
    required String miniProgramId,
    required int quality,
    int? maxWidth,
    int? maxHeight,
  }) async {
    _ensureActive();
    if (_activeByApp.isNotEmpty) {
      throw const MiniProgramCameraException(
        errorCode: MiniProgramErrorCodes.cameraRequestInProgress,
        message: 'A photo capture request is already in progress.',
      );
    }
    _sequence++;
    final captureId =
        'capture_${DateTime.now().microsecondsSinceEpoch}_$_sequence';
    _activeByApp[miniProgramId] = captureId;
    try {
      final result = await provider.capturePhoto(
        MiniProgramCameraCaptureRequest(
          captureId: captureId,
          miniProgramId: miniProgramId,
          quality: quality,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
      );
      if (_cancelledCaptureIds.remove(captureId)) {
        await _releaseBestEffort(result.mediaRef);
        throw const MiniProgramCameraException(
          errorCode: MiniProgramErrorCodes.cameraCaptureCancelled,
          message: 'Photo capture was cancelled.',
        );
      }
      if (result.captureId != captureId ||
          _mediaOwners.containsKey(result.mediaRef) ||
          (mediaManager?.owns(miniProgramId, result.mediaRef) ?? false)) {
        await _releaseBestEffort(result.mediaRef);
        throw const MiniProgramCameraException(
          errorCode: MiniProgramErrorCodes.cameraInvalidResult,
          message: 'The host returned an invalid camera reference.',
        );
      }
      result.validate();
      final sharedMedia = mediaManager;
      if (sharedMedia == null) {
        _mediaOwners[result.mediaRef] = miniProgramId;
      } else {
        try {
          sharedMedia.register(
            miniProgramId: miniProgramId,
            mediaRef: result.mediaRef,
          );
        } on MiniProgramMediaException {
          await _releaseBestEffort(result.mediaRef);
          throw const MiniProgramCameraException(
            errorCode: MiniProgramErrorCodes.cameraInvalidResult,
            message: 'The host returned an invalid camera reference.',
          );
        }
      }
      return result;
    } on FormatException catch (error) {
      throw MiniProgramCameraException(
        errorCode: MiniProgramErrorCodes.cameraInvalidResult,
        message: error.message.toString(),
      );
    } finally {
      _cancelledCaptureIds.remove(captureId);
      if (_activeByApp[miniProgramId] == captureId) {
        _activeByApp.remove(miniProgramId);
      }
    }
  }

  Future<bool> cancelFor(String miniProgramId) async {
    _ensureActive();
    final captureId = _activeByApp[miniProgramId];
    if (captureId == null) {
      return false;
    }
    final cancelled = await provider.cancel(captureId);
    if (cancelled) {
      _cancelledCaptureIds.add(captureId);
    }
    return cancelled;
  }

  Future<void> releaseAllFor(String miniProgramId) async {
    final captureId = _activeByApp[miniProgramId];
    if (captureId != null) {
      try {
        if (await provider.cancel(captureId)) {
          _cancelledCaptureIds.add(captureId);
        }
      } on Object {
        // Host lifecycle cleanup is best effort.
      }
    }
    final mediaRefs = _mediaOwners.entries
        .where((entry) => entry.value == miniProgramId)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final mediaRef in mediaRefs) {
      _mediaOwners.remove(mediaRef);
      await _releaseBestEffort(mediaRef);
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final appIds = <String>{..._activeByApp.keys, ..._mediaOwners.values};
    for (final appId in appIds) {
      await releaseAllFor(appId);
    }
    _activeByApp.clear();
    _cancelledCaptureIds.clear();
    _mediaOwners.clear();
  }

  Future<void> _releaseBestEffort(String mediaRef) async {
    try {
      await provider.release(mediaRef);
    } on Object {
      // Temporary host media cleanup must not leak provider exceptions.
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('MiniProgramCameraManager is disposed.');
    }
  }
}
