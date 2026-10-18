import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../media/mini_program_media.dart';

/// Host-accepted foreground voice recording limits. Disabled by default.
@immutable
class MiniProgramMicrophonePolicy {
  const MiniProgramMicrophonePolicy({
    this.enabled = false,
    this.maxDurationSeconds = 60,
    this.maxBytes = 20 * 1024 * 1024,
  });

  final bool enabled;
  final int maxDurationSeconds;
  final int maxBytes;

  @override
  bool operator ==(Object other) =>
      other is MiniProgramMicrophonePolicy &&
      enabled == other.enabled &&
      maxDurationSeconds == other.maxDurationSeconds &&
      maxBytes == other.maxBytes;
  @override
  int get hashCode => Object.hash(enabled, maxDurationSeconds, maxBytes);
}

abstract interface class MiniProgramMicrophonePolicyProvider {
  MiniProgramMicrophonePolicy microphonePolicyFor(String miniProgramId);
}

@immutable
class MiniProgramMicrophoneRequest {
  const MiniProgramMicrophoneRequest({
    required this.recordingId,
    required this.miniProgramId,
    required this.maxDurationSeconds,
    required this.maxBytes,
  });
  final String recordingId;
  final String miniProgramId;
  final int maxDurationSeconds;
  final int maxBytes;
}

/// A trusted provider owns permission UI, foreground capture, and native media.
abstract interface class MiniProgramMicrophoneProvider
    implements MiniProgramMediaProvider {
  /// Completes when stopped or a native limit is reached. [onStarted] runs only
  /// once capture begins, after permission is granted.
  Future<MiniProgramMicrophoneResult> record(
    MiniProgramMicrophoneRequest request, {
    required VoidCallback onStarted,
  });
  Future<bool> stop(String recordingId, {bool background = false});
  Future<bool> cancel(String recordingId);
}

class MiniProgramMicrophoneException implements Exception {
  const MiniProgramMicrophoneException({
    required this.errorCode,
    required this.message,
  });
  final String errorCode;
  final String message;
  @override
  String toString() => message;
}

/// Owns one pending recording and validates app-owned completed audio references.
class MiniProgramMicrophoneManager {
  MiniProgramMicrophoneManager(this.provider, {required this.mediaManager});
  final MiniProgramMicrophoneProvider provider;
  final MiniProgramMediaManager mediaManager;
  final Map<String, String> _owners = {};
  _MicrophoneOperation? _active;
  bool _disposed = false;
  int _sequence = 0;

