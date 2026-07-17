import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test('portable artifact public API remains available from the barrel', () {
    const builder = MiniProgramArtifactBuilder();
    const verifier = MiniProgramArtifactVerifier();
    const buildRequest = MiniProgramArtifactBuildRequest(
      miniProgramRootPath: 'calculator',
      skipPubGet: true,
    );
    const verifyRequest = MiniProgramArtifactVerifyRequest(
      miniProgramRootPath: 'calculator',
    );
    const exception = MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.structureInvalid,
      message: 'invalid',
    );

    expect(builder, isA<MiniProgramArtifactBuilder>());
    expect(verifier, isA<MiniProgramArtifactVerifier>());
    expect(buildRequest.skipPubGet, isTrue);
    expect(verifyRequest.miniProgramRootPath, 'calculator');
    expect(MiniProgramArtifactBuilder.artifactLayoutVersion, 1);
    expect(exception.toString(), '[artifact_structure_invalid] invalid');
  });
}
