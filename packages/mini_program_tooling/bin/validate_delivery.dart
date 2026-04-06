import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:mini_program_tooling/mini_program_tooling.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    )
    ..addOption(
      'repo-root',
      defaultsTo: Directory.current.path,
      help: 'Repository root containing mini_programs/ and backend/api/.',
    )
    ..addOption(
      'mini-program',
      help: 'Optional mini-program ID to validate in isolation.',
    )
    ..addOption(
      'output',
      allowed: <String>['text', 'json'],
      defaultsTo: 'text',
      help: 'Output format.',
    );

  late final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }

  if (results.flag('help')) {
    stdout.writeln(parser.usage);
    return;
  }

  final validator = const DeliveryRepositoryValidator();
  final report = await validator.validate(
    repoRootPath: results.option('repo-root')!,
    miniProgramId: results.option('mini-program'),
  );

  if (results.option('output') == 'json') {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report.toJson()));
  } else {
    stdout.writeln(formatDeliveryValidationReport(report));
  }

  if (report.hasErrors) {
    exitCode = 1;
  }
}
