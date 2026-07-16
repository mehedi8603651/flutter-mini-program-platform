part of '../../mini_program_backend_store.dart';

@immutable
class MiniProgramBackendSnapshot {
  const MiniProgramBackendSnapshot({
    required this.requestId,
    required this.status,
    this.endpoint,
    this.method,
    this.statusCode,
    this.message,
    this.errorCode,
    this.data = const <String, dynamic>{},
    this.fromCache = false,
    this.updatedAt,
  });

  factory MiniProgramBackendSnapshot.idle(String requestId) {
    return MiniProgramBackendSnapshot(
      requestId: requestId,
      status: MiniProgramBackendSnapshotStatus.idle,
    );
  }

  factory MiniProgramBackendSnapshot.loading({
    required String requestId,
    required String endpoint,
    required String method,
    MiniProgramBackendSnapshot? previous,
  }) {
    return MiniProgramBackendSnapshot(
      requestId: requestId,
      status: MiniProgramBackendSnapshotStatus.loading,
      endpoint: endpoint,
      method: method,
      data: previous?.data ?? const <String, dynamic>{},
      fromCache: previous?.fromCache ?? false,
      updatedAt: previous?.updatedAt,
    );
  }

  factory MiniProgramBackendSnapshot.fromResult(
    MiniProgramBackendResult result, {
    required String requestId,
    MiniProgramBackendSnapshot? previous,
  }) {
    final isSuccess = result.isSuccess;
    return MiniProgramBackendSnapshot(
      requestId: requestId,
      status: isSuccess
          ? MiniProgramBackendSnapshotStatus.success
          : MiniProgramBackendSnapshotStatus.failed,
      endpoint: result.endpoint,
      method: result.method,
      statusCode: result.statusCode,
      message: result.message,
      errorCode: result.errorCode,
      data: isSuccess ? result.data : previous?.data ?? result.data,
      fromCache: result.fromCache,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  final String requestId;
  final MiniProgramBackendSnapshotStatus status;
  final String? endpoint;
  final String? method;
  final int? statusCode;
  final String? message;
  final String? errorCode;
  final Map<String, dynamic> data;
  final bool fromCache;
  final DateTime? updatedAt;

  bool get isIdle => status == MiniProgramBackendSnapshotStatus.idle;
  bool get isLoading => status == MiniProgramBackendSnapshotStatus.loading;
  bool get isSuccess => status == MiniProgramBackendSnapshotStatus.success;
  bool get isFailure => status == MiniProgramBackendSnapshotStatus.failed;
  bool get hasData => data.isNotEmpty;

  Map<String, dynamic> toBindingData() {
    return <String, dynamic>{
      'requestId': requestId,
      'status': status.name,
      'idle': isIdle,
      'loading': isLoading,
      'success': isSuccess,
      'failed': isFailure,
      'error': isFailure,
      if (endpoint != null) 'endpoint': endpoint,
      if (method != null) 'method': method,
      if (statusCode != null) 'statusCode': statusCode,
      if (message != null) 'message': message,
      if (errorCode != null) 'errorCode': errorCode,
      'data': data,
      'hasData': hasData,
      'fromCache': fromCache,
      if (updatedAt != null) 'updatedAtUtc': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toBindingData();
}
