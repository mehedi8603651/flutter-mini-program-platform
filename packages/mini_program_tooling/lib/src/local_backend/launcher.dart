import 'dart:io';

class LocalBackendLauncher {
  const LocalBackendLauncher();

  String executable() => Platform.isWindows ? 'cmd.exe' : 'sh';

  List<String> arguments(String launcherScriptPath) => Platform.isWindows
      ? <String>['/c', launcherScriptPath]
      : <String>[launcherScriptPath];

  Future<void> writeScript({
    required String launcherScriptPath,
    required String serviceDirectoryPath,
    required String serverScriptPath,
    required String apiRootPath,
    required String stdoutLogPath,
    required String stderrLogPath,
    required int port,
  }) async {
    final content = Platform.isWindows
        ? _buildWindowsScript(
            serviceDirectoryPath: serviceDirectoryPath,
            serverScriptPath: serverScriptPath,
            apiRootPath: apiRootPath,
            stdoutLogPath: stdoutLogPath,
            stderrLogPath: stderrLogPath,
            port: port,
          )
        : _buildUnixScript(
            serviceDirectoryPath: serviceDirectoryPath,
            serverScriptPath: serverScriptPath,
            apiRootPath: apiRootPath,
            stdoutLogPath: stdoutLogPath,
            stderrLogPath: stderrLogPath,
            port: port,
          );
    await File(launcherScriptPath).writeAsString(content);
  }

  String _buildWindowsScript({
    required String serviceDirectoryPath,
    required String serverScriptPath,
    required String apiRootPath,
    required String stdoutLogPath,
    required String stderrLogPath,
    required int port,
  }) {
    final quotedDart = _quoteForCmd(Platform.resolvedExecutable);
    final quotedServiceDirectory = _quoteForCmd(serviceDirectoryPath);
    final quotedServerScript = _quoteForCmd(serverScriptPath);
    final quotedHostArg = _quoteForCmd('--host=0.0.0.0');
    final quotedPortArg = _quoteForCmd('--port=$port');
    final quotedApiRootArg = _quoteForCmd('--api-root=$apiRootPath');
    final quotedStdoutLog = _quoteForCmd(stdoutLogPath);
    final quotedStderrLog = _quoteForCmd(stderrLogPath);

    return [
      '@echo off',
      'setlocal',
      'cd /d $quotedServiceDirectory',
      '$quotedDart $quotedServerScript $quotedHostArg $quotedPortArg '
          '$quotedApiRootArg 1>>$quotedStdoutLog 2>>$quotedStderrLog',
    ].join('\r\n');
  }

  String _buildUnixScript({
    required String serviceDirectoryPath,
    required String serverScriptPath,
    required String apiRootPath,
    required String stdoutLogPath,
    required String stderrLogPath,
    required int port,
  }) {
    final quotedDart = _quoteForSh(Platform.resolvedExecutable);
    final quotedServiceDirectory = _quoteForSh(serviceDirectoryPath);
    final quotedServerScript = _quoteForSh(serverScriptPath);
    final quotedHostArg = _quoteForSh('--host=0.0.0.0');
    final quotedPortArg = _quoteForSh('--port=$port');
    final quotedApiRootArg = _quoteForSh('--api-root=$apiRootPath');
    final quotedStdoutLog = _quoteForSh(stdoutLogPath);
    final quotedStderrLog = _quoteForSh(stderrLogPath);

    return [
      '#!/usr/bin/env sh',
      'set -eu',
      'cd $quotedServiceDirectory',
      'exec $quotedDart $quotedServerScript $quotedHostArg $quotedPortArg '
          '$quotedApiRootArg >>$quotedStdoutLog 2>>$quotedStderrLog',
      '',
    ].join('\n');
  }

  String _quoteForCmd(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _quoteForSh(String value) {
    final escaped = value.replaceAll("'", r"'\''");
    return "'$escaped'";
  }
}
