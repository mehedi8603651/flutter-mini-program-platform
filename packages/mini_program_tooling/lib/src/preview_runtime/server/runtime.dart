import 'dart:io';

import 'package:path/path.dart' as path;

import 'assets.dart';
import 'models.dart';
import 'responses.dart';

class PreviewServerRuntime {
  PreviewServerRuntime({
    PreviewHttpServerBinder serverBinder = defaultPreviewServerBinder,
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
      writePreviewBaseHeaders(request.response);

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }

      if (request.method != 'GET') {
        await writePreviewJson(
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
        await writePreviewJson(request.response, HttpStatus.ok, _statusBody());
        return;
      }

      final bundle = _bundle;
      if (bundle == null) {
        await writePreviewJson(
          request.response,
          HttpStatus.serviceUnavailable,
          <String, Object?>{'message': 'Preview bundle is not ready yet.'},
        );
        return;
      }

      if (segments.length == 2 &&
          segments[0] == 'preview' &&
          segments[1] == 'manifest.json') {
        await writePreviewJson(
          request.response,
          HttpStatus.ok,
          bundle.manifestJson,
        );
        return;
      }

      if (segments.length == 2 &&
          segments[0] == 'preview' &&
          segments[1] == 'publisher_backend.json') {
        final contract = bundle.publisherBackendJson;
        if (contract == null) {
          await writePreviewJson(
            request.response,
            HttpStatus.notFound,
            <String, Object?>{
              'message': 'Preview Publisher API contract was not found.',
            },
          );
          return;
        }
        await writePreviewJson(request.response, HttpStatus.ok, contract);
        return;
      }

      if (segments.length >= 3 &&
          segments[0] == 'preview' &&
          segments[1] == 'screens') {
        final screenId = path.basenameWithoutExtension(
          segments.sublist(2).join('/'),
        );
        final screenJson = bundle.screenJsonById[screenId];
        if (screenJson == null) {
          await writePreviewJson(
            request.response,
            HttpStatus.notFound,
            <String, Object?>{
              'message': 'Preview screen was not found: $screenId',
            },
          );
          return;
        }

        await writePreviewJson(
          request.response,
          HttpStatus.ok,
          rewritePreviewScreenJson(
            screenJson,
            bundle: bundle,
            baseUri: baseUri,
          ),
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

      await writePreviewJson(
        request.response,
        HttpStatus.notFound,
        <String, Object?>{
          'message': 'Preview route not found: ${request.uri.path}',
        },
      );
    } catch (error) {
      try {
        await writePreviewJson(
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
      await writePreviewJson(
        request.response,
        HttpStatus.notFound,
        <String, Object?>{
          'message': 'Preview mini-program does not define an assets/ root.',
        },
      );
      return;
    }

    final decodedSegments = relativeSegments
        .map(Uri.decodeComponent)
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (decodedSegments.isEmpty) {
      await writePreviewJson(
        request.response,
        HttpStatus.badRequest,
        <String, Object?>{'message': 'Preview asset path must not be blank.'},
      );
      return;
    }

    final resolvedAssetPath = resolvePreviewAssetPath(
      assetRootPath: assetRootPath,
      rawRelativePath: path.joinAll(decodedSegments),
    );
    final assetFile = File(resolvedAssetPath);
    if (!await assetFile.exists()) {
      await writePreviewJson(
        request.response,
        HttpStatus.notFound,
        <String, Object?>{
          'message': 'Preview asset was not found.',
          'path': path.relative(resolvedAssetPath, from: assetRootPath),
        },
      );
      return;
    }

    request.response.statusCode = HttpStatus.ok;
    final contentType = previewAssetContentType(resolvedAssetPath);
    if (contentType != null) {
      request.response.headers.contentType = ContentType.parse(contentType);
    }
    await request.response.addStream(assetFile.openRead());
    await request.response.close();
  }
}

Future<HttpServer> defaultPreviewServerBinder(
  InternetAddress address,
  int port,
) {
  return HttpServer.bind(address, port);
}
