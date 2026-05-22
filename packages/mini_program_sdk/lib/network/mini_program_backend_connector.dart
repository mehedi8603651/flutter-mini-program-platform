import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'http_mini_program_source.dart';
import 'mini_program_delivery_context.dart';

typedef MiniProgramBackendHttpClientFactory = http.Client Function();

abstract final class MiniProgramBackendHttpHeaders {
  static const String appId = 'x-mini-program-app-id';
  static const String hostApp = 'x-mini-program-host-app';
  static const String hostVersion = 'x-mini-program-host-version';
  static const String sdkVersion = 'x-mini-program-sdk-version';
  static const String platform = 'x-mini-program-platform';
  static const String locale = 'x-mini-program-locale';
}

@immutable
class MiniProgramBackendEndpoint {
  const MiniProgramBackendEndpoint({
    required this.baseUri,
    this.headers = const <String, String>{},
    this.requestTimeout = const Duration(seconds: 8),
    this.sendAccessKeyToBackend = false,
    this.enableLocalLoopbackFallback = true,
  });

  final Uri baseUri;
  final Map<String, String> headers;
  final Duration requestTimeout;
  final bool sendAccessKeyToBackend;
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
    this.cachePolicy = const MiniProgramBackendCachePolicy.noCache(),
  });

  final String miniProgramId;
  final String endpoint;
  final String? requestId;
  final String method;
  final Map<String, dynamic> body;
  final MiniProgramBackendCachePolicy cachePolicy;
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

abstract interface class MiniProgramBackendConnector {
  Future<MiniProgramBackendResult> call(MiniProgramBackendRequest request);
}

abstract interface class DisposableMiniProgramBackendConnector
    implements MiniProgramBackendConnector {
  void dispose();
}

