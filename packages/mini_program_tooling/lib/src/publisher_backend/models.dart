part of '../publisher_backend_starter.dart';

typedef PublisherBackendShellRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });
typedef PublisherBackendProcessStarter =
    Future<StartedPublisherBackendProcess> Function({
      required String executable,
      required List<String> arguments,
      required String workingDirectory,
    });
typedef PublisherBackendHealthGetter = Future<http.Response> Function(Uri uri);
typedef PublisherBackendClock = DateTime Function();
typedef PublisherBackendDelay = Future<void> Function(Duration duration);

const String _publisherBackendStorageBundled = 'bundled';

class PublisherBackendException implements Exception {
  const PublisherBackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PublisherBackendScaffoldRequest {
  const PublisherBackendScaffoldRequest({
    required this.miniProgramRootPath,
    this.template = 'mock',
    this.storageMode = 'bundled',
    this.force = false,
    this.withStarterUi = false,
  });

  final String miniProgramRootPath;
  final String template;
  final String storageMode;
  final bool force;
  final bool withStarterUi;
}

class PublisherBackendScaffoldResult {
  const PublisherBackendScaffoldResult({
    required this.miniProgramRootPath,
    required this.backendRootPath,
    required this.template,
    required this.createdPaths,
    this.storageMode,
  });

  final String miniProgramRootPath;
  final String backendRootPath;
  final String template;
  final List<String> createdPaths;
  final String? storageMode;
}
