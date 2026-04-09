import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class LocalCliStateException implements Exception {
  const LocalCliStateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalBackendState {
  const LocalBackendState({
    required this.pid,
    required this.port,
    required this.bindHost,
    required this.healthCheckUrl,
    required this.stdoutLogPath,
    required this.stderrLogPath,
    required this.startedAtUtc,
  });

  final int pid;
  final int port;
  final String bindHost;
  final String healthCheckUrl;
  final String stdoutLogPath;
  final String stderrLogPath;
  final String startedAtUtc;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pid': pid,
    'port': port,
    'bindHost': bindHost,
    'healthCheckUrl': healthCheckUrl,
    'stdoutLogPath': stdoutLogPath,
    'stderrLogPath': stderrLogPath,
    'startedAtUtc': startedAtUtc,
  };

  factory LocalBackendState.fromJson(Map<String, dynamic> json) {
    final pid = json['pid'];
    final port = json['port'];
    final bindHost = json['bindHost'];
    final healthCheckUrl = json['healthCheckUrl'];
    final stdoutLogPath = json['stdoutLogPath'];
    final stderrLogPath = json['stderrLogPath'];
    final startedAtUtc = json['startedAtUtc'];

    if (pid is! int ||
        port is! int ||
        bindHost is! String ||
        healthCheckUrl is! String ||
        stdoutLogPath is! String ||
        stderrLogPath is! String ||
        startedAtUtc is! String) {
      throw const LocalCliStateException(
        'backend.local.json is missing required fields.',
      );
    }

    return LocalBackendState(
      pid: pid,
      port: port,
      bindHost: bindHost,
      healthCheckUrl: healthCheckUrl,
      stdoutLogPath: stdoutLogPath,
      stderrLogPath: stderrLogPath,
      startedAtUtc: startedAtUtc,
    );
  }
}

class PublishedLocalArtifactRecord {
  const PublishedLocalArtifactRecord({
    required this.miniProgramId,
    required this.version,
    required this.latestManifestPath,
    required this.versionedManifestPath,
    required this.screensDirectoryPath,
    required this.publishedAtUtc,
  });

  final String miniProgramId;
  final String version;
  final String latestManifestPath;
  final String versionedManifestPath;
  final String screensDirectoryPath;
  final String publishedAtUtc;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'miniProgramId': miniProgramId,
    'version': version,
    'latestManifestPath': latestManifestPath,
    'versionedManifestPath': versionedManifestPath,
    'screensDirectoryPath': screensDirectoryPath,
    'publishedAtUtc': publishedAtUtc,
  };

  factory PublishedLocalArtifactRecord.fromJson(Map<String, dynamic> json) {
    final miniProgramId = json['miniProgramId'];
    final version = json['version'];
    final latestManifestPath = json['latestManifestPath'];
    final versionedManifestPath = json['versionedManifestPath'];
    final screensDirectoryPath = json['screensDirectoryPath'];
    final publishedAtUtc = json['publishedAtUtc'];

    if (miniProgramId is! String ||
        version is! String ||
        latestManifestPath is! String ||
        versionedManifestPath is! String ||
        screensDirectoryPath is! String ||
        publishedAtUtc is! String) {
      throw const LocalCliStateException(
        'published_local_artifacts.json is missing required fields.',
      );
    }

    return PublishedLocalArtifactRecord(
      miniProgramId: miniProgramId,
      version: version,
      latestManifestPath: latestManifestPath,
      versionedManifestPath: versionedManifestPath,
      screensDirectoryPath: screensDirectoryPath,
      publishedAtUtc: publishedAtUtc,
    );
  }
}

class PublishedLocalArtifactsState {
  const PublishedLocalArtifactsState({
    required this.records,
  });

