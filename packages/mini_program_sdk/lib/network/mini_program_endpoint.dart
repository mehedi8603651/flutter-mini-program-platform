import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'http_mini_program_source.dart';
import 'mini_program_delivery_context.dart';
import 'mini_program_backend_connector.dart';
import 'mini_program_source.dart';
import 'mini_program_source_exception.dart';

typedef MiniProgramEndpointSourceFactory =
    MiniProgramSource Function({
      required String appId,
      required MiniProgramEndpoint endpoint,
      required MiniProgramDeliveryContext deliveryContext,
    });

/// A remote mini-program delivery endpoint registered by a host app.
///
/// Host UI should open mini-programs by `appId`; endpoint configuration owns
/// where that app is delivered from and which MiniProgram access key authorizes
/// this host to load it.
@immutable
class MiniProgramEndpoint {
  const MiniProgramEndpoint({
    required this.apiBaseUri,
    required this.accessKey,
    this.headers = const <String, String>{},
    this.requestTimeout = const Duration(seconds: 5),
    this.enableLocalLoopbackFallback = true,
    this.backend,
  });

  /// Creates a public/static mini-program endpoint.
  ///
  /// Public endpoints do not send the MiniProgram access-key header and should
  /// only be used for public demos, open-source samples, or CDN-hosted content
  /// that does not need delivery access control.
  const MiniProgramEndpoint.public({
    required this.apiBaseUri,
    this.headers = const <String, String>{},
    this.requestTimeout = const Duration(seconds: 5),
    this.enableLocalLoopbackFallback = true,
    this.backend,
  }) : accessKey = null;

  final Uri apiBaseUri;
  final String? accessKey;
  final Map<String, String> headers;
  final Duration requestTimeout;
  final bool enableLocalLoopbackFallback;
  final MiniProgramBackendEndpoint? backend;
}

MiniProgramBackendConnector? buildEndpointRoutingBackendConnector({
  required Map<String, MiniProgramEndpoint> endpoints,
  required MiniProgramDeliveryContext deliveryContext,
  MiniProgramBackendHttpClientFactory? clientFactory,
}) {
  final backends = <String, MiniProgramBackendEndpoint>{};
  final accessKeys = <String, String>{};
  for (final entry in EndpointRoutingMiniProgramSource._normalizeEndpoints(
    endpoints,
  ).entries) {
    final backend = entry.value.backend;
    if (backend == null) {
      continue;
    }
    backends[entry.key] = backend;
    final accessKey = entry.value.accessKey;
    if (accessKey != null) {
      accessKeys[entry.key] = accessKey.trim();
    }
  }
  if (backends.isEmpty) {
    return null;
  }
  return EndpointRoutingMiniProgramBackendConnector(
    backends: backends,
    accessKeys: accessKeys,
    deliveryContext: deliveryContext,
    clientFactory: clientFactory,
  );
}

/// Routes manifest and screen requests to per-app delivery endpoints.
class EndpointRoutingMiniProgramSource implements DisposableMiniProgramSource {
  EndpointRoutingMiniProgramSource({
    required Map<String, MiniProgramEndpoint> endpoints,
    required MiniProgramDeliveryContext deliveryContext,
    MiniProgramEndpointSourceFactory? sourceFactory,
  }) : _endpoints = Map.unmodifiable(_normalizeEndpoints(endpoints)),
       _deliveryContext = deliveryContext,
       _sourceFactory = sourceFactory ?? _defaultSourceFactory {
    if (_endpoints.isEmpty) {
      throw ArgumentError.value(
        endpoints,
        'endpoints',
        'At least one mini-program endpoint must be configured.',
      );
    }
  }

  final Map<String, MiniProgramEndpoint> _endpoints;
  final MiniProgramDeliveryContext _deliveryContext;
  final MiniProgramEndpointSourceFactory _sourceFactory;
  final Map<String, MiniProgramSource> _sources = <String, MiniProgramSource>{};

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) {
    return _sourceFor(miniProgramId).loadManifest(miniProgramId);
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) {
    return _sourceFor(miniProgramId).loadScreen(
      miniProgramId: miniProgramId,
      version: version,
      screenId: screenId,
    );
  }

  @override
  void dispose() {
    for (final source in _sources.values) {
      if (source is DisposableMiniProgramSource) {
        source.dispose();
      }
    }
    _sources.clear();
  }

  MiniProgramSource _sourceFor(String miniProgramId) {
    final normalizedAppId = _normalizeAppId(miniProgramId);
    final endpoint = _endpoints[normalizedAppId];
    if (endpoint == null) {
      throw MiniProgramSourceException(
        message:
            'No MiniProgramEndpoint is configured for appId "$normalizedAppId".',
        errorCode: MiniProgramErrorCodes.endpointNotConfigured,
        details: <String, dynamic>{'miniProgramId': normalizedAppId},
      );
    }

    return _sources.putIfAbsent(
      normalizedAppId,
      () => _sourceFactory(
        appId: normalizedAppId,
        endpoint: endpoint,
        deliveryContext: _deliveryContext,
      ),
    );
  }

  static MiniProgramSource _defaultSourceFactory({
    required String appId,
    required MiniProgramEndpoint endpoint,
    required MiniProgramDeliveryContext deliveryContext,
  }) {
    return HttpMiniProgramSource.fromDeliveryContext(
      apiBaseUri: endpoint.apiBaseUri,
      deliveryContext: deliveryContext,
      accessKey: _normalizeAccessKey(endpoint.accessKey, appId),
      headers: endpoint.headers,
      requestTimeout: endpoint.requestTimeout,
      enableLocalLoopbackFallback: endpoint.enableLocalLoopbackFallback,
    );
  }

  static Map<String, MiniProgramEndpoint> _normalizeEndpoints(
    Map<String, MiniProgramEndpoint> endpoints,
  ) {
    final normalized = <String, MiniProgramEndpoint>{};
    for (final entry in endpoints.entries) {
      final appId = _normalizeAppId(entry.key);
      if (normalized.containsKey(appId)) {
        throw ArgumentError.value(
          endpoints,
          'endpoints',
          'Duplicate mini-program endpoint for appId "$appId".',
        );
      }
      _normalizeAccessKey(entry.value.accessKey, appId);
      normalized[appId] = entry.value;
    }
    return normalized;
  }

  static String _normalizeAppId(String rawAppId) {
    final appId = rawAppId.trim();
    if (appId.isEmpty) {
      throw ArgumentError.value(rawAppId, 'appId', 'appId must not be blank.');
    }
    return appId;
  }

  static String? _normalizeAccessKey(String? rawAccessKey, String appId) {
    if (rawAccessKey == null) {
      return null;
    }
    final accessKey = rawAccessKey.trim();
    if (accessKey.isEmpty) {
      throw ArgumentError.value(
        rawAccessKey,
        'accessKey',
        'MiniProgram access key for appId "$appId" must not be blank.',
      );
    }
    return accessKey;
  }
}
