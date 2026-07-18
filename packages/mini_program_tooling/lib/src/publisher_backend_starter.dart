import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'publisher_backend/generated_files.dart';

part 'publisher_backend/models.dart';
part 'publisher_backend/models/local_models.dart';
part 'publisher_backend/internal_models.dart';
part 'publisher_backend/starter_helpers.dart';
part 'publisher_backend/runtime_smoke_helpers.dart';
part 'publisher_backend/core_operations.dart';

class PublisherBackendStarter {
  const PublisherBackendStarter({
    PublisherBackendShellRunner shellRunner = _defaultShellRunner,
    PublisherBackendProcessStarter processStarter = _defaultProcessStarter,
    PublisherBackendHealthGetter healthGetter = http.get,
    PublisherBackendClock clock = _defaultClock,
    PublisherBackendDelay delay = _defaultDelay,
  }) : _shellRunner = shellRunner,
       _processStarter = processStarter,
       _healthGetter = healthGetter,
       _clock = clock,
       _delay = delay;

  final PublisherBackendShellRunner _shellRunner;
  final PublisherBackendProcessStarter _processStarter;
  final PublisherBackendHealthGetter _healthGetter;
  final PublisherBackendClock _clock;
  final PublisherBackendDelay _delay;

  Future<PublisherBackendScaffoldResult> scaffold(
    PublisherBackendScaffoldRequest request,
  ) => _scaffoldImpl(request);

  Future<PublisherBackendRunResult> run({
    required String miniProgramRootPath,
    int port = 9090,
  }) => _runImpl(miniProgramRootPath: miniProgramRootPath, port: port);

  Future<PublisherBackendStatusResult> status({
    required String miniProgramRootPath,
  }) => _statusImpl(miniProgramRootPath: miniProgramRootPath);

  Future<PublisherBackendStopResult> stop({
    required String miniProgramRootPath,
  }) => _stopImpl(miniProgramRootPath: miniProgramRootPath);

  PublisherBackendUrlsResult urls({int port = 9090}) => _urlsImpl(port: port);

  static Future<ProcessResult> _defaultShellRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: true,
    );
  }

  static Future<StartedPublisherBackendProcess> _defaultProcessStarter({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.detached,
    );
    return StartedPublisherBackendProcess(pid: process.pid);
  }

  static DateTime _defaultClock() => DateTime.now();

  static Future<void> _defaultDelay(Duration duration) {
    return Future<void>.delayed(duration);
  }
}
