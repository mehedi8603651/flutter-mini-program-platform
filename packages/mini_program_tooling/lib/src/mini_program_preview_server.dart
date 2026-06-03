import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'mini_program_builder.dart';

typedef PreviewHttpServerBinder =
    Future<HttpServer> Function(InternetAddress address, int port);

class MiniProgramPreviewBundle {
  const MiniProgramPreviewBundle({
    required this.miniProgramId,
    required this.title,
    required this.manifestJson,
    required this.screenJsonById,
    this.assetRootPath,
  });

  final String miniProgramId;
  final String title;
  final Map<String, dynamic> manifestJson;
  final Map<String, Map<String, dynamic>> screenJsonById;
  final String? assetRootPath;
}

abstract final class MiniProgramPreviewStates {
  static const String ready = 'ready';
  static const String building = 'building';
  static const String buildFailed = 'build_failed';
}

class MiniProgramPreviewException implements Exception {
  const MiniProgramPreviewException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MiniProgramPreviewBundleLoader {
  const MiniProgramPreviewBundleLoader();

  Future<MiniProgramPreviewBundle> load(
    MiniProgramBuildResult buildResult,
  ) async {
    final manifestPath = p.join(
      buildResult.miniProgramRootPath,
      'manifest.json',
    );
    final manifestFile = File(manifestPath);
    if (!await manifestFile.exists()) {
      throw MiniProgramPreviewException(
        'Preview manifest was not found: $manifestPath',
      );
    }

    final manifestJson = await _readJsonMap(
      manifestFile,
      label: 'preview manifest',
    );
    final title = _resolveTitle(
      manifestJson: manifestJson,
      miniProgramId: buildResult.miniProgramId,
    );

    final screensDirectory = Directory(buildResult.screensDirectoryPath);
    if (!await screensDirectory.exists()) {
      throw MiniProgramPreviewException(
        'Preview screens directory was not found: '
        '${buildResult.screensDirectoryPath}',
      );
    }

    final screenJsonById = <String, Map<String, dynamic>>{};
    final files = await screensDirectory
        .list(followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.json')
        .toList();
    files.sort((left, right) => left.path.compareTo(right.path));

    for (final file in files) {
      final screenId = p.basenameWithoutExtension(file.path);
      screenJsonById[screenId] = await _readJsonMap(
        file,
        label: 'preview screen',
      );
    }

    if (screenJsonById.isEmpty) {
      throw MiniProgramPreviewException(
        'Preview build did not produce any screen JSON files under '
        '${buildResult.screensDirectoryPath}.',
      );
    }

    final assetRootPath = p.join(buildResult.miniProgramRootPath, 'assets');
    final hasAssetRoot = await Directory(assetRootPath).exists();

    return MiniProgramPreviewBundle(
      miniProgramId: buildResult.miniProgramId,
      title: title,
      manifestJson: manifestJson,
      screenJsonById: screenJsonById,
      assetRootPath: hasAssetRoot ? assetRootPath : null,
    );
  }

  Future<Map<String, dynamic>> _readJsonMap(
    File file, {
    required String label,
  }) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        throw MiniProgramPreviewException(
          '$label is not a JSON object: ${file.path}',
        );
      }
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } on FormatException catch (error) {
      throw MiniProgramPreviewException(
        'Failed to parse $label JSON: ${file.path}\n${error.message}',
      );
    } on FileSystemException catch (error) {
      throw MiniProgramPreviewException(
        'Failed to read $label file: ${file.path}\n$error',
      );
    }
  }

  String _resolveTitle({
    required Map<String, dynamic> manifestJson,
    required String miniProgramId,
  }) {
    final rawTitle = '${manifestJson['title'] ?? ''}'.trim();
    if (rawTitle.isNotEmpty) {
      return rawTitle;
    }

    final words = miniProgramId
        .split('_')
        .where((segment) => segment.isNotEmpty)
        .map(
          (segment) =>
              '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
        );
    return words.isEmpty ? miniProgramId : words.join(' ');
  }
}

