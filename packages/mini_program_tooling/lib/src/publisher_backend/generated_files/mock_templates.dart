class MockPublisherBackendTemplates {
  const MockPublisherBackendTemplates._();

  static String pubspec(String appId) =>
      '''
name: ${appId}_mock_backend
description: Local mock Publisher API for $appId.
publish_to: none

environment:
  sdk: '>=3.9.0 <4.0.0'
''';

  static String readme(String appId, String title) =>
      '''
# $title mock Publisher API

This is a local-only mock Publisher API for mini-program data calls. It is not
the static artifact endpoint and it does not contain production secrets.

Run it from the mini-program root:

```powershell
miniprogram publisher-backend run --port 9090
```

Useful base URLs:

- desktop/web host: `http://127.0.0.1:9090/`
- Android emulator host: `http://10.0.2.2:9090/`

Routes:

- `GET /health`
- `GET /home/bootstrap`
- `GET /coupons/list`
- `GET /coupons/page?limit=20&cursor=<couponId>`
- `GET /auth/session`
- `POST /coupon/redeem`

Connect a host endpoint with:

```powershell
miniprogram host endpoint add $appId `
  --artifact-base-url <public-static-artifact-url> `
  --publisher-api-url http://127.0.0.1:9090/
```

Production provider SDKs, database clients, payment clients, credentials, and
business rules should live on your Publisher API server, not in the Flutter
host app or mini_program_sdk.
''';

  static String serverSource() => r'''
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final host = _option(arguments, 'host') ?? '0.0.0.0';
  final port = int.tryParse(_option(arguments, 'port') ?? '9090') ?? 9090;
  final dataRoot = Directory(
    _option(arguments, 'data-root') ??
        '${File.fromUri(Platform.script).parent.parent.path}${Platform.pathSeparator}data',
  );
  final server = await HttpServer.bind(host, port);
  stdout.writeln('Mock Publisher API listening on http://$host:$port');
  stdout.writeln('Data root: ${dataRoot.path}');
  await for (final request in server) {
    await _handleRequest(request, dataRoot);
  }
}

Future<void> _handleRequest(HttpRequest request, Directory dataRoot) async {
  _writeCorsHeaders(request.response);
  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }

  final path = request.uri.path.replaceAll(RegExp(r'/+$'), '');
  if (request.method == 'GET' && path == '/health') {
    await _writeJson(request.response, <String, Object?>{
      'status': 'ok',
      'service': 'mini_program_mock_publisher_backend',
      'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    });
    return;
  }
  if (request.method == 'GET' && path == '/home/bootstrap') {
    await _writeDataFile(request.response, dataRoot, 'home_bootstrap.json');
    return;
  }
  if (request.method == 'GET' && path == '/coupons/list') {
    await _writeDataFile(request.response, dataRoot, 'coupons_list.json');
    return;
  }
  if (request.method == 'GET' && path == '/coupons/page') {
    await _writePagedCoupons(request.response, dataRoot, request.uri);
    return;
  }
  if (request.method == 'GET' && path == '/auth/session') {
    await _writeDataFile(request.response, dataRoot, 'session.json');
    return;
  }
  if (request.method == 'POST' && path == '/coupon/redeem') {
    final body = await utf8.decoder.bind(request).join();
    final decoded = body.trim().isEmpty ? <String, Object?>{} : jsonDecode(body);
    await _writeJson(request.response, <String, Object?>{
      'status': 'redeemed',
      'couponId': decoded is Map ? decoded['couponId']?.toString() : null,
      'message': 'Mock redeem succeeded. Replace this route on your real backend.',
    });
    return;
  }

  request.response.statusCode = HttpStatus.notFound;
  await _writeJson(request.response, <String, Object?>{
    'errorCode': 'not_found',
    'message': 'No mock backend route matches ${request.uri.path}.',
  });
}

Future<void> _writeDataFile(
  HttpResponse response,
  Directory dataRoot,
  String fileName,
) async {
  final file = File('${dataRoot.path}${Platform.pathSeparator}$fileName');
  if (!await file.exists()) {
    response.statusCode = HttpStatus.notFound;
    await _writeJson(response, <String, Object?>{
      'errorCode': 'mock_data_missing',
      'message': 'Mock data file was not found: $fileName',
    });
    return;
  }
  response.headers.contentType = ContentType.json;
  await response.addStream(file.openRead());
  await response.close();
}

Future<void> _writePagedCoupons(
  HttpResponse response,
  Directory dataRoot,
  Uri uri,
) async {
  final file = File('${dataRoot.path}${Platform.pathSeparator}coupons_list.json');
  if (!await file.exists()) {
    response.statusCode = HttpStatus.notFound;
    await _writeJson(response, <String, Object?>{
      'errorCode': 'mock_data_missing',
      'message': 'Mock data file was not found: coupons_list.json',
    });
    return;
  }
  final decoded = jsonDecode(await file.readAsString());
  final coupons = decoded is Map && decoded['coupons'] is List
      ? List<Object?>.from(decoded['coupons'] as List)
      : <Object?>[];
  await _writeJson(response, _pageItems(coupons, uri));
}

Map<String, Object?> _pageItems(List<Object?> items, Uri uri) {
  final limit = _boundedLimit(uri.queryParameters['limit'], 20, 100);
  final cursor = uri.queryParameters['cursor']?.trim() ?? '';
  final startIndex = cursor.isEmpty ? 0 : _cursorStartIndex(items, cursor);
  final page = items.skip(startIndex).take(limit).toList();
  final nextIndex = startIndex + page.length;
  final hasMore = nextIndex < items.length;
  return <String, Object?>{
    'items': page,
    'nextCursor': hasMore && page.isNotEmpty
        ? _cursorFor(page.last, nextIndex)
        : null,
    'hasMore': hasMore,
  };
}

int _boundedLimit(String? value, int defaultLimit, int maxLimit) {
  final parsed = int.tryParse(value ?? '');
  if (parsed == null || parsed < 1) {
    return defaultLimit;
  }
  return parsed > maxLimit ? maxLimit : parsed;
}

int _cursorStartIndex(List<Object?> items, String cursor) {
  final index = items.indexWhere((item) {
    return item is Map && item['id']?.toString() == cursor;
  });
  if (index >= 0) {
    return index + 1;
  }
  final numeric = int.tryParse(cursor);
  return numeric != null && numeric > 0 ? numeric : 0;
}

String _cursorFor(Object? item, int fallbackIndex) {
  if (item is Map) {
    final id = item['id']?.toString() ?? '';
    if (id.isNotEmpty) {
      return id;
    }
  }
  return fallbackIndex.toString();
}

Future<void> _writeJson(HttpResponse response, Object? body) async {
  response.headers.contentType = ContentType.json;
  response.write(const JsonEncoder.withIndent('  ').convert(body));
  await response.close();
}

void _writeCorsHeaders(HttpResponse response) {
  response.headers.set('access-control-allow-origin', '*');
  response.headers.set(
    'access-control-allow-methods',
    'GET, POST, OPTIONS',
  );
  response.headers.set(
    'access-control-allow-headers',
    'content-type, x-mini-program-access-key, x-mini-program-app-id, x-mini-program-host-app, x-mini-program-host-version, x-mini-program-id, x-mini-program-sdk-version, x-mini-program-platform, x-mini-program-locale',
  );
}

String? _option(List<String> arguments, String name) {
  final prefix = '--$name=';
  for (var i = 0; i < arguments.length; i++) {
    final value = arguments[i];
    if (value.startsWith(prefix)) {
      return value.substring(prefix.length);
    }
    if (value == '--$name' && i + 1 < arguments.length) {
      return arguments[i + 1];
    }
  }
  return null;
}
''';
}
