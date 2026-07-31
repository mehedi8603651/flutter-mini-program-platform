import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../network/mini_program_backend_connector.dart';

/// Destination used by a completed Publisher API download.
enum MiniProgramFileDownloadDestination { downloads, choose, temporary }

/// Host authority for Publisher API file transfers.
@immutable
class MiniProgramFilePolicy {
  const MiniProgramFilePolicy({
    this.enabled = false,
    this.allowUpload = false,
    this.allowDownload = false,
    this.allowedMimeTypes = const <String>{'*/*'},
    this.allowedDestinations = const <MiniProgramFileDownloadDestination>{
      MiniProgramFileDownloadDestination.downloads,
      MiniProgramFileDownloadDestination.choose,
      MiniProgramFileDownloadDestination.temporary,
    },
    this.maxFilesPerUpload = 10,
    this.maxConcurrentTransfers = 2,
    this.maxFileBytes,
    this.minimumFreeBytes = 256 * 1024 * 1024,
  }) : assert(maxFilesPerUpload > 0),
       assert(maxConcurrentTransfers > 0),
       assert(maxFileBytes == null || maxFileBytes > 0),
       assert(minimumFreeBytes >= 0);

  final bool enabled;
  final bool allowUpload;
  final bool allowDownload;
  final Set<String> allowedMimeTypes;
  final Set<MiniProgramFileDownloadDestination> allowedDestinations;
  final int maxFilesPerUpload;
  final int maxConcurrentTransfers;

  /// Optional host policy cap. `null` delegates size limits to storage and the
  /// provider while retaining streaming and free-space safeguards.
  final int? maxFileBytes;
  final int minimumFreeBytes;

  bool acceptsMimeType(String mimeType) {
    final normalized = mimeType.trim().toLowerCase();
    if (allowedMimeTypes.contains('*/*') ||
        allowedMimeTypes.contains(normalized)) {
      return true;
    }
    final separator = normalized.indexOf('/');
    return separator > 0 &&
        allowedMimeTypes.contains('${normalized.substring(0, separator)}/*');
  }

  @override
  bool operator ==(Object other) {
    return other is MiniProgramFilePolicy &&
        enabled == other.enabled &&
        allowUpload == other.allowUpload &&
        allowDownload == other.allowDownload &&
        setEquals(allowedMimeTypes, other.allowedMimeTypes) &&
        setEquals(allowedDestinations, other.allowedDestinations) &&
        maxFilesPerUpload == other.maxFilesPerUpload &&
        maxConcurrentTransfers == other.maxConcurrentTransfers &&
        maxFileBytes == other.maxFileBytes &&
        minimumFreeBytes == other.minimumFreeBytes;
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    allowUpload,
    allowDownload,
    Object.hashAllUnordered(allowedMimeTypes),
    Object.hashAllUnordered(allowedDestinations),
    maxFilesPerUpload,
    maxConcurrentTransfers,
    maxFileBytes,
    minimumFreeBytes,
  );
}

/// Resolves accepted file policy for one mini-program endpoint.
abstract interface class MiniProgramFilePolicyProvider {
  MiniProgramFilePolicy filePolicyFor(String miniProgramId);
}

typedef MiniProgramFileProgressCallback =
    void Function(MiniProgramFileTransferProgress progress);

/// Upload request passed only to a trusted host file provider.
@immutable
class MiniProgramFileUploadRequest {
  const MiniProgramFileUploadRequest({
    required this.transferId,
    required this.miniProgramId,
    required this.backend,
    required this.mimeTypes,
    required this.multiple,
    required this.maxFiles,
    required this.fieldName,
    required this.metadata,
    required this.maxFileBytes,
    required this.minimumFreeBytes,
    required this.maxConcurrentTransfers,
  });

  final String transferId;
  final String miniProgramId;
  final MiniProgramResolvedBackendTransfer backend;
  final List<String> mimeTypes;
  final bool multiple;
  final int maxFiles;
  final String fieldName;
  final Map<String, dynamic> metadata;
  final int? maxFileBytes;
  final int minimumFreeBytes;
  final int maxConcurrentTransfers;
}

/// Download request passed only to a trusted host file provider.
@immutable
class MiniProgramFileDownloadRequest {
  const MiniProgramFileDownloadRequest({
    required this.transferId,
    required this.miniProgramId,
    required this.backend,
    required this.request,
    required this.destination,
    required this.maxFileBytes,
    required this.minimumFreeBytes,
    required this.maxConcurrentTransfers,
    this.suggestedName,
    this.expectedMimeType,
  });

  final String transferId;
  final String miniProgramId;
  final MiniProgramResolvedBackendTransfer backend;
  final Map<String, dynamic> request;
  final MiniProgramFileDownloadDestination destination;
  final String? suggestedName;
  final String? expectedMimeType;
  final int? maxFileBytes;
  final int minimumFreeBytes;
  final int maxConcurrentTransfers;
}

/// Normalized transfer result returned by a trusted host provider.
@immutable
class MiniProgramFileTransferResult {
  const MiniProgramFileTransferResult({
    required this.transferId,
    required this.direction,
    required this.statusCode,
    required this.bytesTransferred,
    this.fileName,
    this.mimeType,
    this.destination,
    this.data = const <String, dynamic>{},
  });

