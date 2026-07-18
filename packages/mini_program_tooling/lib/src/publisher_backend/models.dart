import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

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

class PublisherBackendRunResult {
  const PublisherBackendRunResult({
    required this.state,
    required this.alreadyRunning,
  });

  final PublisherBackendState state;
  final bool alreadyRunning;
}

class PublisherBackendStatusResult {
  const PublisherBackendStatusResult({
    required this.state,
    required this.hasState,
    required this.processAlive,
    required this.healthy,
    this.healthStatusCode,
    this.healthError,
  });

  final PublisherBackendState? state;
  final bool hasState;
  final bool processAlive;
  final bool healthy;
  final int? healthStatusCode;
  final String? healthError;
}

class PublisherBackendStopResult {
  const PublisherBackendStopResult({
    required this.hadState,
    required this.processWasAlive,
    required this.stopped,
    required this.clearedStaleState,
  });

  final bool hadState;
  final bool processWasAlive;
  final bool stopped;
  final bool clearedStaleState;
}

class PublisherBackendUrlsResult {
  const PublisherBackendUrlsResult({required this.port});

  final int port;

  String get desktopBaseUrl => 'http://127.0.0.1:$port/';
  String get androidEmulatorBaseUrl => 'http://10.0.2.2:$port/';
  String get androidUsbBaseUrl => 'http://127.0.0.1:$port/';
}

class PublisherBackendState {
  const PublisherBackendState({
    required this.schemaVersion,
    required this.miniProgramRootPath,
    required this.backendRootPath,
    required this.pid,
    required this.port,
    required this.bindHost,
    required this.healthCheckUrl,
    required this.stdoutLogPath,
    required this.stderrLogPath,
    required this.startedAtUtc,
  });

  final int schemaVersion;
  final String miniProgramRootPath;
  final String backendRootPath;
  final int pid;
  final int port;
  final String bindHost;
  final String healthCheckUrl;
  final String stdoutLogPath;
  final String stderrLogPath;
  final String startedAtUtc;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'miniProgramRootPath': miniProgramRootPath,
    'backendRootPath': backendRootPath,
    'pid': pid,
    'port': port,
    'bindHost': bindHost,
    'healthCheckUrl': healthCheckUrl,
    'stdoutLogPath': stdoutLogPath,
    'stderrLogPath': stderrLogPath,
    'startedAtUtc': startedAtUtc,
  };

  static PublisherBackendState fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    final miniProgramRootPath = json['miniProgramRootPath'];
    final backendRootPath = json['backendRootPath'];
    final pid = json['pid'];
    final port = json['port'];
    final bindHost = json['bindHost'];
    final healthCheckUrl = json['healthCheckUrl'];
    final stdoutLogPath = json['stdoutLogPath'];
    final stderrLogPath = json['stderrLogPath'];
    final startedAtUtc = json['startedAtUtc'];
    if (schemaVersion is! int ||
        miniProgramRootPath is! String ||
        backendRootPath is! String ||
        pid is! int ||
        port is! int ||
        bindHost is! String ||
        healthCheckUrl is! String ||
        stdoutLogPath is! String ||
        stderrLogPath is! String ||
        startedAtUtc is! String) {
      throw const PublisherBackendException(
        'publisher_backend.local.json is missing required fields.',
      );
    }
    return PublisherBackendState(
      schemaVersion: schemaVersion,
      miniProgramRootPath: p.normalize(p.absolute(miniProgramRootPath)),
      backendRootPath: p.normalize(p.absolute(backendRootPath)),
      pid: pid,
      port: port,
      bindHost: bindHost,
      healthCheckUrl: healthCheckUrl,
      stdoutLogPath: stdoutLogPath,
      stderrLogPath: stderrLogPath,
      startedAtUtc: startedAtUtc,
    );
  }
}

class StartedPublisherBackendProcess {
  const StartedPublisherBackendProcess({required this.pid});

  final int pid;
}