class EndpointRoutingMiniProgramBackendConnector
    implements DisposableMiniProgramBackendConnector {
  EndpointRoutingMiniProgramBackendConnector({
    required Map<String, MiniProgramBackendEndpoint> backends,
    required MiniProgramDeliveryContext deliveryContext,
    Map<String, String> accessKeys = const <String, String>{},
    MiniProgramBackendHttpClientFactory? clientFactory,
  }) : _backends = Map.unmodifiable(_normalizeBackends(backends)),
       _deliveryContext = deliveryContext,
       _accessKeys = Map.unmodifiable(_normalizeAccessKeys(accessKeys)),
       _clientFactory = clientFactory ?? http.Client.new;

  final Map<String, MiniProgramBackendEndpoint> _backends;
  final MiniProgramDeliveryContext _deliveryContext;
  final Map<String, String> _accessKeys;
  final MiniProgramBackendHttpClientFactory _clientFactory;
  final Map<String, _CachedBackendResult> _cache =
      <String, _CachedBackendResult>{};

  http.Client? _client;
  bool _disposed = false;

  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    if (_disposed) {
      return MiniProgramBackendResult.failed(
        requestId: request.requestId,
        endpoint: request.endpoint,
        method: request.method,
        message: 'Mini-program backend connector has been disposed.',
        errorCode: 'publisher_backend_disposed',
      );
    }

    final appId = request.miniProgramId.trim();
    final backend = _backends[appId];
    if (backend == null) {
      return MiniProgramBackendResult.failed(
        requestId: request.requestId,
        endpoint: request.endpoint,
        method: request.method,
        message:
            'No publisher backend is configured for mini-program "$appId".',
        errorCode: 'publisher_backend_not_configured',
      );
    }

    final method = _normalizeMethod(request.method);
    final normalizedEndpoint = _normalizeRelativeEndpoint(request.endpoint);
    if (normalizedEndpoint == null) {
      return MiniProgramBackendResult.failed(
        requestId: request.requestId,
        endpoint: request.endpoint,
        method: method,
        message:
            'Mini-program backend endpoint must be a relative path, for example "home/bootstrap".',
        errorCode: 'invalid_backend_endpoint',
      );
    }

    final uri = _resolve(backend.baseUri, normalizedEndpoint);
    final cacheKey = _cacheKey(appId: appId, method: method, uri: uri);
    if (method == 'GET' && request.cachePolicy.isEnabled) {
      final cached = _cache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return cached.result.copyWith(fromCache: true);
      }
    }

    late final http.Response response;
    try {
      response = await _loadResponse(
        backend: backend,
        uri: uri,
        method: method,
        body: request.body,
        headers: _requestHeaders(appId, backend),
      );
    } on TimeoutException {
      return MiniProgramBackendResult.failed(
        requestId: request.requestId,
        endpoint: normalizedEndpoint,
        method: method,
        message: 'Timed out while calling the mini-program publisher backend.',
        errorCode: 'publisher_backend_timeout',
        data: <String, dynamic>{
          'requestTimeoutMs': backend.requestTimeout.inMilliseconds,
        },
      );
    } catch (error) {
      return MiniProgramBackendResult.failed(
        requestId: request.requestId,
        endpoint: normalizedEndpoint,
        method: method,
        message: 'Failed to reach the mini-program publisher backend.',
        errorCode: 'publisher_backend_unreachable',
        data: <String, dynamic>{'transportError': error.toString()},
      );
    }

    final result = _toResult(
      request: request,
      endpoint: normalizedEndpoint,
      method: method,
      response: response,
    );

    if (result.isSuccess && method == 'GET' && request.cachePolicy.isEnabled) {
      _cache[cacheKey] = _CachedBackendResult(
        result: result,
        expiresAt: DateTime.now().add(request.cachePolicy.ttl!),
      );
    }

    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _cache.clear();
    _client?.close();
    _client = null;
  }

  http.Client get _resolvedClient => _client ??= _clientFactory();

  Future<http.Response> _loadResponse({
    required MiniProgramBackendEndpoint backend,
    required Uri uri,
    required String method,
    required Map<String, dynamic> body,
    required Map<String, String> headers,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (final candidateUri in _candidateUris(uri, backend)) {
      try {
        return await _loadSingleResponse(
          backend: backend,
          uri: candidateUri,
          method: method,
          body: body,
          headers: headers,
        );
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    if (lastError != null && lastStackTrace != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace);
    }
    throw StateError('No mini-program backend request URI candidates found.');
  }

  Future<http.Response> _loadSingleResponse({
    required MiniProgramBackendEndpoint backend,
    required Uri uri,
    required String method,
    required Map<String, dynamic> body,
    required Map<String, String> headers,
  }) {
    final client = _resolvedClient;
    final effectiveHeaders = method == 'GET'
        ? headers
        : <String, String>{'content-type': 'application/json', ...headers};
    final encodedBody = method == 'GET' ? null : jsonEncode(body);

    final future = switch (method) {
      'GET' => client.get(uri, headers: effectiveHeaders),
      'POST' => client.post(uri, headers: effectiveHeaders, body: encodedBody),
      'PUT' => client.put(uri, headers: effectiveHeaders, body: encodedBody),
      'PATCH' => client.patch(
        uri,
        headers: effectiveHeaders,
        body: encodedBody,
      ),
      'DELETE' => client.delete(
        uri,
        headers: effectiveHeaders,
        body: encodedBody,
      ),
      _ => client.post(uri, headers: effectiveHeaders, body: encodedBody),
    };

    return future.timeout(backend.requestTimeout);
  }

  List<Uri> _candidateUris(Uri primaryUri, MiniProgramBackendEndpoint backend) {
    if (!backend.enableLocalLoopbackFallback || primaryUri.scheme != 'http') {
      return <Uri>[primaryUri];
    }

    final hosts = <String>[primaryUri.host];
    if (primaryUri.host == '10.0.2.2') {
      hosts.add('127.0.0.1');
    } else if (primaryUri.host == '127.0.0.1' ||
        primaryUri.host == 'localhost') {
      hosts.add('10.0.2.2');
    }

    return hosts
        .toSet()
        .map(
          (host) => host == primaryUri.host
              ? primaryUri
              : primaryUri.replace(host: host),
        )
        .toList();
  }

  Map<String, String> _requestHeaders(
    String appId,
    MiniProgramBackendEndpoint backend,
  ) {
    final headers = <String, String>{
      'accept': 'application/json',
      MiniProgramBackendHttpHeaders.appId: appId,
      MiniProgramBackendHttpHeaders.hostApp: _deliveryContext.hostApp,
      MiniProgramBackendHttpHeaders.hostVersion: _deliveryContext.hostVersion,
      MiniProgramBackendHttpHeaders.sdkVersion: _deliveryContext.sdkVersion,
      if (_deliveryContext.platform?.trim().isNotEmpty == true)
        MiniProgramBackendHttpHeaders.platform: _deliveryContext.platform!
            .trim(),
      if (_deliveryContext.locale?.trim().isNotEmpty == true)
        MiniProgramBackendHttpHeaders.locale: _deliveryContext.locale!.trim(),
      ...backend.headers,
    };
    final accessKey = _accessKeys[appId];
    if (backend.sendAccessKeyToBackend &&
        accessKey != null &&
        accessKey.isNotEmpty) {
      headers[MiniProgramHttpHeaders.accessKey] = accessKey;
    }
    return headers;
  }

  MiniProgramBackendResult _toResult({
    required MiniProgramBackendRequest request,
    required String endpoint,
    required String method,
    required http.Response response,
  }) {
    final decoded = _decodeBody(response.body);
    final data = _normalizeData(decoded);
    final message = data['message']?.toString();
    final errorCode = data['errorCode']?.toString();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return MiniProgramBackendResult.success(
        requestId: request.requestId,
        endpoint: endpoint,
        method: method,
        statusCode: response.statusCode,
        message: message,
        data: data,
      );
    }

    return MiniProgramBackendResult.failed(
      requestId: request.requestId,
      endpoint: endpoint,
      method: method,
      statusCode: response.statusCode,
      message:
          message ??
          'Mini-program publisher backend returned HTTP ${response.statusCode}.',
      errorCode: errorCode ?? 'publisher_backend_error',
      data: data,
    );
  }

  Object? _decodeBody(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return const <String, dynamic>{};
    }
    try {
      return jsonDecode(rawBody);
    } catch (_) {
      return <String, dynamic>{'rawBody': rawBody};
    }
  }

  Map<String, dynamic> _normalizeData(Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    if (decoded is List) {
      return <String, dynamic>{'items': decoded};
    }
    if (decoded == null) {
      return const <String, dynamic>{};
    }
    return <String, dynamic>{'value': decoded};
  }

  String _normalizeMethod(String rawMethod) {
    final method = rawMethod.trim().toUpperCase();
    return method.isEmpty ? 'GET' : method;
  }

  String? _normalizeRelativeEndpoint(String rawEndpoint) {
    final endpoint = rawEndpoint.trim();
    if (endpoint.isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(endpoint);
    if (parsed == null || parsed.hasScheme || parsed.hasAuthority) {
      return null;
    }
    final normalized = endpoint.replaceFirst(RegExp(r'^/+'), '');
    final segments = Uri.parse(normalized).pathSegments;
    if (segments.any((segment) => segment == '..')) {
      return null;
    }
    return normalized;
  }

  Uri _resolve(Uri baseUri, String relativeEndpoint) {
    final baseUrl = baseUri.toString();
    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse(normalizedBaseUrl).resolve(relativeEndpoint);
  }

  String _cacheKey({
    required String appId,
    required String method,
    required Uri uri,
  }) {
    return '$appId::$method::${uri.toString()}';
  }

  static Map<String, MiniProgramBackendEndpoint> _normalizeBackends(
    Map<String, MiniProgramBackendEndpoint> backends,
  ) {
    final normalized = <String, MiniProgramBackendEndpoint>{};
    for (final entry in backends.entries) {
      final appId = entry.key.trim();
      if (appId.isEmpty) {
        throw ArgumentError.value(entry.key, 'backends', 'appId is blank.');
      }
      if (!entry.value.baseUri.hasScheme || entry.value.baseUri.host.isEmpty) {
        throw ArgumentError.value(
          entry.value.baseUri,
          'baseUri',
          'Mini-program backend baseUri must be absolute.',
        );
      }
      normalized[appId] = entry.value;
    }
    return normalized;
  }

  static Map<String, String> _normalizeAccessKeys(
    Map<String, String> accessKeys,
  ) {
    return accessKeys.map((key, value) => MapEntry(key.trim(), value.trim()))
      ..removeWhere((key, value) => key.isEmpty || value.isEmpty);
  }
}

extension on MiniProgramBackendResult {
  MiniProgramBackendResult copyWith({bool? fromCache}) {
    return MiniProgramBackendResult(
      status: status,
      requestId: requestId,
      endpoint: endpoint,
      method: method,
      statusCode: statusCode,
      message: message,
      errorCode: errorCode,
      data: data,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

class _CachedBackendResult {
  const _CachedBackendResult({required this.result, required this.expiresAt});

  final MiniProgramBackendResult result;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
