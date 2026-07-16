part of '../../http_mini_program_source.dart';

extension _HttpMiniProgramSourceLoading on HttpMiniProgramSource {
  Future<Map<String, dynamic>> _loadJsonObject(
    Uri uri, {
    required String resourceLabel,
  }) async {
    final candidateUris = _candidateUris(uri);
    MiniProgramSourceException? lastTransportException;
    for (final candidateUri in candidateUris) {
      try {
        return await _loadSingleJsonObject(
          candidateUri,
          resourceLabel: resourceLabel,
          attemptedUris: candidateUris,
        );
      } on _TransportSourceException catch (error) {
        lastTransportException = error.sourceException;
      }
    }

    if (lastTransportException != null) {
      throw lastTransportException;
    }

    throw MiniProgramSourceException(
      message:
          'Failed to reach the mini-program backend while loading $resourceLabel.',
      errorCode: MiniProgramErrorCodes.backendUnreachable,
      details: <String, dynamic>{
        'uri': uri.toString(),
        'resourceLabel': resourceLabel,
      },
    );
  }

  Future<Map<String, dynamic>> _loadSingleJsonObject(
    Uri uri, {
    required String resourceLabel,
    required List<Uri> attemptedUris,
  }) async {
    final responseBytes = await _loadSingleBytes(
      uri,
      resourceLabel: resourceLabel,
      attemptedUris: attemptedUris,
    );
    final responseBody = utf8.decode(responseBytes);
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Expected a JSON object for $resourceLabel at "$uri".',
        responseBody,
      );
    }

    return decoded;
  }

  Future<List<int>> _loadBytes(Uri uri, {required String resourceLabel}) async {
    final candidateUris = _candidateUris(uri);
    MiniProgramSourceException? lastTransportException;
    for (final candidateUri in candidateUris) {
      try {
        return await _loadSingleBytes(
          candidateUri,
          resourceLabel: resourceLabel,
          attemptedUris: candidateUris,
        );
      } on _TransportSourceException catch (error) {
        lastTransportException = error.sourceException;
      }
    }
    if (lastTransportException != null) {
      throw lastTransportException;
    }
    throw MiniProgramSourceException(
      message:
          'Failed to reach the mini-program backend while loading $resourceLabel.',
      errorCode: MiniProgramErrorCodes.backendUnreachable,
      details: <String, dynamic>{
        'uri': uri.toString(),
        'resourceLabel': resourceLabel,
      },
    );
  }
}
