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
    ..addOption('repo-root', help: 'Repository root containing mini_programs/.')
    ..addOption(
      'mini-program-root',
      help: 'Exact mini-program root path for standalone authoring.',
    )
    ..addOption('id', help: 'Mini-program ID to build.')
    ..addFlag(
      'skip-pub-get',
      negatable: false,
      help: 'Skip dart pub get inside the mini-program package.',
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

  try {
    final result = await const MiniProgramBuilder().build(
      MiniProgramBuildRequest(
        repoRootPath: results.option('repo-root'),
        miniProgramId: results.option('id'),
        miniProgramRootPath: results.option('mini-program-root'),
        skipPubGet: results.flag('skip-pub-get'),
      ),
    );

    if (results.option('output') == 'json') {
      stdout.writeln(
        const JsonEncoder.withIndent('  ').convert(result.toJson()),
      );
    } else {
      stdout.writeln(_formatResult(result));
    }
  } on MiniProgramBuildException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}

String _formatResult(MiniProgramBuildResult result) {
  final lines = <String>[
    'Built mini-program: ${result.miniProgramId}',
    'Root: ${result.miniProgramRootPath}',
    if (result.repoRootPath != null) 'Repo root: ${result.repoRootPath}',
    'CLI source: ${result.cliSource}',
    'Command: ${result.invocation.join(' ')}',
    'Output directory: ${result.outputDirectoryPath}',
    'Entry screen JSON: ${result.entryScreenJsonPath}',
    'Ran pub get: ${result.pubGetRan}',
  ];

  return lines.join('\n');
}
