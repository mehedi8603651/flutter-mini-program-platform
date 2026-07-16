part of '../published_mini_program_catalog_client.dart';

extension _PublishedCatalogParsing on PublishedMiniProgramCatalogClient {
  PublishedMiniProgramCatalog _parseCatalogResponse({
    required Uri uri,
    required http.Response response,
  }) {
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
}
