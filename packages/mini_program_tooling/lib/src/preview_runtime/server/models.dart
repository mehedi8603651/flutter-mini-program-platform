import 'dart:io';

typedef PreviewHttpServerBinder =
    Future<HttpServer> Function(InternetAddress address, int port);

class MiniProgramPreviewBundle {
  const MiniProgramPreviewBundle({
    required this.miniProgramId,
    required this.title,
    required this.manifestJson,
    required this.screenJsonById,
    this.assetRootPath,
    this.publisherBackendJson,
  });

  final String miniProgramId;
  final String title;
  final Map<String, dynamic> manifestJson;
  final Map<String, Map<String, dynamic>> screenJsonById;
  final String? assetRootPath;
  final Map<String, dynamic>? publisherBackendJson;
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