  Future<MiniProgramMicrophoneResult> record({
    required String miniProgramId,
    required MiniProgramMicrophonePolicy policy,
    int maxDurationSeconds = 60,
    VoidCallback? onStarted,
  }) async {
    if (_disposed) throw StateError('Microphone manager is disposed.');
    if (!policy.enabled) {
      throw const MiniProgramMicrophoneException(
        errorCode: MiniProgramErrorCodes.microphoneNotAccepted,
        message: 'Microphone recording is not accepted by host policy.',
      );
    }
    if (maxDurationSeconds < 1 ||
        maxDurationSeconds > 600 ||
        policy.maxDurationSeconds < 1 ||
        policy.maxDurationSeconds > 600 ||
        policy.maxBytes < 1 ||
        policy.maxBytes > 100 * 1024 * 1024) {
      throw const MiniProgramMicrophoneException(
        errorCode: MiniProgramErrorCodes.microphoneInvalidRequest,
        message: 'The recording request or accepted limits are invalid.',
      );
    }
    if (_active != null) {
      throw const MiniProgramMicrophoneException(
        errorCode: MiniProgramErrorCodes.microphoneRequestInProgress,
        message: 'A microphone recording is already in progress.',
      );
    }
    final operation = _MicrophoneOperation(
      'recording_${DateTime.now().microsecondsSinceEpoch}_${++_sequence}',
      miniProgramId,
    );
    _active = operation;
    final duration = math.min(maxDurationSeconds, policy.maxDurationSeconds);
    MiniProgramMicrophoneResult? result;
    bool registered = false;
    Object? callbackError;
    try {
      result = await provider.record(
        MiniProgramMicrophoneRequest(
          recordingId: operation.id,
          miniProgramId: miniProgramId,
          maxDurationSeconds: duration,
          maxBytes: policy.maxBytes,
        ),
        onStarted: () {
          if (_disposed ||
              operation.cancelled ||
              !identical(_active, operation) ||
              operation.started) {
            return;
          }
          operation.started = true;
          try {
            onStarted?.call();
          } on Object catch (error) {
            callbackError = error;
            unawaited(cancelFor(miniProgramId));
          }
        },
      );
      if (operation.cancelled || _disposed) {
        throw const MiniProgramMicrophoneException(
          errorCode: MiniProgramErrorCodes.microphoneRecordingCancelled,
          message: 'Microphone recording was cancelled.',
        );
      }
      result.validate();
      if (result.recordingId != operation.id ||
          mediaManager.isRegistered(result.mediaRef)) {
        throw const MiniProgramMicrophoneException(
          errorCode: MiniProgramErrorCodes.microphoneInvalidResult,
          message: 'The host returned an invalid recording reference.',
        );
      }
      // Native encoders may finalize a frame just beyond the timer boundary.
      if (result.bytes > policy.maxBytes ||
          result.durationMs > duration * 1000 + 1000) {
        throw const MiniProgramMicrophoneException(
          errorCode: MiniProgramErrorCodes.microphoneLimitExceeded,
          message: 'The recording exceeds accepted host limits.',
        );
      }
      mediaManager.register(
        miniProgramId: miniProgramId,
        mediaRef: result.mediaRef,
      );
      registered = true;
      _owners[result.mediaRef] = miniProgramId;
      return result;
    } catch (error) {
      if (result != null) {
        if (registered) {
          await releaseRecording(miniProgramId, result);
        } else if (!mediaManager.isRegistered(result.mediaRef)) {
          await _releaseNative(miniProgramId, result.mediaRef);
        }
      }
      if (callbackError != null) throw callbackError!;
      if (error is FormatException || error is MiniProgramMediaException) {
        throw const MiniProgramMicrophoneException(
          errorCode: MiniProgramErrorCodes.microphoneInvalidResult,
          message: 'The host returned invalid recording metadata.',
        );
      }
      rethrow;
    } finally {
      if (identical(_active, operation)) _active = null;
    }
  }

  Future<bool> stopFor(String miniProgramId, {bool background = false}) async {
    final operation = _active;
    if (operation == null || operation.appId != miniProgramId) return false;
    return provider.stop(operation.id, background: background);
  }

  Future<bool> cancelFor(String miniProgramId) async {
    final operation = _active;
    if (operation == null || operation.appId != miniProgramId) return false;
    operation.cancelled = true;
    try {
      await provider.cancel(operation.id);
    } on Object {
      /* Logical cancellation applies. */
    }
    return true;
  }

  Future<void> releaseRecording(
    String appId,
    MiniProgramMicrophoneResult result,
  ) async {
    if (_owners[result.mediaRef] != appId) return;
    _owners.remove(result.mediaRef);
    if (mediaManager.owns(appId, result.mediaRef)) {
      try {
        await mediaManager.release(
          miniProgramId: appId,
          mediaRef: result.mediaRef,
        );
      } on Object {
        /* Best-effort cleanup. */
      }
    }
  }

  Future<void> releaseAllFor(String appId) async {
    await cancelFor(appId);
    final refs = _owners.entries
        .where((entry) => entry.value == appId)
        .map((entry) => entry.key)
        .toList();
    for (final ref in refs) {
      _owners.remove(ref);
      if (mediaManager.owns(appId, ref)) {
        try {
          await mediaManager.release(miniProgramId: appId, mediaRef: ref);
        } on Object {
          /* Best effort. */
        }
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final appId in {
      ..._owners.values,
      if (_active != null) _active!.appId,
    }) {
      await releaseAllFor(appId);
    }
  }

  Future<void> _releaseNative(String appId, String ref) async {
    try {
      await provider.releaseMedia(
        MiniProgramMediaReleaseRequest(miniProgramId: appId, mediaRef: ref),
      );
    } on Object {
      /* Never release a reference owned by another mini-program. */
    }
  }
}

class _MicrophoneOperation {
  _MicrophoneOperation(this.id, this.appId);
  final String id;
  final String appId;
  bool cancelled = false;
  bool started = false;
}
