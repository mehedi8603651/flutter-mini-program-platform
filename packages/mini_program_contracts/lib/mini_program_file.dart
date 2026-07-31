/// Direction of a publisher file transfer.
enum MiniProgramFileTransferDirection { upload, download }

/// Stable lifecycle states reported by file transfers.
enum MiniProgramFileTransferStatus {
  queued,
  running,
  completed,
  cancelled,
  failed,
}

/// Converts a file transfer direction to its wire value.
extension MiniProgramFileTransferDirectionX
    on MiniProgramFileTransferDirection {
  String get wireValue => switch (this) {
    MiniProgramFileTransferDirection.upload => 'upload',
    MiniProgramFileTransferDirection.download => 'download',
  };
}

/// Converts a file transfer status to its wire value.
extension MiniProgramFileTransferStatusX on MiniProgramFileTransferStatus {
  String get wireValue => switch (this) {
    MiniProgramFileTransferStatus.queued => 'queued',
    MiniProgramFileTransferStatus.running => 'running',
    MiniProgramFileTransferStatus.completed => 'completed',
    MiniProgramFileTransferStatus.cancelled => 'cancelled',
    MiniProgramFileTransferStatus.failed => 'failed',
  };
}

/// JSON-safe progress reported by an active upload or download.
class MiniProgramFileTransferProgress {
  MiniProgramFileTransferProgress({
    required String transferId,
    required this.direction,
    required this.status,
    required this.bytesTransferred,
    this.totalBytes,
    String? fileName,
  }) : transferId = _requiredFileString(transferId, 'transferId'),
       fileName = _optionalFileString(fileName, 'fileName') {
    if (bytesTransferred < 0) {
      throw const FormatException('bytesTransferred must not be negative.');
    }
    if (totalBytes != null && totalBytes! < 0) {
      throw const FormatException('totalBytes must not be negative.');
    }
    if (totalBytes != null && bytesTransferred > totalBytes!) {
      throw const FormatException('bytesTransferred cannot exceed totalBytes.');
    }
  }

  final String transferId;
  final MiniProgramFileTransferDirection direction;
  final MiniProgramFileTransferStatus status;
  final int bytesTransferred;
  final int? totalBytes;
  final String? fileName;

  double? get fraction => totalBytes == null || totalBytes == 0
      ? null
      : bytesTransferred / totalBytes!;

  Map<String, Object?> toJson() => <String, Object?>{
    'transferId': transferId,
    'direction': direction.wireValue,
    'status': status.wireValue,
    'bytesTransferred': bytesTransferred,
    if (totalBytes != null) 'totalBytes': totalBytes,
    if (fraction != null) 'progress': fraction,
    if (fileName != null) 'fileName': fileName,
  };
}

String _requiredFileString(String value, String label) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 512) {
    throw FormatException('$label must be 1-512 characters.');
  }
  return normalized;
}

String? _optionalFileString(String? value, String label) {
  if (value == null) {
    return null;
  }
  return _requiredFileString(value, label);
}
