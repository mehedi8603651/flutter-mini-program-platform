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
      'project-root',
      help: 'Existing Flutter app root containing pubspec.yaml and lib/.',
      mandatory: true,
    )
    ..addOption(
      'repo-root',
      help:
          'Optional platform repo root used for README dependency path snippets.',
    )
    ..addOption(
      'host-app-id',
      help: 'Optional host app identifier. Defaults to the pubspec package name.',
    )
    ..addOption(
      'host-version',
      help: 'Optional host version. Defaults to the pubspec version without +build suffix.',
    )
    ..addOption(
      'native-route-path',
      defaultsTo: '/native/profile-editor',
      help: 'Sample native route path used by the generated bridge alias.',
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

  final request = MiniProgramEmbeddingInitRequest(
    projectRootPath: results.option('project-root')!,
    repoRootPath: results.option('repo-root'),
    hostAppId: results.option('host-app-id'),
    hostVersion: results.option('host-version'),
    nativeRoutePath: results.option('native-route-path')!,
    force: results.flag('force'),
  );

  try {
    final result = await const MiniProgramEmbeddingInitializer().initialize(
      request,
    );

    if (results.option('output') == 'json') {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
    } else {
      stdout.writeln(_formatResult(result));
    }
  } on MiniProgramEmbeddingInitException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}

String _formatResult(MiniProgramEmbeddingInitResult result) {
  final lines = <String>[
    'Initialized embedded mini-program adapter for: ${result.packageName}',
    'Project root: ${result.projectRootPath}',
    if (result.repoRootPath != null) 'Repo root: ${result.repoRootPath}',
    'Host app id: ${result.hostAppId}',
    'Host version: ${result.hostVersion}',
    'Native route path: ${result.nativeRoutePath}',
    'Files:',
    ...result.createdPaths.map((path) => '- $path'),
    'Next steps:',
    '- Add mini_program_sdk and mini_program_contracts to pubspec.yaml if they are missing.',
    '- Keep main.dart small by calling buildMiniProgramRuntime(navigatorKey).',
    '- Register the generated NativeProfileEditorPage route in your app shell.',
    "- Open MiniProgramPage(miniProgramId: 'my_data') from your existing UI.",
  ];

  return lines.join('\n');
}
