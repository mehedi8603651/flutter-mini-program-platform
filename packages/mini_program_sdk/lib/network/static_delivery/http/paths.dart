part of '../../http_mini_program_source.dart';

extension _HttpMiniProgramSourcePaths on HttpMiniProgramSource {
  Uri _resolve(String relativePath, {Map<String, String>? queryParameters}) {
    final baseUrl = apiBaseUri.toString();
    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final uri = Uri.parse(normalizedBaseUrl).resolve(relativePath);
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: queryParameters);
  }
}
