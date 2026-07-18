import 'dart:io';

import 'package:path/path.dart' as p;

class PublisherBackendLauncher {
  const PublisherBackendLauncher();

  String executable() => Platform.isWindows ? 'cmd.exe' : 'sh';

  List<String> arguments(String launcherScriptPath) => Platform.isWindows
      ? <String>['/c', launcherScriptPath]
      : <String>[launcherScriptPath];

  Future<void> writeScript({
    required String launcherScriptPath,
    required String backendRootPath,
    required String stdoutLogPath,
    required String stderrLogPath,
    required int port,
  }) async {
    final serverScriptPath = p.join(backendRootPath, 'bin', 'server.dart');
    final content = Platform.isWindows
        ? <String>[
            '@echo off',
            'setlocal',
            'cd /d ${_quoteForCmd(backendRootPath)}',
            '${_quoteForCmd(Platform.resolvedExecutable)} '
                '${_quoteForCmd(serverScriptPath)} '
                '${_quoteForCmd('--host=0.0.0.0')} '
                '${_quoteForCmd('--port=$port')} '
                '1>>${_quoteForCmd(stdoutLogPath)} '
                '2>>${_quoteForCmd(stderrLogPath)}',
          ].join('\r\n')
        : <String>[
            '#!/usr/bin/env sh',
            'set -eu',
            'cd ${_quoteForSh(backendRootPath)}',
            'exec ${_quoteForSh(Platform.resolvedExecutable)} '
                '${_quoteForSh(serverScriptPath)} '
                '${_quoteForSh('--host=0.0.0.0')} '
                '${_quoteForSh('--port=$port')} '
                '>>${_quoteForSh(stdoutLogPath)} '
                '2>>${_quoteForSh(stderrLogPath)}',
            '',
          ].join('\n');
    await File(launcherScriptPath).writeAsString(content);
  }

  String _quoteForCmd(String value) => '"${value.replaceAll('"', '""')}"';

  String _quoteForSh(String value) => "'${value.replaceAll("'", r"'\''")}'";
}
