import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../media/mini_program_media.dart';

/// Host-accepted limits for user-selected gallery photos.
@immutable
class MiniProgramGalleryPolicy {
  const MiniProgramGalleryPolicy({
    this.enabled = false,
    this.maxImages = 9,
    this.maxImageBytes = 20 * 1024 * 1024,
    this.maxTotalBytes = 50 * 1024 * 1024,
  });

  final bool enabled;
  final int maxImages;
  final int maxImageBytes;
  final int maxTotalBytes;

  @override
  bool operator ==(Object other) =>
      other is MiniProgramGalleryPolicy &&
      enabled == other.enabled &&
      maxImages == other.maxImages &&
      maxImageBytes == other.maxImageBytes &&
      maxTotalBytes == other.maxTotalBytes;

  @override
  int get hashCode =>
      Object.hash(enabled, maxImages, maxImageBytes, maxTotalBytes);
}

abstract interface class MiniProgramGalleryPolicyProvider {
  MiniProgramGalleryPolicy galleryPolicyFor(String miniProgramId);
}

/// Trusted selection request. These limits come from host-accepted policy.
@immutable
class MiniProgramGalleryRequest {
  const MiniProgramGalleryRequest({
    required this.selectionId,
    required this.miniProgramId,
    required this.maxImages,
    required this.maxImageBytes,
    required this.maxTotalBytes,
    required this.maxWidth,
    required this.maxHeight,
    required this.quality,
  });

  final String selectionId;
  final String miniProgramId;
  final int maxImages;
  final int maxImageBytes;
  final int maxTotalBytes;
  final int maxWidth;
  final int maxHeight;
  final int quality;
}

/// Photo selection and app-owned media access supplied by a trusted host.
abstract interface class MiniProgramGalleryProvider
    implements MiniProgramMediaProvider {
  Future<MiniProgramGalleryResult> pickImages(
    MiniProgramGalleryRequest request,
  );
  Future<bool> cancel(String selectionId);
}

class MiniProgramGalleryException implements Exception {
  const MiniProgramGalleryException({
    required this.errorCode,
    required this.message,
  });
  final String errorCode;
  final String message;
  @override
  String toString() => message;
}

/// Owns selection identity, cancellation, validation, and temporary media.
class MiniProgramGalleryManager {
  MiniProgramGalleryManager(this.provider, {required this.mediaManager});

  final MiniProgramGalleryProvider provider;
  final MiniProgramMediaManager mediaManager;
  final Map<String, String> _owners = {};
  _GalleryOperation? _active;
  int _sequence = 0;
  bool _disposed = false;

