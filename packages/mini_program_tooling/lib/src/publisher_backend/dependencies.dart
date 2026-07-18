import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

class PublisherBackendDependencies {
  const PublisherBackendDependencies({
    required this.shellRunner,
    required this.processStarter,
    required this.healthGetter,
    required this.clock,
    required this.delay,
  });

  final PublisherBackendShellRunner shellRunner;
  final PublisherBackendProcessStarter processStarter;
  final PublisherBackendHealthGetter healthGetter;
  final PublisherBackendClock clock;
  final PublisherBackendDelay delay;
}

Future<ProcessResult> defaultPublisherBackendShellRunner(
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

Future<StartedPublisherBackendProcess> defaultPublisherBackendProcessStarter({
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

DateTime defaultPublisherBackendClock() => DateTime.now();

Future<void> defaultPublisherBackendDelay(Duration duration) =>
    Future<void>.delayed(duration);

Future<http.Response> defaultPublisherBackendHealthGetter(Uri uri) =>
    http.get(uri);
