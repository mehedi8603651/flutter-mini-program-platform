import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'mini_program_source_exception.dart';

/// Lightweight catalog of published mini-programs exposed by backend discovery.
class PublishedMiniProgramCatalog {
  const PublishedMiniProgramCatalog({
    required this.entries,
    this.traceId,
  });

  final List<PublishedMiniProgramSummary> entries;
  final String? traceId;
}

/// User-facing backend summary for one published mini-program.
class PublishedMiniProgramSummary {
  const PublishedMiniProgramSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.entry,
    required this.resolvedVersion,
    required this.requiredCapabilities,
    this.selectionMode,
    this.decisionReason,
    this.matchedRuleId,
  });

  factory PublishedMiniProgramSummary.fromJson(Map<String, dynamic> json) {
    final rawRequiredCapabilities =
        json['requiredCapabilities'] as List<dynamic>? ?? const [];

    return PublishedMiniProgramSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      entry: json['entry'] as String,
      resolvedVersion: json['resolvedVersion'] as String,
      requiredCapabilities: rawRequiredCapabilities
          .map((value) => _parseCapability(value.toString()))
          .toList(growable: false),
      selectionMode: json['selectionMode']?.toString(),
      decisionReason: json['decisionReason']?.toString(),
      matchedRuleId: json['matchedRuleId']?.toString(),
    );
  }

  final String id;
  final String title;
  final String description;
  final String entry;
  final String resolvedVersion;
  final List<Capability> requiredCapabilities;
  final String? selectionMode;
  final String? decisionReason;
  final String? matchedRuleId;
}

/// HTTP-backed client for the backend discovery catalog.
class PublishedMiniProgramCatalogClient {
  PublishedMiniProgramCatalogClient({
    required this.apiBaseUri,
    this.queryParameters = const <String, String>{},
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri apiBaseUri;
  final Map<String, String> queryParameters;
  final http.Client _client;

  Future<PublishedMiniProgramCatalog> listAvailableMiniPrograms() async {
    final uri = _resolve(
      'discovery/mini-programs.json',
      queryParameters: queryParameters,
    );

    late final http.Response response;
    try {
      response = await _client.get(uri);
    } catch (error) {
      throw MiniProgramSourceException(
        message:
            'Failed to reach the mini-program backend while loading the discovery catalog.',
        errorCode: MiniProgramErrorCodes.backendUnreachable,
        details: <String, dynamic>{
          'uri': uri.toString(),
          'resourceLabel': 'mini_program_catalog',
          'transportError': error.toString(),
        },
      );
    }

    if (response.statusCode != 200) {
      throw _buildSourceException(uri: uri, response: response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Expected a JSON object for mini-program catalog at "$uri".',
        response.body,
      );
    }

    final rawEntries = decoded['entries'] as List<dynamic>? ?? const [];
    final entries = rawEntries
        .map(
          (value) => PublishedMiniProgramSummary.fromJson(
            (value as Map).map(
              (key, entryValue) => MapEntry(key.toString(), entryValue),
            ),
          ),
        )
        .toList(growable: false);

    return PublishedMiniProgramCatalog(
      entries: entries,
      traceId:
          decoded['traceId']?.toString() ??
          response.headers['x-backend-trace-id'],
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

  MiniProgramSourceException _buildSourceException({
    required Uri uri,
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
        'Failed to load mini-program catalog from "$uri" (HTTP ${response.statusCode}).';

    return MiniProgramSourceException(
      message: message,
      errorCode: errorCode,
      statusCode: response.statusCode,
      details: <String, dynamic>{
        'uri': uri.toString(),
        'resourceLabel': 'mini_program_catalog',
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
      // Fall back to a generic error when the backend body is malformed.
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

    final rawDetails =
        decodedBody?['details'] ?? _tryReadNestedError(decodedBody)?['details'];
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

Capability _parseCapability(String wireValue) {
  for (final capability in Capability.values) {
    if (capability.wireValue == wireValue) {
      return capability;
    }
  }

  throw FormatException('Unsupported capability "$wireValue".');
}
