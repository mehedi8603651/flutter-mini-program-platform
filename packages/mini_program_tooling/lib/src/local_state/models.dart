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
  const PublishedLocalArtifactsState({required this.records});

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

class LocalCliEnvironmentState {
  const LocalCliEnvironmentState({
    required this.schemaVersion,
    required this.repoRootPath,
    required this.activeEnvironment,
    required this.initializedAtUtc,
    required this.updatedAtUtc,
  });

  final int schemaVersion;
  final String? repoRootPath;
  final String activeEnvironment;
  final String initializedAtUtc;
  final String updatedAtUtc;

  LocalCliEnvironmentState copyWith({
    int? schemaVersion,
    String? repoRootPath,
    String? activeEnvironment,
    String? initializedAtUtc,
    String? updatedAtUtc,
  }) {
    return LocalCliEnvironmentState(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      repoRootPath: repoRootPath ?? this.repoRootPath,
      activeEnvironment: activeEnvironment ?? this.activeEnvironment,
      initializedAtUtc: initializedAtUtc ?? this.initializedAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'activeEnvironment': activeEnvironment,
      'initializedAtUtc': initializedAtUtc,
      'updatedAtUtc': updatedAtUtc,
    };
    if (repoRootPath != null) {
      json['repoRootPath'] = repoRootPath;
    }
    return json;
  }

  factory LocalCliEnvironmentState.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    final rawRepoRootPath = json['repoRootPath'];
    final activeEnvironment = json['activeEnvironment'];
    final initializedAtUtc = json['initializedAtUtc'];
    final updatedAtUtc = json['updatedAtUtc'];

    if (schemaVersion is! int ||
        activeEnvironment is! String ||
        initializedAtUtc is! String ||
        updatedAtUtc is! String) {
      throw const LocalCliStateException(
        'env.json is missing required fields.',
      );
    }
    if (rawRepoRootPath != null && rawRepoRootPath is! String) {
      throw const LocalCliStateException(
        'env.json contains an invalid repoRootPath value.',
      );
    }
    final trimmedActiveEnvironment = activeEnvironment.trim();
    if (trimmedActiveEnvironment.isEmpty) {
      throw const LocalCliStateException(
        'env.json contains a blank activeEnvironment value.',
      );
    }

    return LocalCliEnvironmentState(
      schemaVersion: schemaVersion,
      repoRootPath: rawRepoRootPath == null || rawRepoRootPath.trim().isEmpty
          ? null
          : p.normalize(p.absolute(rawRepoRootPath)),
      activeEnvironment: 'local',
      initializedAtUtc: initializedAtUtc,
      updatedAtUtc: updatedAtUtc,
    );
  }
}

class LocalBackendWorkspaceState {
  const LocalBackendWorkspaceState({
    required this.schemaVersion,
    required this.backendRootPath,
    required this.apiRootPath,
    required this.serviceDirectoryPath,
    required this.initializedAtUtc,
    required this.updatedAtUtc,
  });

  final int schemaVersion;
  final String backendRootPath;
  final String apiRootPath;
  final String serviceDirectoryPath;
  final String initializedAtUtc;
  final String updatedAtUtc;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'backendRootPath': backendRootPath,
    'apiRootPath': apiRootPath,
    'serviceDirectoryPath': serviceDirectoryPath,
    'initializedAtUtc': initializedAtUtc,
    'updatedAtUtc': updatedAtUtc,
  };

  factory LocalBackendWorkspaceState.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    final backendRootPath = json['backendRootPath'];
    final apiRootPath = json['apiRootPath'];
    final serviceDirectoryPath = json['serviceDirectoryPath'];
    final initializedAtUtc = json['initializedAtUtc'];
    final updatedAtUtc = json['updatedAtUtc'];

    if (schemaVersion is! int ||
        backendRootPath is! String ||
        apiRootPath is! String ||
        serviceDirectoryPath is! String ||
        initializedAtUtc is! String ||
        updatedAtUtc is! String) {
      throw const LocalCliStateException(
        'backend_workspace.json is missing required fields.',
      );
    }

    return LocalBackendWorkspaceState(
      schemaVersion: schemaVersion,
      backendRootPath: p.normalize(p.absolute(backendRootPath)),
      apiRootPath: p.normalize(p.absolute(apiRootPath)),
      serviceDirectoryPath: p.normalize(p.absolute(serviceDirectoryPath)),
      initializedAtUtc: initializedAtUtc,
      updatedAtUtc: updatedAtUtc,
    );
  }
}

class ResolvedLocalCliEnvironmentState {
  const ResolvedLocalCliEnvironmentState({
    required this.rootPath,
    required this.filePath,
    required this.state,
    required this.scope,
  });

  final String rootPath;
  final String filePath;
  final LocalCliEnvironmentState state;
  final String scope;

  ResolvedLocalCliEnvironmentState copyWithState(
    LocalCliEnvironmentState state,
  ) {
    return ResolvedLocalCliEnvironmentState(
      rootPath: rootPath,
      filePath: filePath,
      state: state,
      scope: scope,
    );
  }
}

class ResolvedLocalBackendWorkspaceState {
  const ResolvedLocalBackendWorkspaceState({
    required this.rootPath,
    required this.filePath,
    required this.state,
    required this.scope,
  });

  final String rootPath;
  final String filePath;
  final LocalBackendWorkspaceState state;
  final String scope;
}
