import 'dart:convert';
import 'dart:io';

import 'mp_program.dart';

/// Writes deterministic Mp build artifacts for tooling.
Future<void> writeMpBuildOutput(
  MpProgram program, {
  List<String> arguments = const <String>[],
  String defaultOutputDirectory = 'mp/.build',
}) async {
  final outputDirectoryPath = _resolveOutputDirectoryPath(
    arguments: arguments,
    defaultOutputDirectory: defaultOutputDirectory,
  );
  final screensDirectory = Directory(_joinPath(outputDirectoryPath, 'screens'));

  await screensDirectory.create(recursive: true);
  await for (final entity in screensDirectory.list(followLinks: false)) {
    if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
      await entity.delete();
    }
  }

  final encoder = const JsonEncoder.withIndent('  ');
  final screens = program.buildScreensJson();
  for (final entry in screens.entries) {
    final file = File(_joinPath(screensDirectory.path, '${entry.key}.json'));
    await file.writeAsString('${encoder.convert(entry.value)}\n');
  }
}

String _resolveOutputDirectoryPath({
  required List<String> arguments,
  required String defaultOutputDirectory,
}) {
  var outputDirectory = defaultOutputDirectory;
  for (var index = 0; index < arguments.length; index += 1) {
    final argument = arguments[index];
    if (argument == '--output') {
      if (index == arguments.length - 1) {
        throw ArgumentError.value(
          arguments,
          'arguments',
          'Missing value after --output.',
        );
      }
      outputDirectory = arguments[index + 1];
      index += 1;
      continue;
    }

    if (argument == '--help' || argument == '-h') {
      stdout.writeln('Usage: dart run tool/build_mp.dart [--output <path>]');
      return outputDirectory;
    }

    throw ArgumentError.value(
      argument,
      'argument',
      'Unsupported build_mp.dart argument.',
    );
  }

  if (outputDirectory.trim().isEmpty) {
    throw ArgumentError.value(
      outputDirectory,
      'outputDirectory',
      'Output directory must not be empty.',
    );
  }
  return outputDirectory;
}

String _joinPath(String first, String second) {
  if (first.endsWith('/') || first.endsWith(r'\')) {
    return '$first$second';
  }
  return '$first${Platform.pathSeparator}$second';
}
