import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../models.dart';
import 'headers.dart';

Uri resolvePublisherBackendSmokeUri(Uri baseUri, String relativeEndpoint) {
  final baseUrl = baseUri.toString();
  final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
  return Uri.parse(normalizedBaseUrl).resolve(relativeEndpoint);
}

Future<http.Response> sendPublisherBackendSmokeRequest({
  required http.Client client,
  required PublisherBackendContractSmokeRequest request,
  required MiniProgramPublisherBackendSmokeCase smokeCase,
  required Uri uri,
}) {
  final headers = publisherBackendSmokeHeaders(request, smokeCase);
  final body = smokeCase.body.isEmpty ? null : jsonEncode(smokeCase.body);
  final effectiveHeaders = smokeCase.method == 'GET'
      ? headers
      : <String, String>{'content-type': 'application/json', ...headers};
  return switch (smokeCase.method) {
    'GET' => client.get(uri, headers: effectiveHeaders),
    'POST' => client.post(uri, headers: effectiveHeaders, body: body),
    'PUT' => client.put(uri, headers: effectiveHeaders, body: body),
    'PATCH' => client.patch(uri, headers: effectiveHeaders, body: body),
    'DELETE' => client.delete(uri, headers: effectiveHeaders, body: body),
    _ => client.get(uri, headers: effectiveHeaders),
  };
}
