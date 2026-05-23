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

class CloudEnvironmentConfiguration {
  const CloudEnvironmentConfiguration({
    required this.name,
    required this.provider,
    required this.values,
    required this.configuredAtUtc,
    required this.updatedAtUtc,
  });

  static const List<String> supportedProviders = <String>[
    'aws',
    'firebase',
    'gcp',
    'custom-s3-compatible',
  ];

  final String name;
  final String provider;
  final Map<String, dynamic> values;
  final String configuredAtUtc;
  final String updatedAtUtc;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'provider': provider,
    'values': values,
    'configuredAtUtc': configuredAtUtc,
    'updatedAtUtc': updatedAtUtc,
  };

  CloudEnvironmentConfiguration copyWith({
    String? provider,
    Map<String, dynamic>? values,
    String? configuredAtUtc,
    String? updatedAtUtc,
  }) {
    return CloudEnvironmentConfiguration(
      name: name,
      provider: provider ?? this.provider,
      values: values ?? this.values,
      configuredAtUtc: configuredAtUtc ?? this.configuredAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  factory CloudEnvironmentConfiguration.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final provider = json['provider'];
    final rawValues = json['values'];
    final configuredAtUtc = json['configuredAtUtc'];
    final updatedAtUtc = json['updatedAtUtc'];

    if (name is! String ||
        provider is! String ||
        rawValues is! Map ||
        configuredAtUtc is! String ||
        updatedAtUtc is! String) {
      throw const LocalCliStateException(
        'env.json contains an invalid cloud environment entry.',
      );
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty || !_isSafeEnvironmentName(trimmedName)) {
      throw LocalCliStateException(
        'env.json contains an invalid cloud environment name: $name',
      );
    }

    if (!supportedProviders.contains(provider)) {
      throw LocalCliStateException(
        'env.json contains an unsupported cloud provider: $provider',
      );
    }

    return CloudEnvironmentConfiguration(
      name: trimmedName,
      provider: provider,
      values: rawValues.map((key, value) => MapEntry(key.toString(), value)),
      configuredAtUtc: configuredAtUtc,
      updatedAtUtc: updatedAtUtc,
    );
  }
}

class EmbeddedHostCloudConfiguration {
  const EmbeddedHostCloudConfiguration({
    required this.environmentName,
    required this.provider,
    required this.backendApiBaseUrl,
    required this.configuredAtUtc,
    required this.updatedAtUtc,
  });

  final String environmentName;
  final String provider;
  final String backendApiBaseUrl;
  final String configuredAtUtc;
  final String updatedAtUtc;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'environmentName': environmentName,
    'provider': provider,
    'backendApiBaseUrl': backendApiBaseUrl,
    'configuredAtUtc': configuredAtUtc,
    'updatedAtUtc': updatedAtUtc,
  };

  factory EmbeddedHostCloudConfiguration.fromJson(Map<String, dynamic> json) {
    final environmentName = json['environmentName'];
    final provider = json['provider'];
    final backendApiBaseUrl = json['backendApiBaseUrl'];
    final configuredAtUtc = json['configuredAtUtc'];
    final updatedAtUtc = json['updatedAtUtc'];

    if (environmentName is! String ||
        provider is! String ||
        backendApiBaseUrl is! String ||
        configuredAtUtc is! String ||
        updatedAtUtc is! String) {
      throw const LocalCliStateException(
        'host_cloud.json is missing required fields.',
      );
    }

    final trimmedEnvironmentName = environmentName.trim();
    final trimmedProvider = provider.trim();
    final trimmedBackendApiBaseUrl = backendApiBaseUrl.trim();
    if (trimmedEnvironmentName.isEmpty ||
        !_isSafeEnvironmentName(trimmedEnvironmentName)) {
      throw LocalCliStateException(
        'host_cloud.json contains an invalid environmentName value: '
        '$environmentName',
      );
    }
    if (!CloudEnvironmentConfiguration.supportedProviders.contains(
      trimmedProvider,
    )) {
      throw LocalCliStateException(
        'host_cloud.json contains an unsupported provider: $provider',
      );
    }
    if (trimmedBackendApiBaseUrl.isEmpty) {
      throw const LocalCliStateException(
        'host_cloud.json contains a blank backendApiBaseUrl value.',
      );
    }

    return EmbeddedHostCloudConfiguration(
      environmentName: trimmedEnvironmentName,
      provider: trimmedProvider,
      backendApiBaseUrl: trimmedBackendApiBaseUrl,
      configuredAtUtc: configuredAtUtc,
      updatedAtUtc: updatedAtUtc,
    );
  }
}

