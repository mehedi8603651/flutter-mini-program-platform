import 'dart:io';

import 'package:http/http.dart' as http;

import '../local_cli_state.dart';

typedef BackendShellRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });
typedef BackendProcessStarter =
    Future<StartedBackendProcess> Function({
      required String executable,
      required List<String> arguments,
      required String workingDirectory,
    });
typedef BackendHealthGetter = Future<http.Response> Function(Uri uri);
typedef BackendClock = DateTime Function();

class LocalBackendControlException implements Exception {
  const LocalBackendControlException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalBackendStartResult {
  const LocalBackendStartResult({
    required this.state,
    required this.alreadyRunning,
    this.reversedDeviceIds = const <String>[],
  });

  final LocalBackendState state;
  final bool alreadyRunning;
  final List<String> reversedDeviceIds;
}

class LocalBackendStatusResult {
  const LocalBackendStatusResult({
    required this.state,
    required this.hasState,
    required this.processAlive,
    required this.healthy,
    this.healthStatusCode,
    this.healthError,
  });

  final LocalBackendState? state;
  final bool hasState;
  final bool processAlive;
  final bool healthy;
  final int? healthStatusCode;
  final String? healthError;
}

class LocalBackendStopResult {
  const LocalBackendStopResult({
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

class LocalBackendResetResult {
  const LocalBackendResetResult({required this.removedPaths});

  final List<String> removedPaths;
}

class StartedBackendProcess {
  const StartedBackendProcess({
    required this.pid,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final int pid;
  final Stream<List<int>> stdout;
  final Stream<List<int>> stderr;
  final Future<int> exitCode;
}