class MiniProgramPreviewServer {
  MiniProgramPreviewServer({
    PreviewHttpServerBinder serverBinder = _defaultServerBinder,
    InternetAddress? bindAddress,
    String publicHost = '127.0.0.1',
  }) : _serverBinder = serverBinder,
       _bindAddress = bindAddress ?? InternetAddress.loopbackIPv4,
       _publicHost = publicHost;

  final PreviewHttpServerBinder _serverBinder;
  final InternetAddress _bindAddress;
  String _publicHost;

  HttpServer? _server;
  MiniProgramPreviewBundle? _bundle;
  int _buildVersion = 0;
  String _state = MiniProgramPreviewStates.ready;
  String? _lastBuildError;

  int get buildVersion => _buildVersion;

  void updatePublicHost(String publicHost) {
    final trimmedPublicHost = publicHost.trim();
    if (trimmedPublicHost.isEmpty) {
      throw const MiniProgramPreviewException(
        'Preview public host must not be blank.',
      );
    }
    _publicHost = trimmedPublicHost;
  }

  Uri get baseUri {
    final server = _server;
    if (server == null) {
      throw const MiniProgramPreviewException(
        'Preview server has not been started yet.',
      );
    }

    return Uri(
      scheme: 'http',
      host: _publicHost,
      port: server.port,
      path: 'preview/',
    );
  }

  Future<void> start({required MiniProgramPreviewBundle initialBundle}) async {
    if (_server != null) {
      throw const MiniProgramPreviewException(
        'Preview server is already running.',
      );
    }

    final server = await _serverBinder(_bindAddress, 0);
    _server = server;
    _bundle = initialBundle;
    _buildVersion = 1;
    _state = MiniProgramPreviewStates.ready;
    _lastBuildError = null;
    server.listen(_handleRequest);
  }

  void markBuilding() {
    _state = MiniProgramPreviewStates.building;
    _lastBuildError = null;
  }

  void applyBundle(MiniProgramPreviewBundle bundle) {
    _bundle = bundle;
    _buildVersion += 1;
    _state = MiniProgramPreviewStates.ready;
    _lastBuildError = null;
  }

  void markBuildFailed(String error) {
    _state = MiniProgramPreviewStates.buildFailed;
    _lastBuildError = error.trim().isEmpty ? 'Preview rebuild failed.' : error;
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    _bundle = null;
    _buildVersion = 0;
    _state = MiniProgramPreviewStates.ready;
    _lastBuildError = null;
    await server?.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      _writeBaseHeaders(request.response);

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }

      if (request.method != 'GET') {
        await _writeJson(
          request.response,
          HttpStatus.methodNotAllowed,
          <String, Object?>{
            'message': 'Preview server only supports GET requests.',
          },
        );
        return;
      }

      final segments = request.uri.pathSegments;
      if (segments.length == 2 &&
          segments[0] == 'preview' &&
          segments[1] == 'status.json') {
        await _writeJson(request.response, HttpStatus.ok, _statusBody());
        return;
      }

      final bundle = _bundle;
      if (bundle == null) {
        await _writeJson(
          request.response,
          HttpStatus.serviceUnavailable,
          <String, Object?>{'message': 'Preview bundle is not ready yet.'},
        );
        return;
      }

      if (segments.length == 2 &&
          segments[0] == 'preview' &&
          segments[1] == 'manifest.json') {
        await _writeJson(request.response, HttpStatus.ok, bundle.manifestJson);
        return;
      }

      if (segments.length >= 3 &&
          segments[0] == 'preview' &&
          segments[1] == 'screens') {
        final screenId = p.basenameWithoutExtension(
          segments.sublist(2).join('/'),
        );
        final screenJson = bundle.screenJsonById[screenId];
        if (screenJson == null) {
          await _writeJson(
            request.response,
            HttpStatus.notFound,
            <String, Object?>{
              'message': 'Preview screen was not found: $screenId',
            },
          );
          return;
        }

        await _writeJson(
          request.response,
          HttpStatus.ok,
          _rewriteScreenJson(screenJson, bundle: bundle),
        );
        return;
      }

