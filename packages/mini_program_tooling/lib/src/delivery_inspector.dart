import 'dart:convert';

import 'package:http/http.dart' as http;

class DeliveryInspectionRequest {
  const DeliveryInspectionRequest({
    required this.miniProgramId,
    this.hostApp,
    this.sdkVersion,
    this.hostVersion,
    this.platform,
    this.locale,
    this.tenantId,
    this.pinnedVersion,
    this.capabilities = const <String>{},
  });

  final String miniProgramId;
  final String? hostApp;
  final String? sdkVersion;
  final String? hostVersion;
  final String? platform;
  final String? locale;
  final String? tenantId;
  final String? pinnedVersion;
  final Set<String> capabilities;

  Uri buildUri(Uri apiBaseUri) {
    final baseUrl = apiBaseUri.toString();
    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final resolved = Uri.parse(
      normalizedBaseUrl,
    ).resolve('debug/manifests/$miniProgramId/decision');
    final queryParameters = <String, String>{
      if (_hasValue(hostApp)) 'hostApp': hostApp!,
      if (_hasValue(sdkVersion)) 'sdkVersion': sdkVersion!,
      if (_hasValue(hostVersion)) 'hostVersion': hostVersion!,
      if (_hasValue(platform)) 'platform': platform!,
      if (_hasValue(locale)) 'locale': locale!,
      if (_hasValue(tenantId)) 'tenantId': tenantId!,
      if (_hasValue(pinnedVersion)) 'pinnedVersion': pinnedVersion!,
      if (capabilities.isNotEmpty)
        'capabilities': (capabilities.toList()..sort()).join(','),
    };

    if (queryParameters.isEmpty) {
      return resolved;
    }

    return resolved.replace(queryParameters: queryParameters);
  }

  static bool _hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;
}

class DeliveryInspectionResponse {
  const DeliveryInspectionResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });

  final int statusCode;
  final Map<String, dynamic> body;
  final Map<String, String> headers;

  String? get traceId =>
      body['traceId']?.toString() ?? headers['x-backend-trace-id'];
}

class DeliveryInspectorClient {
  DeliveryInspectorClient({required this.apiBaseUri, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final Uri apiBaseUri;
  final http.Client _httpClient;

  Future<DeliveryInspectionResponse> inspect(
    DeliveryInspectionRequest request, {
    String? requestId,
  }) async {
    final headers = <String, String>{
      if (_hasValue(requestId)) 'x-request-id': requestId!.trim(),
    };
    final response = await _httpClient.get(
      request.buildUri(apiBaseUri),
      headers: headers,
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw FormatException(
        'Expected a JSON object from the delivery inspection route.',
        response.body,
      );
    }

    return DeliveryInspectionResponse(
      statusCode: response.statusCode,
      body: decoded.map((key, value) => MapEntry(key.toString(), value)),
      headers: response.headers,
    );
  }

  static bool _hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;
}

String formatDeliveryInspectionResponse(DeliveryInspectionResponse response) {
  final body = response.body;
  final lines = <String>[
    'Mini-program: ${body['miniProgramId'] ?? 'unknown'}',
    'Outcome: ${body['outcome'] ?? 'unknown'} (simulated HTTP ${body['simulatedStatusCode'] ?? response.statusCode})',
    if (response.traceId != null) 'Trace ID: ${response.traceId}',
  ];

  final decision = _asMap(body['decision']);
  if (decision != null) {
    lines.add('Decision:');
    lines.add('  selectionMode: ${decision['selectionMode']}');
    lines.add('  decisionReason: ${decision['decisionReason']}');
    lines.add('  resolvedVersion: ${decision['resolvedVersion']}');
    if (decision['declaredDefaultVersion'] != null) {
      lines.add(
        '  declaredDefaultVersion: ${decision['declaredDefaultVersion']}',
      );
    }
    if (decision['matchedRuleId'] != null) {
      lines.add('  matchedRuleId: ${decision['matchedRuleId']}');
    }
    if (decision['requestedPinnedVersion'] != null) {
      lines.add(
        '  requestedPinnedVersion: ${decision['requestedPinnedVersion']}',
      );
    }
  }

  final rejection = _asMap(body['rejection']);
  if (rejection != null) {
    lines.add('Rejection:');
    lines.add('  errorCode: ${rejection['errorCode']}');
    lines.add('  message: ${rejection['message']}');
  }

  final manifestSummary = _asMap(body['manifestSummary']);
  if (manifestSummary != null) {
    lines.add('Manifest summary:');
    lines.add('  version: ${manifestSummary['version']}');
    lines.add('  entry: ${manifestSummary['entry']}');
    lines.add('  sdkVersionRange: ${manifestSummary['sdkVersionRange']}');
    final requiredCapabilities = _asList(
      manifestSummary['requiredCapabilities'],
    );
    if (requiredCapabilities.isNotEmpty) {
      lines.add('  requiredCapabilities: ${requiredCapabilities.join(', ')}');
    }
  }

  final rollout = _asMap(body['rollout']);
  if (rollout != null) {
    lines.add('Rollout:');
    if (rollout['type'] != null) {
      lines.add('  type: ${rollout['type']}');
    }
    if (rollout['defaultVersion'] != null) {
      lines.add('  defaultVersion: ${rollout['defaultVersion']}');
    }
    final rules = _asListOfMaps(rollout['rules']);
    for (final rule in rules) {
      final id = rule['id'] ?? '<unnamed>';
      final version = rule['version'] ?? '?';
      final matchStatus = rule['matches'] == true ? 'match' : 'skip';
      final mismatches = _asList(rule['mismatchReasons']);
      final mismatchSuffix = mismatches.isEmpty
          ? ''
          : ' (${mismatches.join(', ')})';
      lines.add('  [$matchStatus] $id -> $version$mismatchSuffix');
    }
  }

  final capabilityPolicy = _asMap(body['capabilityPolicy']);
  if (capabilityPolicy != null) {
    lines.add('Capability policy:');
    lines.add(
      '  requireContextForLatest: ${capabilityPolicy['requireContextForLatest']}',
    );
    lines.add(
      '  enforceManifestCapabilities: ${capabilityPolicy['enforceManifestCapabilities']}',
    );
    final requiredParams = _asList(capabilityPolicy['requiredQueryParameters']);
    if (requiredParams.isNotEmpty) {
      lines.add('  requiredQueryParameters: ${requiredParams.join(', ')}');
    }
  }

  final deliveryContext = _asMap(body['deliveryContext']);
  if (deliveryContext != null) {
    lines.add('Delivery context:');
    for (final entry in deliveryContext.entries) {
      if (entry.value == null) {
        continue;
      }
      if (entry.value is List && (entry.value as List).isEmpty) {
        continue;
      }
      lines.add('  ${entry.key}: ${_formatValue(entry.value)}');
    }
  }

  return lines.join('\n');
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

List<String> _asList(Object? value) {
  if (value is Iterable) {
    return value.map((item) => item.toString()).toList();
  }
  return const <String>[];
}

List<Map<String, dynamic>> _asListOfMaps(Object? value) {
  if (value is! Iterable) {
    return const <Map<String, dynamic>>[];
  }

  return value
      .map(_asMap)
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
}

String _formatValue(Object? value) {
  if (value is Iterable) {
    return value.map((item) => item.toString()).join(', ');
  }
  return value.toString();
}
