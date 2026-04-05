import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'mini_program_source.dart';
import 'mini_program_source_exception.dart';

typedef ManifestRequestQueryParametersBuilder =
    Map<String, String> Function(String miniProgramId);

/// HTTP-backed source that loads manifests and screen JSON from backend paths.
class HttpMiniProgramSource implements MiniProgramSource {
  HttpMiniProgramSource({
    required this.apiBaseUri,
    this.manifestRequestQueryParametersBuilder,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri apiBaseUri;
  final ManifestRequestQueryParametersBuilder?
  manifestRequestQueryParametersBuilder;
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
    final response = await _client.get(uri);

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
    final errorCode = decodedBody?['errorCode']?.toString();
    final message =
        decodedBody?['message']?.toString() ??
        'Failed to load $resourceLabel from "$uri" (HTTP ${response.statusCode}).';

    return MiniProgramSourceException(
      message: message,
      errorCode: errorCode,
      statusCode: response.statusCode,
      details: <String, dynamic>{
        'uri': uri.toString(),
        'resourceLabel': resourceLabel,
        'statusCode': response.statusCode,
        if (decodedBody != null) ...decodedBody,
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
}
