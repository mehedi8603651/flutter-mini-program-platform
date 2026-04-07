import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'mini_program_delivery_context.dart';
import 'mini_program_source.dart';
import 'mini_program_source_exception.dart';

typedef ManifestRequestQueryParametersBuilder =
    Map<String, String> Function(String miniProgramId);

/// HTTP-backed source that loads manifests and screen JSON from backend paths.
class HttpMiniProgramSource implements MiniProgramSource {
  HttpMiniProgramSource({
    required this.apiBaseUri,
    this.manifestRequestQueryParametersBuilder,
    this.requestTimeout = const Duration(seconds: 5),
    http.Client? client,
  }) : _client = client ?? http.Client();

  factory HttpMiniProgramSource.fromDeliveryContext({
    required Uri apiBaseUri,
    required MiniProgramDeliveryContext deliveryContext,
    Duration requestTimeout = const Duration(seconds: 5),
    http.Client? client,
  }) {
    return HttpMiniProgramSource(
      apiBaseUri: apiBaseUri,
      manifestRequestQueryParametersBuilder: (_) =>
          deliveryContext.toQueryParameters(),
      requestTimeout: requestTimeout,
      client: client,
    );
  }

  final Uri apiBaseUri;
  final ManifestRequestQueryParametersBuilder?
  manifestRequestQueryParametersBuilder;
  final Duration requestTimeout;
  final http.Client _client;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    final queryParameters = manifestRequestQueryParametersBuilder?.call(
      miniProgramId,
    );
    final manifestJson = await _loadJsonObject(
      _resolve(
        'manifests/$miniProgramId/latest.json',
        queryParameters: queryParameters,
      ),
      resourceLabel: 'manifest',
    );
    return MiniProgramManifest.fromJson(manifestJson);
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    return _loadJsonObject(
      _resolve('screens/$miniProgramId/$version/$screenId.json'),
      resourceLabel: 'screen',
    );
  }

  Uri _resolve(String relativePath, {Map<String, String>? queryParameters}) {
    final baseUrl = apiBaseUri.toString();
    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final uri = Uri.parse(normalizedBaseUrl).resolve(relativePath);
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> _loadJsonObject(
    Uri uri, {
    required String resourceLabel,
  }) async {
    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(requestTimeout);
    } on TimeoutException {
      throw MiniProgramSourceException(
        message:
            'Timed out while loading $resourceLabel from the mini-program backend.',
        errorCode: MiniProgramErrorCodes.backendUnreachable,
        details: <String, dynamic>{
          'uri': uri.toString(),
          'resourceLabel': resourceLabel,
          'requestTimeoutMs': requestTimeout.inMilliseconds,
          'transportError': 'timeout',
        },
      );
    } catch (error) {
      throw MiniProgramSourceException(
        message:
            'Failed to reach the mini-program backend while loading $resourceLabel.',
        errorCode: MiniProgramErrorCodes.backendUnreachable,
        details: <String, dynamic>{
          'uri': uri.toString(),
          'resourceLabel': resourceLabel,
          'transportError': error.toString(),
        },
      );
    }

    if (response.statusCode != 200) {
      throw _buildSourceException(
        uri: uri,
        resourceLabel: resourceLabel,
        response: response,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Expected a JSON object for $resourceLabel at "$uri".',
        response.body,
      );
    }

    return decoded;
  }

  MiniProgramSourceException _buildSourceException({
    required Uri uri,
    required String resourceLabel,
    required http.Response response,
  }) {
    final decodedBody = _tryDecodeJsonObject(response.body);
    final nestedError = _tryReadNestedError(decodedBody);
    final errorCode =
        decodedBody?['errorCode']?.toString() ??
        nestedError?['code']?.toString();
    final message =
        decodedBody?['message']?.toString() ??
        nestedError?['message']?.toString() ??
        'Failed to load $resourceLabel from "$uri" (HTTP ${response.statusCode}).';

    return MiniProgramSourceException(
      message: message,
      errorCode: errorCode,
      statusCode: response.statusCode,
      details: <String, dynamic>{
        'uri': uri.toString(),
        'resourceLabel': resourceLabel,
        'statusCode': response.statusCode,
        ..._extractBackendDetails(decodedBody, response.headers),
      },
    );
  }

  Map<String, dynamic>? _tryDecodeJsonObject(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore non-JSON or malformed backend error bodies and fall back
      // to the generic transport message.
    }

    return null;
  }

  Map<String, dynamic> _extractBackendDetails(
    Map<String, dynamic>? decodedBody,
    Map<String, String> responseHeaders,
  ) {
    final details = <String, dynamic>{};

    final responseType = decodedBody?['responseType']?.toString();
    if (responseType != null && responseType.isNotEmpty) {
      details['responseType'] = responseType;
    }

    final traceId =
        decodedBody?['traceId']?.toString() ??
        responseHeaders['x-backend-trace-id'];
    if (traceId != null && traceId.isNotEmpty) {
      details['traceId'] = traceId;
    }

    final selectionMode =
        decodedBody?['selectionMode']?.toString() ??
        responseHeaders['x-mini-program-selection-mode'];
    if (selectionMode != null && selectionMode.isNotEmpty) {
      details['selectionMode'] = selectionMode;
    }

    final decisionReason =
        decodedBody?['decisionReason']?.toString() ??
        responseHeaders['x-mini-program-decision-reason'];
    if (decisionReason != null && decisionReason.isNotEmpty) {
      details['decisionReason'] = decisionReason;
    }

    final matchedRuleId =
        decodedBody?['matchedRuleId']?.toString() ??
        responseHeaders['x-mini-program-matched-rule-id'];
    if (matchedRuleId != null && matchedRuleId.isNotEmpty) {
      details['matchedRuleId'] = matchedRuleId;
    }

    final resolvedVersion =
        decodedBody?['resolvedVersion']?.toString() ??
        responseHeaders['x-mini-program-version'];
    if (resolvedVersion != null && resolvedVersion.isNotEmpty) {
      details['resolvedVersion'] = resolvedVersion;
    }

    if (decodedBody == null) {
      return details;
    }

    final rawDetails = decodedBody['details'] ?? _tryReadNestedError(decodedBody)?['details'];
    if (rawDetails is Map<String, dynamic>) {
      details.addAll(rawDetails);
      return details;
    }

    if (rawDetails is Map) {
      details.addAll(
        rawDetails.map((key, value) => MapEntry(key.toString(), value)),
      );
      return details;
    }

    if (rawDetails != null) {
      details['backendDetails'] = rawDetails;
    }

    return details;
  }

  Map<String, dynamic>? _tryReadNestedError(Map<String, dynamic>? decodedBody) {
    if (decodedBody == null) {
      return null;
    }

    final rawError = decodedBody['error'];
    if (rawError is Map<String, dynamic>) {
      return rawError;
    }
    if (rawError is Map) {
      return rawError.map((key, value) => MapEntry(key.toString(), value));
    }

    return null;
  }
}
