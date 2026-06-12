part of '../publisher_backend_starter.dart';

extension _PublisherBackendStarterSharedHelpers on PublisherBackendStarter {
  Future<String> _requireMiniProgramRoot(String rawRootPath) async {
    final rootPath = p.normalize(p.absolute(rawRootPath));
    final manifestFile = File(p.join(rootPath, 'manifest.json'));
    if (!await manifestFile.exists()) {
      throw PublisherBackendException(
        'Mini-program root is missing manifest.json: $rootPath',
      );
    }
    return rootPath;
  }

  Future<void> _assertMockBackendPaths(String backendRootPath) async {
    final serverFile = File(p.join(backendRootPath, 'bin', 'server.dart'));
    final dataDirectory = Directory(p.join(backendRootPath, 'data'));
    if (!await serverFile.exists() || !await dataDirectory.exists()) {
      throw PublisherBackendException(
        'Publisher mock API was not found. Run '
        '`miniprogram publisher-backend scaffold --template mock` first.',
      );
    }
  }

  Future<void> _writeManagedFile({
    required String filePath,
    required String contents,
    required bool force,
    required List<String> createdPaths,
  }) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    if (await file.exists()) {
      final existing = await file.readAsString();
      if (existing == contents) {
        return;
      }
      if (!force) {
        throw PublisherBackendException(
          'Publisher API scaffold would overwrite an existing file. '
          'Re-run with --force if you want to replace scaffold-managed files.\n'
          '$filePath',
        );
      }
    } else {
      createdPaths.add(filePath);
    }
    await file.writeAsString(contents);
  }

  Future<void> _writeLauncherScript({
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

  Future<Directory> _ensureStateDirectory(String miniProgramRootPath) async {
    final directory = Directory(p.join(miniProgramRootPath, '.mini_program'));
    await directory.create(recursive: true);
    return directory;
  }

  String _statePath(String miniProgramRootPath) => p.join(
    miniProgramRootPath,
    '.mini_program',
    'publisher_backend.local.json',
  );

  Future<PublisherBackendState?> _readState(String miniProgramRootPath) async {
    final file = File(_statePath(miniProgramRootPath));
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'publisher_backend.local.json must contain a JSON object.',
      );
    }
    return PublisherBackendState.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<void> _writeState(
    String miniProgramRootPath,
    PublisherBackendState state,
  ) async {
    final directory = await _ensureStateDirectory(miniProgramRootPath);
    final file = File(p.join(directory.path, 'publisher_backend.local.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  Future<void> _clearState(String miniProgramRootPath) async {
    final file = File(_statePath(miniProgramRootPath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _quoteForCmd(String value) => '"${value.replaceAll('"', '""')}"';

  String _quoteForSh(String value) => "'${value.replaceAll("'", r"'\''")}'";
}