  final String transferId;
  final MiniProgramFileTransferDirection direction;
  final int statusCode;
  final int bytesTransferred;
  final String? fileName;
  final String? mimeType;
  final String? destination;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'transferId': transferId,
    'direction': direction.wireValue,
    'status': 'completed',
    'statusCode': statusCode,
    'bytesTransferred': bytesTransferred,
    if (fileName != null) 'fileName': fileName,
    if (mimeType != null) 'mimeType': mimeType,
    if (destination != null) 'destination': destination,
    if (data.isNotEmpty) 'data': data,
  };
}

/// Performs native file selection/storage and streaming network transport.
///
/// Implementations must stream data, enforce request limits while streaming,
/// remove partial files on failure, and never expose native paths or URIs in
/// returned data.
abstract interface class MiniProgramFileTransferProvider {
  Future<MiniProgramFileTransferResult> upload(
    MiniProgramFileUploadRequest request, {
    required MiniProgramFileProgressCallback onProgress,
  });

  Future<MiniProgramFileTransferResult> download(
    MiniProgramFileDownloadRequest request, {
    required MiniProgramFileProgressCallback onProgress,
  });

  Future<bool> cancel(String transferId);
}

/// Structured provider failure mapped to stable mini-program errors.
class MiniProgramFileException implements Exception {
  const MiniProgramFileException({
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

/// Owns transfer identity, concurrency, cancellation, and app isolation.
class MiniProgramFileTransferManager {
  MiniProgramFileTransferManager(this.provider);

  final MiniProgramFileTransferProvider provider;
  final Map<String, String> _owners = <String, String>{};
  int _sequence = 0;
  bool _disposed = false;

  int activeCountFor(String miniProgramId) =>
      _owners.values.where((owner) => owner == miniProgramId).length;

  String createTransferId(String miniProgramId) {
    _ensureActive();
    _sequence++;
    return 'transfer_${DateTime.now().microsecondsSinceEpoch}_$_sequence';
  }

  Future<MiniProgramFileTransferResult> upload(
    MiniProgramFileUploadRequest request, {
    required MiniProgramFileProgressCallback onProgress,
  }) => _run(
    transferId: request.transferId,
    miniProgramId: request.miniProgramId,
    onProgress: onProgress,
    maxConcurrentTransfers: request.maxConcurrentTransfers,
    operation: (progress) => provider.upload(request, onProgress: progress),
  );

  Future<MiniProgramFileTransferResult> download(
    MiniProgramFileDownloadRequest request, {
    required MiniProgramFileProgressCallback onProgress,
  }) => _run(
    transferId: request.transferId,
    miniProgramId: request.miniProgramId,
    onProgress: onProgress,
    maxConcurrentTransfers: request.maxConcurrentTransfers,
    operation: (progress) => provider.download(request, onProgress: progress),
  );

  Future<bool> cancel(String miniProgramId, String transferId) async {
    _ensureActive();
    if (_owners[transferId] != miniProgramId) {
      return false;
    }
    return provider.cancel(transferId);
  }

  Future<void> cancelAllFor(String miniProgramId) async {
    final ids = _owners.entries
        .where((entry) => entry.value == miniProgramId)
        .map((entry) => entry.key)
        .toList(growable: false);
    await Future.wait(ids.map(_cancelBestEffort));
  }

  Future<MiniProgramFileTransferResult> _run({
    required String transferId,
    required String miniProgramId,
    required MiniProgramFileProgressCallback onProgress,
    required int maxConcurrentTransfers,
    required Future<MiniProgramFileTransferResult> Function(
      MiniProgramFileProgressCallback progress,
    )
    operation,
  }) async {
    _ensureActive();
    if (_owners.containsKey(transferId)) {
      throw const MiniProgramFileException(
        errorCode: MiniProgramErrorCodes.fileTransferLimitExceeded,
        message: 'File transfer identifier is already active.',
      );
    }
    if (activeCountFor(miniProgramId) >= maxConcurrentTransfers) {
      throw MiniProgramFileException(
        errorCode: MiniProgramErrorCodes.fileTransferLimitExceeded,
        message: 'The accepted concurrent file transfer limit was reached.',
        details: <String, Object?>{
          'maxConcurrentTransfers': maxConcurrentTransfers,
        },
      );
    }
    _owners[transferId] = miniProgramId;
    try {
      return await operation((progress) {
        if (!_disposed && _owners[transferId] == miniProgramId) {
          onProgress(progress);
        }
      });
    } finally {
      _owners.remove(transferId);
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final ids = _owners.keys.toList(growable: false);
    _owners.clear();
    await Future.wait(ids.map(_cancelBestEffort));
  }

  Future<void> _cancelBestEffort(String transferId) async {
    try {
      await provider.cancel(transferId);
    } on Object {
      // Lifecycle cleanup must not surface an unhandled provider exception.
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('MiniProgramFileTransferManager is disposed.');
    }
  }
}