  final List<PublishedLocalArtifactRecord> records;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'artifacts': records.map((record) => record.toJson()).toList(),
  };

  factory PublishedLocalArtifactsState.fromJson(Map<String, dynamic> json) {
    final artifacts = json['artifacts'];
    if (artifacts is! List) {
      throw const LocalCliStateException(
        'published_local_artifacts.json must contain an "artifacts" list.',
      );
    }

    return PublishedLocalArtifactsState(
      records: artifacts
          .map((value) {
            if (value is! Map) {
              throw const LocalCliStateException(
                'published_local_artifacts.json contains a non-object artifact.',
              );
            }

            return PublishedLocalArtifactRecord.fromJson(
              value.map((key, entry) => MapEntry(key.toString(), entry)),
            );
          })
          .cast<PublishedLocalArtifactRecord>()
          .toList(),
    );
  }
}

class LocalCliStateStore {
  const LocalCliStateStore();

  String stateDirectoryPath(String repoRootPath) => p.join(
    _normalizeRoot(repoRootPath),
    '.mini_program',
  );

  String backendStatePath(String repoRootPath) => p.join(
    stateDirectoryPath(repoRootPath),
    'backend.local.json',
  );

  String publishedArtifactsPath(String repoRootPath) => p.join(
    stateDirectoryPath(repoRootPath),
    'published_local_artifacts.json',
  );

  Future<Directory> ensureStateDirectory(String repoRootPath) async {
    final directory = Directory(stateDirectoryPath(repoRootPath));
    await directory.create(recursive: true);
    return directory;
  }

  Future<LocalBackendState?> readBackendState(String repoRootPath) async {
    final file = File(backendStatePath(repoRootPath));
    if (!await file.exists()) {
      return null;
    }

    final json = await _readJsonObject(file);
    return LocalBackendState.fromJson(json);
  }

  Future<void> writeBackendState(
    String repoRootPath,
    LocalBackendState state,
  ) async {
    await ensureStateDirectory(repoRootPath);
    final file = File(backendStatePath(repoRootPath));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  Future<void> clearBackendState(String repoRootPath) async {
    final file = File(backendStatePath(repoRootPath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<PublishedLocalArtifactsState> readPublishedArtifactsState(
    String repoRootPath,
  ) async {
    final file = File(publishedArtifactsPath(repoRootPath));
    if (!await file.exists()) {
      return const PublishedLocalArtifactsState(records: <PublishedLocalArtifactRecord>[]);
    }

    final json = await _readJsonObject(file);
    return PublishedLocalArtifactsState.fromJson(json);
  }

  Future<void> writePublishedArtifactsState(
    String repoRootPath,
    PublishedLocalArtifactsState state,
  ) async {
    await ensureStateDirectory(repoRootPath);
    final file = File(publishedArtifactsPath(repoRootPath));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  Future<void> recordPublishedArtifact(
    String repoRootPath,
    PublishedLocalArtifactRecord record,
  ) async {
    final state = await readPublishedArtifactsState(repoRootPath);
    final updatedRecords = state.records
        .where(
          (existing) =>
              existing.miniProgramId != record.miniProgramId ||
              existing.version != record.version,
        )
        .toList()
      ..add(record);
    updatedRecords.sort((a, b) {
      final idComparison = a.miniProgramId.compareTo(b.miniProgramId);
      if (idComparison != 0) {
        return idComparison;
      }
      return a.version.compareTo(b.version);
    });

    await writePublishedArtifactsState(
      repoRootPath,
      PublishedLocalArtifactsState(records: updatedRecords),
    );
  }

  Future<void> clearPublishedArtifactsState(String repoRootPath) async {
    final file = File(publishedArtifactsPath(repoRootPath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Map<String, dynamic>> _readJsonObject(File file) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        throw LocalCliStateException(
          'State file is not a JSON object: ${file.path}',
        );
      }

      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } on FormatException catch (error) {
      throw LocalCliStateException(
        'State file contains invalid JSON: ${file.path}\n${error.message}',
      );
    } on FileSystemException catch (error) {
      throw LocalCliStateException(
        'Failed to read state file: ${file.path}\n$error',
      );
    }
  }

  String _normalizeRoot(String repoRootPath) =>
      p.normalize(p.absolute(repoRootPath));
}
