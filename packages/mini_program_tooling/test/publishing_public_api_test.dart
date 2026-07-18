import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test(
    'static and legacy publishing APIs remain available from the barrel',
    () {
      const buildResult = MiniProgramBuildResult(
        repoRootPath: 'repo',
        miniProgramRootPath: 'repo/mini_programs/app',
        miniProgramId: 'app',
        outputDirectoryPath: 'build',
        screensDirectoryPath: 'build/screens',
        entryScreenJsonPath: 'build/screens/home.json',
        cliSource: 'test',
        invocation: <String>['dart', 'run'],
        pubGetRan: false,
      );
      const validation = DeliveryValidationReport(
        repoRootPath: 'repo',
        messages: <DeliveryValidationMessage>[],
      );
      const staticRequest = MiniProgramStaticPublishRequest(
        repoRootPath: 'repo',
        outputPath: 'public',
        clean: true,
      );
      const staticFile = StaticPublishedFileRecord(
        relativePath: 'artifacts/app/latest.json',
        localSourcePath: 'public/artifacts/app/latest.json',
      );
      const staticResult = MiniProgramStaticPublishResult(
        outputPath: 'public',
        miniProgramId: 'app',
        version: '1.0.0',
        buildResult: buildResult,
        manifestLatestPath: 'public/artifacts/app/latest.json',
        manifestVersionPath: 'public/artifacts/app/1.0.0/manifest.json',
        screensDirectoryPath: 'public/artifacts/app/1.0.0/screens',
        metadataReleasePath: 'public/artifacts/app/1.0.0/release.json',
        metadataCatalogPath: 'public/artifacts/app/catalog.json',
        instructionsPath: 'public/PUBLISH_INSTRUCTIONS.md',
        nojekyllPath: 'public/.nojekyll',
        publishedAtUtc: '2026-07-18T00:00:00.000Z',
        writtenFiles: <StaticPublishedFileRecord>[staticFile],
        cleaned: true,
      );
      const legacyRequest = MiniProgramPublishRequest(repoRootPath: 'repo');
      const legacyResult = MiniProgramPublishResult(
        repoRootPath: 'repo',
        backendRootPath: 'backend',
        miniProgramId: 'app',
        version: '1.0.0',
        buildResult: buildResult,
        prePublishValidation: validation,
        postPublishValidation: validation,
        latestManifestPath: 'backend/artifacts/app/latest.json',
        versionedManifestPath: 'backend/artifacts/app/1.0.0/manifest.json',
        screensDirectoryPath: 'backend/artifacts/app/1.0.0/screens',
        copiedScreenCount: 1,
      );
      const exception = MiniProgramPublishException('publish failed');

      expect(
        const MiniProgramStaticPublisher(),
        isA<MiniProgramStaticPublisher>(),
      );
      expect(const MiniProgramPublisher(), isA<MiniProgramPublisher>());
      expect(staticRequest.clean, isTrue);
      expect(
        staticResult.writtenFiles.single.relativePath,
        staticFile.relativePath,
      );
      expect(legacyRequest.repoRootPath, 'repo');
      expect(legacyResult.toJson()['copiedScreenCount'], 1);
      expect(exception.toString(), 'publish failed');
    },
  );
}