      if (segments.length >= 3 &&
          segments[0] == 'preview' &&
          segments[1] == 'assets') {
        await _serveAsset(
          request,
          bundle: bundle,
          relativeSegments: segments.sublist(2),
        );
        return;
      }

      await _writeJson(request.response, HttpStatus.notFound, <String, Object?>{
        'message': 'Preview route not found: ${request.uri.path}',
      });
    } catch (error) {
      try {
        await _writeJson(
          request.response,
          HttpStatus.internalServerError,
          <String, Object?>{
            'message': 'Preview server error.',
            'details': '$error',
          },
        );
      } catch (_) {
        await request.response.close();
      }
    }
  }

  Map<String, Object?> _statusBody() {
    final bundle = _bundle;
    return <String, Object?>{
      'buildVersion': _buildVersion,
      'state': _state,
      'miniProgramId': bundle?.miniProgramId,
      'title': bundle?.title,
      if (_lastBuildError != null) 'lastBuildError': _lastBuildError,
    };
  }

  Future<void> _serveAsset(
    HttpRequest request, {
    required MiniProgramPreviewBundle bundle,
    required List<String> relativeSegments,
  }) async {
    final assetRootPath = bundle.assetRootPath;
    if (assetRootPath == null) {
      await _writeJson(request.response, HttpStatus.notFound, <String, Object?>{
        'message': 'Preview mini-program does not define an assets/ root.',
      });
      return;
    }

    final decodedSegments = relativeSegments
        .map(Uri.decodeComponent)
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (decodedSegments.isEmpty) {
      await _writeJson(
        request.response,
        HttpStatus.badRequest,
        <String, Object?>{'message': 'Preview asset path must not be blank.'},
      );
      return;
    }

    final resolvedAssetPath = _resolveAssetPath(
      assetRootPath: assetRootPath,
      rawRelativePath: p.joinAll(decodedSegments),
    );
    final assetFile = File(resolvedAssetPath);
    if (!await assetFile.exists()) {
      await _writeJson(request.response, HttpStatus.notFound, <String, Object?>{
        'message': 'Preview asset was not found.',
        'path': p.relative(resolvedAssetPath, from: assetRootPath),
      });
      return;
    }

    request.response.statusCode = HttpStatus.ok;
    final contentType = _contentTypeFor(resolvedAssetPath);
    if (contentType != null) {
      request.response.headers.contentType = ContentType.parse(contentType);
    }
    await request.response.addStream(assetFile.openRead());
    await request.response.close();
  }

  String _resolveAssetPath({
    required String assetRootPath,
    required String rawRelativePath,
  }) {
    final normalizedAssetRoot = p.normalize(p.absolute(assetRootPath));
    var normalizedRelativePath = rawRelativePath.replaceAll('\\', '/');
    if (normalizedRelativePath.startsWith('assets/')) {
      normalizedRelativePath = normalizedRelativePath.substring(
        'assets/'.length,
      );
    }
    while (normalizedRelativePath.startsWith('/')) {
      normalizedRelativePath = normalizedRelativePath.substring(1);
    }

    final candidatePath = p.normalize(
      p.join(normalizedAssetRoot, normalizedRelativePath),
    );
    if (candidatePath != normalizedAssetRoot &&
        !p.isWithin(normalizedAssetRoot, candidatePath)) {
      throw const MiniProgramPreviewException(
        'Preview asset path escapes the mini-program asset root.',
      );
    }
    return candidatePath;
  }

  Map<String, dynamic> _rewriteScreenJson(
    Map<String, dynamic> screenJson, {
    required MiniProgramPreviewBundle bundle,
  }) {
    final rewritten = _rewriteValue(screenJson, bundle: bundle);
    return Map<String, dynamic>.from(rewritten as Map);
  }

  Object? _rewriteValue(
    Object? value, {
    required MiniProgramPreviewBundle bundle,
  }) {
    if (value is List) {
      return value
          .map((entry) => _rewriteValue(entry, bundle: bundle))
          .toList();
    }

    if (value is! Map) {
      return value;
    }

    final json = value.map((key, entry) => MapEntry(key.toString(), entry));
    final rewrittenImage = _rewriteLocalAssetImage(json, bundle: bundle);
    if (rewrittenImage != null) {
      return rewrittenImage;
    }

    return json.map(
      (key, entry) => MapEntry(key, _rewriteValue(entry, bundle: bundle)),
    );
  }

  Map<String, dynamic>? _rewriteLocalAssetImage(
    Map<String, dynamic> json, {
    required MiniProgramPreviewBundle bundle,
  }) {
    if (bundle.assetRootPath == null || json['type'] != 'image') {
      return null;
    }

    final rawTopLevelSource = json['src'];
    if (rawTopLevelSource is String &&
        _isLocalAssetSource(rawTopLevelSource, bundle: bundle)) {
      return <String, dynamic>{
        ...json,
        'imageType': 'network',
        'src': baseUri
            .resolve('assets/${_normalizePreviewAssetPath(rawTopLevelSource)}')
            .toString(),
      };
    }

    final props = json['props'];
    if (props is Map) {
      final normalizedProps = props.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final rawPropsSource = normalizedProps['src'];
      if (rawPropsSource is String &&
          _isLocalAssetSource(rawPropsSource, bundle: bundle)) {
        return <String, dynamic>{
          ...json,
          'props': <String, dynamic>{
            ...normalizedProps,
            'src': baseUri
                .resolve('assets/${_normalizePreviewAssetPath(rawPropsSource)}')
                .toString(),
          },
        };
      }
    }

    return null;
  }

  bool _isLocalAssetSource(
    String rawSource, {
    required MiniProgramPreviewBundle bundle,
  }) {
    if (rawSource.trim().isEmpty || bundle.assetRootPath == null) {
      return false;
    }

    final source = rawSource.trim();
    final uri = Uri.tryParse(source);
    if (uri != null && uri.scheme.isNotEmpty) {
      return false;
    }

    if (source.startsWith('{') || source.startsWith(r'$')) {
      return false;
    }

    try {
      final assetPath = _resolveAssetPath(
        assetRootPath: bundle.assetRootPath!,
        rawRelativePath: source,
      );
      return File(assetPath).existsSync();
    } on MiniProgramPreviewException {
      return false;
    }
  }

  String _normalizePreviewAssetPath(String rawSource) {
    var value = rawSource.replaceAll('\\', '/').trim();
    if (value.startsWith('assets/')) {
      value = value.substring('assets/'.length);
    }
    while (value.startsWith('/')) {
      value = value.substring(1);
    }
    return value
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
  }

  void _writeBaseHeaders(HttpResponse response) {
    response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set(HttpHeaders.accessControlAllowOriginHeader, '*')
      ..set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, OPTIONS')
      ..set(HttpHeaders.accessControlAllowHeadersHeader, 'Content-Type');
  }

  Future<void> _writeJson(
    HttpResponse response,
    int statusCode,
    Map<String, Object?> body,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  String? _contentTypeFor(String filePath) {
    switch (p.extension(filePath).toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.webp':
        return 'image/webp';
      case '.svg':
        return 'image/svg+xml';
      case '.gif':
        return 'image/gif';
      case '.json':
        return 'application/json';
      default:
        return null;
    }
  }

  static Future<HttpServer> _defaultServerBinder(
    InternetAddress address,
    int port,
  ) {
    return HttpServer.bind(address, port);
  }
}
