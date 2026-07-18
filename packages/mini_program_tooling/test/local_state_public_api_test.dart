import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test('local CLI state public API remains available from the barrel', () {
    const store = LocalCliStateStore(
      homeDirectoryPath: 'home',
      localAppDataDirectoryPath: 'local-app-data',
    );
    const backend = LocalBackendState(
      pid: 10,
      port: 8080,
      bindHost: '127.0.0.1',
      healthCheckUrl: 'http://127.0.0.1:8080/health',
      stdoutLogPath: 'stdout.log',
      stderrLogPath: 'stderr.log',
      startedAtUtc: '2026-07-18T00:00:00.000Z',
    );
    const artifact = PublishedLocalArtifactRecord(
      miniProgramId: 'calculator',
      version: '1.0.0',
      latestManifestPath: 'latest/manifest.json',
      versionedManifestPath: '1.0.0/manifest.json',
      screensDirectoryPath: '1.0.0/screens',
      publishedAtUtc: '2026-07-18T00:00:00.000Z',
    );
    const artifacts = PublishedLocalArtifactsState(
      records: <PublishedLocalArtifactRecord>[artifact],
    );
    const environment = LocalCliEnvironmentState(
      schemaVersion: 1,
      repoRootPath: null,
      activeEnvironment: 'local',
      initializedAtUtc: '2026-07-18T00:00:00.000Z',
      updatedAtUtc: '2026-07-18T00:00:00.000Z',
    );
    const workspace = LocalBackendWorkspaceState(
      schemaVersion: 1,
      backendRootPath: 'backend',
      apiRootPath: 'backend/api',
      serviceDirectoryPath: 'backend/service',
      initializedAtUtc: '2026-07-18T00:00:00.000Z',
      updatedAtUtc: '2026-07-18T00:00:00.000Z',
    );
    const resolvedEnvironment = ResolvedLocalCliEnvironmentState(
      rootPath: 'root',
      filePath: 'root/.mini_program/env.json',
      state: environment,
      scope: 'local',
    );
    const resolvedWorkspace = ResolvedLocalBackendWorkspaceState(
      rootPath: 'root',
      filePath: 'root/.mini_program/backend_workspace.json',
      state: workspace,
      scope: 'local',
    );
    const exception = LocalCliStateException('invalid state');

    expect(store, isA<LocalCliStateStore>());
    expect(backend.port, 8080);
    expect(artifacts.records.single.version, '1.0.0');
    expect(resolvedEnvironment.state, same(environment));
    expect(resolvedWorkspace.state, same(workspace));
    expect(exception.toString(), 'invalid state');
  });
}
