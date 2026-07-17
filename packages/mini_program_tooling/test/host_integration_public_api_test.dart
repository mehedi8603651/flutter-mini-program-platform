import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test('host integration public API remains available from the barrel', () {
    const embeddingInitializer = MiniProgramEmbeddingInitializer();
    const embeddingRequest = MiniProgramEmbeddingInitRequest(
      projectRootPath: 'host',
    );
    const embeddingResult = MiniProgramEmbeddingInitResult(
      projectRootPath: 'host',
      repoRootPath: null,
      packageName: 'host_app',
      hostAppId: 'host_app',
      hostVersion: '1.0.0',
      nativeRoutePath: '/native/profile-editor',
      createdPaths: <String>[],
    );
    const embeddingError = MiniProgramEmbeddingInitException('failure');

    const capabilityInstaller = MiniProgramHostCapabilityInstaller();
    const capabilityRequest = MiniProgramHostCapabilityInitRequest(
      projectRootPath: 'host',
      capability: MiniProgramHostCapabilityInstaller.locationCapability,
      platform: MiniProgramHostCapabilityInstaller.androidPlatform,
    );
    const capabilityResult = MiniProgramHostCapabilityInitResult(
      projectRootPath: 'host',
      capability: 'location',
      platform: 'android',
      createdPaths: <String>[],
      updatedPaths: <String>[],
    );
    const capabilityError = MiniProgramHostCapabilityException('failure');

    expect(embeddingInitializer, isA<MiniProgramEmbeddingInitializer>());
    expect(embeddingRequest.force, isFalse);
    expect(embeddingResult.toJson()['hostAppId'], 'host_app');
    expect(embeddingError.toString(), 'failure');
    expect(capabilityInstaller, isA<MiniProgramHostCapabilityInstaller>());
    expect(capabilityRequest.capability, 'location');
    expect(capabilityResult.alreadyInstalled, isTrue);
    expect(capabilityError.toString(), 'failure');
  });
}
