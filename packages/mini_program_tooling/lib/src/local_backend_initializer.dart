import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'local_cli_state.dart';

class LocalBackendInitException implements Exception {
  const LocalBackendInitException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalBackendInitRequest {
  const LocalBackendInitRequest({this.backendRootPath, this.force = false});

  final String? backendRootPath;
  final bool force;
}

class LocalBackendInitResult {
  const LocalBackendInitResult({
    required this.backendRootPath,
    required this.apiRootPath,
    required this.serviceDirectoryPath,
    required this.stateFilePath,
    required this.globalStateFilePath,
    required this.createdPaths,
  });

  final String backendRootPath;
  final String apiRootPath;
  final String serviceDirectoryPath;
  final String stateFilePath;
  final String globalStateFilePath;
  final List<String> createdPaths;
}

class LocalBackendInitializer {
  const LocalBackendInitializer({
    LocalCliStateStore stateStore = const LocalCliStateStore(),
    String? templateRootPath,
  }) : _stateStore = stateStore,
       _templateRootPath = templateRootPath;

  final LocalCliStateStore _stateStore;
  final String? _templateRootPath;

  Future<LocalBackendInitResult> initialize(
    LocalBackendInitRequest request,
  ) async {
    final backendRootPath = p.normalize(
      p.absolute(
        request.backendRootPath ??
            _stateStore.defaultBackendWorkspaceRootPath(),
      ),
    );
    final templateRootPath = await _resolveTemplateRootPath();
    final templateDirectory = Directory(templateRootPath);
    if (!await templateDirectory.exists()) {
      throw LocalBackendInitException(
        'Backend workspace template was not found: $templateRootPath',
      );
    }

    final createdPaths = <String>[];
    await _copyTemplateTree(
      sourceRootPath: templateRootPath,
      destinationRootPath: backendRootPath,
      force: request.force,
      createdPaths: createdPaths,
    );

    final apiRootPath = p.join(backendRootPath, 'backend', 'api');
    final serviceDirectoryPath = p.join(
      backendRootPath,
      'backend',
      'local_backend_service',
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final existingState = await _stateStore.readBackendWorkspaceState(
      backendRootPath,
    );
    final state = LocalBackendWorkspaceState(
      schemaVersion: 1,
      backendRootPath: backendRootPath,
      apiRootPath: apiRootPath,
      serviceDirectoryPath: serviceDirectoryPath,
      initializedAtUtc: existingState?.initializedAtUtc ?? now,
      updatedAtUtc: now,
    );
    await _stateStore.writeBackendWorkspaceState(backendRootPath, state);
    await _stateStore.writeGlobalBackendWorkspaceState(state);

    final stateFilePath = _stateStore.backendWorkspaceStatePath(
      backendRootPath,
    );
    final globalStateFilePath = _stateStore.globalBackendWorkspaceStatePath();
    if (!createdPaths.contains(stateFilePath)) {
      createdPaths.add(stateFilePath);
    }
    if (!createdPaths.contains(globalStateFilePath)) {
      createdPaths.add(globalStateFilePath);
    }
    createdPaths.sort();

    return LocalBackendInitResult(
      backendRootPath: backendRootPath,
      apiRootPath: apiRootPath,
      serviceDirectoryPath: serviceDirectoryPath,
      stateFilePath: stateFilePath,
      globalStateFilePath: globalStateFilePath,
      createdPaths: createdPaths,
    );
  }

  Future<void> _copyTemplateTree({
    required String sourceRootPath,
    required String destinationRootPath,
    required bool force,
    required List<String> createdPaths,
  }) async {
    final destinationRootDirectory = Directory(destinationRootPath);
    await destinationRootDirectory.create(recursive: true);

    final sourceRootDirectory = Directory(sourceRootPath);
    final entities = await sourceRootDirectory
        .list(recursive: true, followLinks: false)
        .toList();
    entities.sort((a, b) => a.path.compareTo(b.path));

    for (final entity in entities) {
      final relativePath = p.relative(entity.path, from: sourceRootPath);
      final destinationPath = p.join(destinationRootPath, relativePath);

      if (entity is Directory) {
        final directory = Directory(destinationPath);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
          createdPaths.add(destinationPath);
        }
        continue;
      }

      if (entity is! File) {
        continue;
      }

      final sourceBytes = await entity.readAsBytes();
      final destinationFile = File(destinationPath);
      final destinationDirectory = Directory(p.dirname(destinationPath));
      await destinationDirectory.create(recursive: true);

      if (await destinationFile.exists()) {
        final existingBytes = await destinationFile.readAsBytes();
        if (_listEquals(existingBytes, sourceBytes)) {
          continue;
        }
        if (!force) {
          throw LocalBackendInitException(
            'Backend init would overwrite an existing file. '
            'Re-run with --force if you want to replace scaffold-managed '
            'files.\n$destinationPath',
          );
        }
      } else {
        createdPaths.add(destinationPath);
      }

      await destinationFile.writeAsBytes(sourceBytes, flush: true);
    }
  }

  Future<String> _resolveTemplateRootPath() async {
    final templateRootPath = _templateRootPath;
    if (templateRootPath != null && templateRootPath.trim().isNotEmpty) {
      return p.normalize(p.absolute(templateRootPath));
    }

    final packageUri = await Isolate.resolvePackageUri(
      Uri.parse('package:mini_program_tooling/mini_program_tooling.dart'),
    );
    if (packageUri == null || packageUri.scheme != 'file') {
      throw const LocalBackendInitException(
        'Could not resolve the installed mini_program_tooling package root.',
      );
    }

    final packageLibPath = p.fromUri(packageUri);
    final packageRootPath = p.dirname(p.dirname(packageLibPath));
    return p.join(packageRootPath, 'templates', 'backend_workspace');
  }

  bool _listEquals(List<int> left, List<int> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
