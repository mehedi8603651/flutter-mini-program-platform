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
      help: 'Repository root containing mini_programs/.',
    )
    ..addOption(
      'id',
      help: 'Mini-program ID, for example feedback_form.',
      mandatory: true,
    )
    ..addOption(
      'title',
      help: 'Optional human-readable title. Defaults to a titleized form of the ID.',
    )
    ..addOption(
      'description',
      help: 'Optional description written into the generated README.',
    )
    ..addOption(
      'capabilities',
      defaultsTo: 'analytics,native_navigation',
      help: 'Comma-separated capability wire values.',
    )
    ..addFlag(
      'force',
      negatable: false,
      help: 'Overwrite scaffold-managed files if the target already exists.',
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

  final request = MiniProgramScaffoldRequest(
    repoRootPath: results.option('repo-root')!,
    miniProgramId: results.option('id')!,
    title: results.option('title'),
    description: results.option('description'),
    capabilities: _parseCapabilities(results.option('capabilities')!),
    force: results.flag('force'),
  );

  try {
    final result = await const MiniProgramScaffolder().scaffold(request);

    if (results.option('output') == 'json') {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
    } else {
      stdout.writeln(_formatResult(result));
    }
  } on MiniProgramScaffoldException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}

Set<String> _parseCapabilities(String rawCapabilities) => rawCapabilities
    .split(',')
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .toSet();

String _formatResult(MiniProgramScaffoldResult result) {
  final lines = <String>[
    'Created mini-program scaffold: ${result.miniProgramId}',
    'Root: ${result.miniProgramRootPath}',
    'Capabilities: ${result.capabilities.join(', ')}',
    'Files:',
    ...result.createdPaths.map((path) => '- $path'),
    'Next steps:',
    '- Edit manifest.json and the starter screen.',
    '- Build with the vendored Stac CLI.',
    '- Run validate_delivery before publish.',
  ];

  return lines.join('\n');
}
