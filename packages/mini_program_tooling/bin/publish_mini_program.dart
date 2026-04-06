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
      help: 'Repository root containing mini_programs/ and backend/api/.',
    )
    ..addOption(
      'mini-program-root',
      help: 'Exact mini-program root path for standalone authoring.',
    )
    ..addOption(
      'id',
      help: 'Mini-program ID to build, validate, and publish.',
    )
    ..addOption(
      'stac-cli-script',
      help: 'Optional explicit path to bin/stac_cli.dart.',
    )
    ..addFlag(
      'skip-build-pub-get',
      negatable: false,
      help: 'Skip dart pub get inside the mini-program package during build.',
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
    final result = await const MiniProgramPublisher().publish(
      MiniProgramPublishRequest(
        repoRootPath: results.option('repo-root') ?? Directory.current.path,
        miniProgramId: results.option('id'),
        miniProgramRootPath: results.option('mini-program-root'),
        stacCliScriptPath: results.option('stac-cli-script'),
        skipBuildPubGet: results.flag('skip-build-pub-get'),
      ),
    );

    if (results.option('output') == 'json') {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
    } else {
      stdout.writeln(_formatResult(result));
    }
  } on MiniProgramPublishException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}

String _formatResult(MiniProgramPublishResult result) {
  final lines = <String>[
    'Published mini-program: ${result.miniProgramId}',
    'Version: ${result.version}',
    'Build CLI source: ${result.buildResult.cliSource}',
    'Built entry screen: ${result.buildResult.entryScreenJsonPath}',
    'Pre-publish validation: ${result.prePublishValidation.errorCount} error(s), ${result.prePublishValidation.warningCount} warning(s)',
    'Post-publish validation: ${result.postPublishValidation.errorCount} error(s), ${result.postPublishValidation.warningCount} warning(s)',
    'Latest manifest: ${result.latestManifestPath}',
    'Versioned manifest: ${result.versionedManifestPath}',
    'Published screens: ${result.screensDirectoryPath} (${result.copiedScreenCount} file(s))',
  ];

  return lines.join('\n');
}
