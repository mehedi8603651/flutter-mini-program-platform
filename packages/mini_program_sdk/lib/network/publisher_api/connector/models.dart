part of '../../mini_program_backend_connector.dart';

typedef MiniProgramBackendHttpClientFactory = http.Client Function();

@immutable
class MiniProgramBackendEndpoint {
  const MiniProgramBackendEndpoint({
    required this.baseUri,
    this.headers = const <String, String>{},
    this.requestTimeout = const Duration(seconds: 8),
    this.enableLocalLoopbackFallback = true,
  });

  final Uri baseUri;
  final Map<String, String> headers;
  final Duration requestTimeout;
  final bool enableLocalLoopbackFallback;
}

@immutable
class MiniProgramBackendCachePolicy {
  const MiniProgramBackendCachePolicy({this.ttl});

  const MiniProgramBackendCachePolicy.noCache() : ttl = null;

  final Duration? ttl;

  bool get isEnabled => ttl != null && ttl! > Duration.zero;
}

@immutable
class MiniProgramBackendRequest {
  const MiniProgramBackendRequest({
    required this.miniProgramId,
    required this.endpoint,
    this.requestId,
    this.method = 'GET',
    this.body = const <String, dynamic>{},
    this.headers = const <String, String>{},
    this.cachePolicy = const MiniProgramBackendCachePolicy.noCache(),
    this.forceRefresh = false,
  });

  final String miniProgramId;
  final String endpoint;
  final String? requestId;
  final String method;
  final Map<String, dynamic> body;
  final Map<String, String> headers;
  final MiniProgramBackendCachePolicy cachePolicy;
  final bool forceRefresh;

  MiniProgramBackendRequest copyWith({
    Map<String, String>? headers,
    MiniProgramBackendCachePolicy? cachePolicy,
    bool? forceRefresh,
  }) {
    return MiniProgramBackendRequest(
      miniProgramId: miniProgramId,
      endpoint: endpoint,
      requestId: requestId,
      method: method,
      body: body,
      headers: headers ?? this.headers,
      cachePolicy: cachePolicy ?? this.cachePolicy,
      forceRefresh: forceRefresh ?? this.forceRefresh,
    );
  }
}

enum MiniProgramBackendResultStatus { success, failed }

@immutable
class MiniProgramBackendResult {
  const MiniProgramBackendResult({
    required this.status,
    this.requestId,
    this.endpoint,
    this.method,
    this.statusCode,
    this.message,
    this.errorCode,
    this.data = const <String, dynamic>{},
    this.fromCache = false,
  });

  final MiniProgramBackendResultStatus status;
  final String? requestId;
  final String? endpoint;
  final String? method;
  final int? statusCode;
  final String? message;
  final String? errorCode;
  final Map<String, dynamic> data;
  final bool fromCache;

  factory MiniProgramBackendResult.success({
    String? requestId,
    String? endpoint,
    String? method,
    int? statusCode,
    String? message,
    Map<String, dynamic> data = const <String, dynamic>{},
    bool fromCache = false,
  }) {
    return MiniProgramBackendResult(
      status: MiniProgramBackendResultStatus.success,
      requestId: requestId,
      endpoint: endpoint,
      method: method,
      statusCode: statusCode,
      message: message,
      data: data,
      fromCache: fromCache,
    );
  }

  factory MiniProgramBackendResult.failed({
    String? requestId,
    String? endpoint,
    String? method,
    int? statusCode,
    String? message,
    String? errorCode,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) {
    return MiniProgramBackendResult(
      status: MiniProgramBackendResultStatus.failed,
      requestId: requestId,
      endpoint: endpoint,
      method: method,
      statusCode: statusCode,
      message: message,
      errorCode: errorCode,
      data: data,
    );
  }

  bool get isSuccess => status == MiniProgramBackendResultStatus.success;
  bool get isFailure => status == MiniProgramBackendResultStatus.failed;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'status': isSuccess ? 'success' : 'failed',
      if (requestId != null) 'requestId': requestId,
      if (endpoint != null) 'endpoint': endpoint,
      if (method != null) 'method': method,
      if (statusCode != null) 'statusCode': statusCode,
      if (message != null) 'message': message,
      if (errorCode != null) 'errorCode': errorCode,
      'data': data,
      'fromCache': fromCache,
    };
  }
}