  Future<MiniProgramGalleryResult> pickImages({
    required String miniProgramId,
    required MiniProgramGalleryPolicy policy,
    int maxImages = 1,
    int maxWidth = 2048,
    int maxHeight = 2048,
    int quality = 90,
  }) async {
    if (_disposed) throw StateError('MiniProgramGalleryManager is disposed.');
    if (!policy.enabled) {
      throw const MiniProgramGalleryException(
        errorCode: MiniProgramErrorCodes.galleryNotAccepted,
        message: 'Gallery selection is not accepted by host policy.',
      );
    }
    if (maxImages < 1 ||
        maxImages > miniProgramGalleryMaxImages ||
        policy.maxImages < 1 ||
        policy.maxImages > miniProgramGalleryMaxImages ||
        policy.maxImageBytes < 1 ||
        policy.maxImageBytes > 100 * 1024 * 1024 ||
        policy.maxTotalBytes < 1 ||
        policy.maxTotalBytes > 300 * 1024 * 1024 ||
        maxWidth < 64 ||
        maxWidth > 8192 ||
        maxHeight < 64 ||
        maxHeight > 8192 ||
        quality < 1 ||
        quality > 100) {
      throw const MiniProgramGalleryException(
        errorCode: MiniProgramErrorCodes.galleryInvalidRequest,
        message: 'The gallery request or accepted limits are invalid.',
      );
    }
    if (_active != null) {
      throw const MiniProgramGalleryException(
        errorCode: MiniProgramErrorCodes.galleryRequestInProgress,
        message: 'A gallery selection is already in progress.',
      );
    }
    final operation = _GalleryOperation(
      'gallery_${DateTime.now().microsecondsSinceEpoch}_${++_sequence}',
      miniProgramId,
    );
    _active = operation;
    final limit = math.min(maxImages, policy.maxImages);
    MiniProgramGalleryResult? result;
    final registered = <String>[];
    try {
      result = await provider.pickImages(
        MiniProgramGalleryRequest(
          selectionId: operation.id,
          miniProgramId: miniProgramId,
          maxImages: limit,
          maxImageBytes: policy.maxImageBytes,
          maxTotalBytes: policy.maxTotalBytes,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          quality: quality,
        ),
      );
      if (operation.cancelled || _disposed) {
        throw const MiniProgramGalleryException(
          errorCode: MiniProgramErrorCodes.gallerySelectionCancelled,
          message: 'Photo selection was cancelled.',
        );
      }
      result.validate();
      if (result.selectionId != operation.id ||
          result.images.length > limit ||
          result.images.any(
            (image) => mediaManager.isRegistered(image.mediaRef),
          )) {
        throw const MiniProgramGalleryException(
          errorCode: MiniProgramErrorCodes.galleryInvalidResult,
          message: 'The host returned invalid gallery references.',
        );
      }
      final total = result.images.fold<int>(
        0,
        (sum, image) => sum + image.bytes,
      );
      if (total > policy.maxTotalBytes ||
          result.images.any(
            (image) =>
                image.bytes > policy.maxImageBytes ||
                image.width > maxWidth ||
                image.height > maxHeight,
          )) {
        throw const MiniProgramGalleryException(
          errorCode: MiniProgramErrorCodes.galleryLimitExceeded,
          message: 'The selected photos exceed accepted gallery limits.',
        );
      }
      for (final image in result.images) {
        mediaManager.register(
          miniProgramId: miniProgramId,
          mediaRef: image.mediaRef,
        );
        registered.add(image.mediaRef);
        _owners[image.mediaRef] = miniProgramId;
      }
      return result;
    } catch (error) {
      if (result != null) {
        for (final ref
            in result.images.map((image) => image.mediaRef).toSet()) {
          if (registered.contains(ref)) {
            await _release(miniProgramId, ref);
          } else if (!mediaManager.isRegistered(ref)) {
            await _releaseNative(miniProgramId, ref);
          }
        }
      }
      if (error is FormatException || error is MiniProgramMediaException) {
        throw const MiniProgramGalleryException(
          errorCode: MiniProgramErrorCodes.galleryInvalidResult,
          message: 'The host returned invalid gallery metadata.',
        );
      }
      rethrow;
    } finally {
      if (identical(_active, operation)) _active = null;
    }
  }

  Future<bool> cancelFor(String miniProgramId) async {
    final operation = _active;
    if (operation == null || operation.appId != miniProgramId) return false;
    operation.cancelled = true;
    try {
      await provider.cancel(operation.id);
    } on Object {
      /* Logical cancellation still applies. */
    }
    return true;
  }

  Future<void> releaseSelection(
    String miniProgramId,
    MiniProgramGalleryResult result,
  ) async {
    for (final image in result.images) {
      if (_owners[image.mediaRef] == miniProgramId) {
        await _release(miniProgramId, image.mediaRef);
      }
    }
  }

  Future<void> releaseAllFor(String miniProgramId) async {
    await cancelFor(miniProgramId);
    final refs = _owners.entries
        .where((entry) => entry.value == miniProgramId)
        .map((entry) => entry.key)
        .toList();
    for (final ref in refs) {
      await _release(miniProgramId, ref);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final apps = {..._owners.values, if (_active != null) _active!.appId};
    for (final appId in apps) {
      await releaseAllFor(appId);
    }
  }

  Future<void> _release(String appId, String ref) async {
    _owners.remove(ref);
    if (mediaManager.owns(appId, ref)) {
      try {
        await mediaManager.release(miniProgramId: appId, mediaRef: ref);
      } on Object {
        /* Best effort. */
      }
    }
  }

  Future<void> _releaseNative(String appId, String ref) async {
    try {
      await provider.releaseMedia(
        MiniProgramMediaReleaseRequest(miniProgramId: appId, mediaRef: ref),
      );
    } on Object {
      /* Best effort; never release a reference belonging to another app. */
    }
  }
}

class _GalleryOperation {
  _GalleryOperation(this.id, this.appId);
  final String id;
  final String appId;
  bool cancelled = false;
}
