import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Maximum bytes returned to the trusted Flutter renderer for one preview.
const int miniProgramMediaMaxPreviewBytes = 16 * 1024 * 1024;

@immutable
class MiniProgramMediaPreviewRequest {
  const MiniProgramMediaPreviewRequest({
    required this.miniProgramId,
    required this.mediaRef,
    this.maxBytes = miniProgramMediaMaxPreviewBytes,
  });

  final String miniProgramId;
  final String mediaRef;
  final int maxBytes;
}

@immutable
class MiniProgramMediaReleaseRequest {
  const MiniProgramMediaReleaseRequest({
    required this.miniProgramId,
    required this.mediaRef,
  });

  final String miniProgramId;
  final String mediaRef;
}

@immutable
class MiniProgramMediaPreviewResult {
  const MiniProgramMediaPreviewResult({
    required this.mediaRef,
    required this.mimeType,
    required this.bytes,
  });

  final String mediaRef;
  final String mimeType;
  final Uint8List bytes;
}

/// Trusted host access to temporary media without exposing native locations.
abstract interface class MiniProgramMediaProvider {
  Future<MiniProgramMediaPreviewResult> loadPreview(
    MiniProgramMediaPreviewRequest request,
  );

  Future<bool> releaseMedia(MiniProgramMediaReleaseRequest request);
}

class MiniProgramMediaException implements Exception {
  const MiniProgramMediaException({
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

/// App-scoped ownership registry and bounded preview cache for opaque media.
class MiniProgramMediaManager {
  MiniProgramMediaManager(this.provider);

  final MiniProgramMediaProvider provider;
  final Map<String, String> _owners = <String, String>{};
  final Map<String, Future<MiniProgramMediaPreviewResult>> _previews =
      <String, Future<MiniProgramMediaPreviewResult>>{};
  bool _disposed = false;

  void register({required String miniProgramId, required String mediaRef}) {
    _ensureActive();
    final normalized = _validReference(mediaRef);
    final owner = _owners[normalized];
    if (owner != null) {
      throw const MiniProgramMediaException(
        errorCode: MiniProgramErrorCodes.mediaInvalidResult,
        message: 'The host returned a duplicate media reference.',
      );
    }
    _owners[normalized] = miniProgramId;
  }

  bool owns(String miniProgramId, String mediaRef) =>
      _owners[_validReference(mediaRef)] == miniProgramId;

  void requireOwned(String miniProgramId, Iterable<String> mediaRefs) {
    _ensureActive();
    for (final mediaRef in mediaRefs) {
      if (!owns(miniProgramId, mediaRef)) {
        throw const MiniProgramMediaException(
          errorCode: MiniProgramErrorCodes.mediaNotOwned,
          message: 'The media reference is not owned by this mini-program.',
        );
      }
    }
  }

  Future<MiniProgramMediaPreviewResult> loadPreview({
    required String miniProgramId,
    required String mediaRef,
  }) {
    _ensureActive();
    final normalized = _validReference(mediaRef);
    requireOwned(miniProgramId, <String>[normalized]);
    return _previews.putIfAbsent(
      normalized,
      () => _loadPreview(miniProgramId, normalized),
    );
  }

  Future<bool> release({
    required String miniProgramId,
    required String mediaRef,
  }) async {
    _ensureActive();
    final normalized = _validReference(mediaRef);
    requireOwned(miniProgramId, <String>[normalized]);
    _previews.remove(normalized);
    final released = await provider.releaseMedia(
      MiniProgramMediaReleaseRequest(
        miniProgramId: miniProgramId,
        mediaRef: normalized,
      ),
    );
    _owners.remove(normalized);
    if (!released) {
      throw const MiniProgramMediaException(
        errorCode: MiniProgramErrorCodes.mediaNotFound,
        message: 'The temporary media is no longer available.',
      );
    }
    return true;
  }

  Future<void> releaseAllFor(String miniProgramId) async {
    final refs = _owners.entries
        .where((entry) => entry.value == miniProgramId)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final mediaRef in refs) {
      try {
        await release(miniProgramId: miniProgramId, mediaRef: mediaRef);
      } on Object {
        _previews.remove(mediaRef);
        _owners.remove(mediaRef);
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    final appIds = _owners.values.toSet();
    for (final appId in appIds) {
      await releaseAllFor(appId);
    }
    _disposed = true;
    _owners.clear();
    _previews.clear();
  }

  Future<MiniProgramMediaPreviewResult> _loadPreview(
    String miniProgramId,
    String mediaRef,
  ) async {
    try {
      final result = await provider.loadPreview(
        MiniProgramMediaPreviewRequest(
          miniProgramId: miniProgramId,
          mediaRef: mediaRef,
        ),
      );
      final mimeType = result.mimeType.trim().toLowerCase();
      if (result.mediaRef != mediaRef ||
          !mimeType.startsWith('image/') ||
          result.bytes.isEmpty ||
          result.bytes.length > miniProgramMediaMaxPreviewBytes) {
        throw const MiniProgramMediaException(
          errorCode: MiniProgramErrorCodes.mediaInvalidResult,
          message: 'The host returned an invalid media preview.',
        );
      }
      return MiniProgramMediaPreviewResult(
        mediaRef: mediaRef,
        mimeType: mimeType,
        bytes: Uint8List.fromList(result.bytes),
      );
    } catch (_) {
      _previews.remove(mediaRef);
      rethrow;
    }
  }

  String _validReference(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > 512) {
      throw const MiniProgramMediaException(
        errorCode: MiniProgramErrorCodes.mediaInvalidResult,
        message: 'The media reference is invalid.',
      );
    }
    return normalized;
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('MiniProgramMediaManager is disposed.');
    }
  }
}