class LocalCliEnvironmentState {
  const LocalCliEnvironmentState({
    required this.schemaVersion,
    required this.repoRootPath,
    required this.activeEnvironment,
    this.cloudEnvironments = const <CloudEnvironmentConfiguration>[],
    required this.initializedAtUtc,
    required this.updatedAtUtc,
  });

  final int schemaVersion;
  final String? repoRootPath;
  final String activeEnvironment;
  final List<CloudEnvironmentConfiguration> cloudEnvironments;
  final String initializedAtUtc;
  final String updatedAtUtc;

  CloudEnvironmentConfiguration? cloudEnvironmentNamed(String name) {
    final trimmedName = name.trim();
    for (final environment in cloudEnvironments) {
      if (environment.name == trimmedName) {
        return environment;
      }
    }
    return null;
  }

  LocalCliEnvironmentState copyWith({
    int? schemaVersion,
    String? repoRootPath,
    String? activeEnvironment,
    List<CloudEnvironmentConfiguration>? cloudEnvironments,
    String? initializedAtUtc,
    String? updatedAtUtc,
  }) {
    return LocalCliEnvironmentState(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      repoRootPath: repoRootPath ?? this.repoRootPath,
      activeEnvironment: activeEnvironment ?? this.activeEnvironment,
      cloudEnvironments: cloudEnvironments ?? this.cloudEnvironments,
      initializedAtUtc: initializedAtUtc ?? this.initializedAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'activeEnvironment': activeEnvironment,
      'cloudEnvironments': cloudEnvironments
          .map((environment) => environment.toJson())
          .toList(),
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
    final rawCloudEnvironments = json['cloudEnvironments'];
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
    if (rawCloudEnvironments != null && rawCloudEnvironments is! List) {
      throw const LocalCliStateException(
        'env.json contains an invalid cloudEnvironments value.',
      );
    }

    final cloudEnvironments =
        (rawCloudEnvironments as List? ?? const <Object>[])
            .map((value) {
              if (value is! Map) {
                throw const LocalCliStateException(
                  'env.json contains a non-object cloud environment entry.',
                );
              }
              return CloudEnvironmentConfiguration.fromJson(
                value.map((key, entry) => MapEntry(key.toString(), entry)),
              );
            })
            .cast<CloudEnvironmentConfiguration>()
            .toList();
    final seenNames = <String>{};
    for (final environment in cloudEnvironments) {
      if (!seenNames.add(environment.name)) {
        throw LocalCliStateException(
          'env.json contains duplicate cloud environment name: '
          '${environment.name}',
        );
      }
    }

    final trimmedActiveEnvironment = activeEnvironment.trim();
    if (trimmedActiveEnvironment.isEmpty) {
      throw const LocalCliStateException(
        'env.json contains a blank activeEnvironment value.',
      );
    }
    final isKnownActiveEnvironment =
        trimmedActiveEnvironment == 'local' ||
        trimmedActiveEnvironment == 'cloud' ||
        cloudEnvironments.any(
          (environment) => environment.name == trimmedActiveEnvironment,
        );
    if (!isKnownActiveEnvironment) {
      throw LocalCliStateException(
        'env.json contains an unsupported activeEnvironment: '
        '$activeEnvironment',
      );
    }

    return LocalCliEnvironmentState(
      schemaVersion: schemaVersion,
      repoRootPath: rawRepoRootPath == null || rawRepoRootPath.trim().isEmpty
          ? null
          : p.normalize(p.absolute(rawRepoRootPath)),
      activeEnvironment: trimmedActiveEnvironment,
      cloudEnvironments: cloudEnvironments,
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

class LocalCliStateStore {
  const LocalCliStateStore({
    String? homeDirectoryPath,
    String? localAppDataDirectoryPath,
  }) : _homeDirectoryPath = homeDirectoryPath,
       _localAppDataDirectoryPath = localAppDataDirectoryPath;

  final String? _homeDirectoryPath;
  final String? _localAppDataDirectoryPath;

  String stateDirectoryPath(String rootPath) =>
      p.join(_normalizeRoot(rootPath), '.mini_program');

  String backendStatePath(String repoRootPath) =>
      p.join(stateDirectoryPath(repoRootPath), 'backend.local.json');

  String publishedArtifactsPath(String repoRootPath) => p.join(
    stateDirectoryPath(repoRootPath),
    'published_local_artifacts.json',
  );

  String environmentStatePath(String rootPath) =>
      p.join(stateDirectoryPath(rootPath), 'env.json');

  String hostCloudConfigurationPath(String rootPath) =>
      p.join(stateDirectoryPath(rootPath), 'host_cloud.json');

  String backendWorkspaceStatePath(String rootPath) =>
      p.join(stateDirectoryPath(rootPath), 'backend_workspace.json');

  String globalStateDirectoryPath() =>
      p.join(_normalizeHomeDirectoryPath(), '.mini_program');

  String globalEnvironmentStatePath() =>
      p.join(globalStateDirectoryPath(), 'global_env.json');

  String globalBackendWorkspaceStatePath() =>
      p.join(globalStateDirectoryPath(), 'global_backend_workspace.json');

  String defaultBackendWorkspaceRootPath() {
    if (Platform.isWindows) {
      return p.join(
        _normalizeLocalAppDataDirectoryPath(),
        'mini_program',
        'backend',
      );
    }

    return p.join(globalStateDirectoryPath(), 'backend');
  }

  Future<Directory> ensureStateDirectory(String rootPath) async {
    final directory = Directory(stateDirectoryPath(rootPath));
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
      return const PublishedLocalArtifactsState(
        records: <PublishedLocalArtifactRecord>[],
      );
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
    final updatedRecords =
        state.records
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

  Future<LocalCliEnvironmentState?> readEnvironmentState(
    String rootPath,
  ) async {
    final file = File(environmentStatePath(rootPath));
    if (!await file.exists()) {
      return null;
    }

    final json = await _readJsonObject(file);
    return LocalCliEnvironmentState.fromJson(json);
  }

  Future<void> writeEnvironmentState(
    String rootPath,
    LocalCliEnvironmentState state,
  ) async {
    await ensureStateDirectory(rootPath);
    final file = File(environmentStatePath(rootPath));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  Future<EmbeddedHostCloudConfiguration?> readHostCloudConfiguration(
    String rootPath,
  ) async {
    final file = File(hostCloudConfigurationPath(rootPath));
    if (!await file.exists()) {
      return null;
    }

    final json = await _readJsonObject(file);
    return EmbeddedHostCloudConfiguration.fromJson(json);
  }

  Future<void> writeHostCloudConfiguration(
    String rootPath,
    EmbeddedHostCloudConfiguration configuration,
  ) async {
    await ensureStateDirectory(rootPath);
    final file = File(hostCloudConfigurationPath(rootPath));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(configuration.toJson()),
    );
  }

  Future<LocalCliEnvironmentState?> readGlobalEnvironmentState() async {
    final file = File(globalEnvironmentStatePath());
    if (!await file.exists()) {
      return null;
    }

    final json = await _readJsonObject(file);
    return LocalCliEnvironmentState.fromJson(json);
  }

  Future<void> writeGlobalEnvironmentState(
    LocalCliEnvironmentState state,
  ) async {
    final directory = Directory(globalStateDirectoryPath());
    await directory.create(recursive: true);
    final file = File(globalEnvironmentStatePath());
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  Future<ResolvedLocalCliEnvironmentState?> discoverEnvironmentState({
    String? currentWorkingDirectory,
    Iterable<String> additionalSearchRoots = const <String>[],
    bool includeGlobalFallback = true,
  }) async {
    final startDirectories = <String>{
      p.normalize(
        p.absolute(currentWorkingDirectory ?? Directory.current.path),
      ),
      ...additionalSearchRoots
          .where((path) => path.trim().isNotEmpty)
          .map((path) => p.normalize(p.absolute(path))),
    };

    for (final startDirectory in startDirectories) {
      final rootPath = await _discoverEnvironmentRoot(
        startDirectory: startDirectory,
      );
      if (rootPath != null) {
        final state = await readEnvironmentState(rootPath);
        if (state != null) {
          return ResolvedLocalCliEnvironmentState(
            rootPath: rootPath,
            filePath: environmentStatePath(rootPath),
            state: state,
            scope: 'local',
          );
        }
      }
    }

    if (includeGlobalFallback) {
      final globalState = await readGlobalEnvironmentState();
      if (globalState != null) {
        return ResolvedLocalCliEnvironmentState(
          rootPath: _normalizeHomeDirectoryPath(),
          filePath: globalEnvironmentStatePath(),
          state: globalState,
          scope: 'global',
        );
      }
    }

    return null;
  }

  Future<LocalBackendWorkspaceState?> readBackendWorkspaceState(
    String rootPath,
  ) async {
    final file = File(backendWorkspaceStatePath(rootPath));
    if (!await file.exists()) {
      return null;
    }

    final json = await _readJsonObject(file);
    return LocalBackendWorkspaceState.fromJson(json);
  }

  Future<void> writeBackendWorkspaceState(
    String rootPath,
    LocalBackendWorkspaceState state,
  ) async {
    await ensureStateDirectory(rootPath);
    final file = File(backendWorkspaceStatePath(rootPath));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  Future<LocalBackendWorkspaceState?> readGlobalBackendWorkspaceState() async {
    final file = File(globalBackendWorkspaceStatePath());
    if (!await file.exists()) {
      return null;
    }

    final json = await _readJsonObject(file);
    return LocalBackendWorkspaceState.fromJson(json);
  }

  Future<void> writeGlobalBackendWorkspaceState(
    LocalBackendWorkspaceState state,
  ) async {
    final directory = Directory(globalStateDirectoryPath());
    await directory.create(recursive: true);
    final file = File(globalBackendWorkspaceStatePath());
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
    );
  }

  Future<ResolvedLocalBackendWorkspaceState?> discoverBackendWorkspaceState({
    String? currentWorkingDirectory,
    Iterable<String> additionalSearchRoots = const <String>[],
    bool includeGlobalFallback = true,
  }) async {
    final startDirectories = <String>{
      p.normalize(
        p.absolute(currentWorkingDirectory ?? Directory.current.path),
      ),
      ...additionalSearchRoots
          .where((path) => path.trim().isNotEmpty)
          .map((path) => p.normalize(p.absolute(path))),
    };

    for (final startDirectory in startDirectories) {
      final rootPath = await _discoverBackendWorkspaceRoot(
        startDirectory: startDirectory,
      );
      if (rootPath != null) {
        final state = await readBackendWorkspaceState(rootPath);
        if (state != null) {
          return ResolvedLocalBackendWorkspaceState(
            rootPath: rootPath,
            filePath: backendWorkspaceStatePath(rootPath),
            state: state,
            scope: 'local',
          );
        }
      }
    }

    if (includeGlobalFallback) {
      final globalState = await readGlobalBackendWorkspaceState();
      if (globalState != null) {
        return ResolvedLocalBackendWorkspaceState(
          rootPath: _normalizeHomeDirectoryPath(),
          filePath: globalBackendWorkspaceStatePath(),
          state: globalState,
          scope: 'global',
        );
      }
    }

    return null;
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

  String _normalizeHomeDirectoryPath() => p.normalize(
    p.absolute(_homeDirectoryPath ?? _resolveHomeDirectoryPath()),
  );

  String _normalizeLocalAppDataDirectoryPath() => p.normalize(
    p.absolute(
      _localAppDataDirectoryPath ?? _resolveLocalAppDataDirectoryPath(),
    ),
  );

  Future<String?> _discoverEnvironmentRoot({
    required String startDirectory,
  }) async {
    var cursor = p.normalize(p.absolute(startDirectory));
    while (true) {
      final file = File(environmentStatePath(cursor));
      if (await file.exists()) {
        return cursor;
      }

      final parent = p.dirname(cursor);
      if (parent == cursor) {
        return null;
      }
      cursor = parent;
    }
  }

  Future<String?> _discoverBackendWorkspaceRoot({
    required String startDirectory,
  }) async {
    var cursor = p.normalize(p.absolute(startDirectory));
    while (true) {
      final file = File(backendWorkspaceStatePath(cursor));
      if (await file.exists()) {
        return cursor;
      }

      final parent = p.dirname(cursor);
      if (parent == cursor) {
        return null;
      }
      cursor = parent;
    }
  }

  String _resolveHomeDirectoryPath() {
    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return home;
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.trim().isNotEmpty) {
      return userProfile;
    }

    final homeDrive = Platform.environment['HOMEDRIVE'];
    final homePath = Platform.environment['HOMEPATH'];
    if (homeDrive != null &&
        homeDrive.trim().isNotEmpty &&
        homePath != null &&
        homePath.trim().isNotEmpty) {
      return '$homeDrive$homePath';
    }

    return Directory.current.path;
  }

  String _resolveLocalAppDataDirectoryPath() {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.trim().isNotEmpty) {
      return localAppData;
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.trim().isNotEmpty) {
      return p.join(userProfile, 'AppData', 'Local');
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return p.join(home, 'AppData', 'Local');
    }

    return p.join(_resolveHomeDirectoryPath(), 'AppData', 'Local');
  }
}

bool _isSafeEnvironmentName(String value) =>
    RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value);
