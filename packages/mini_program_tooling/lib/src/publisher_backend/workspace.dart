import 'dart:io';

import 'package:path/path.dart' as p;

import 'generated_files.dart';
import 'models.dart';

const String _publisherBackendStorageBundled = 'bundled';

class PublisherBackendWorkspace {
  const PublisherBackendWorkspace();

  Future<PublisherBackendScaffoldResult> scaffold(
    PublisherBackendScaffoldRequest request,
  ) async {
    if (request.template != 'mock') {
      throw PublisherBackendException(
        'Publisher API provider templates were removed. Use your own '
        'middle server and connect it with '
        '`miniprogram publisher-api contract init --publisher-api-url <url>`, '
        'or use `--template mock` for local API testing.',
      );
    }
    if (request.storageMode != _publisherBackendStorageBundled) {
      throw PublisherBackendException(
        'publisher-backend scaffold --storage is not supported. The mock '
        'publisher API uses bundled local JSON only; real storage belongs on '
        'your external middle server.',
      );
    }
    if (request.withStarterUi) {
      throw const PublisherBackendException(
        'publisher-backend scaffold --with-starter-ui was removed. Author '
        'mini-program UI with provider-neutral backend API endpoints instead.',
      );
    }
    final miniProgramRootPath = await requireMiniProgramRoot(
      request.miniProgramRootPath,
    );
    final backendRootPath = p.join(miniProgramRootPath, 'backend', 'mock');
    final createdPaths = <String>[];
    final files = buildMockPublisherBackendFiles(
      miniProgramRootPath: miniProgramRootPath,
    );
    for (final entry in files.entries) {
      await _writeManagedFile(
        filePath: p.join(backendRootPath, entry.key),
        contents: entry.value,
        force: request.force,
        createdPaths: createdPaths,
      );
    }
    createdPaths.sort();
    return PublisherBackendScaffoldResult(
      miniProgramRootPath: miniProgramRootPath,
      backendRootPath: backendRootPath,
      template: request.template,
      createdPaths: createdPaths,
      storageMode: request.storageMode,
    );
  }

  Future<String> requireMiniProgramRoot(String rawRootPath) async {
    final rootPath = p.normalize(p.absolute(rawRootPath));
    final manifestFile = File(p.join(rootPath, 'manifest.json'));
    if (!await manifestFile.exists()) {
      throw PublisherBackendException(
        'Mini-program root is missing manifest.json: $rootPath',
      );
    }
    return rootPath;
  }

  Future<void> assertMockBackendPaths(String backendRootPath) async {
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
}
