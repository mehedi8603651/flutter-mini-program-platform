import 'dart:convert';
import 'dart:io';

void writePreviewBaseHeaders(HttpResponse response) {
  response.headers
    ..set(HttpHeaders.cacheControlHeader, 'no-store')
    ..set(HttpHeaders.accessControlAllowOriginHeader, '*')
    ..set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, OPTIONS')
    ..set(HttpHeaders.accessControlAllowHeadersHeader, 'Content-Type');
}

Future<void> writePreviewJson(
  HttpResponse response,
  int statusCode,
  Map<String, Object?> body,
) async {
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  await response.close();
}
