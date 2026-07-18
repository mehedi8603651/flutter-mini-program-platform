import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test('path resolution public API remains available from the barrel', () {
    const resolver = MiniProgramPathResolver();
    const exception = MiniProgramPathResolutionException('resolution failed');
    const result = ResolvedMiniProgramPaths(
      repoRootPath: 'repo',
      miniProgramRootPath: 'repo/mini_programs/calculator',
      miniProgramId: 'calculator',
      isRepoManaged: true,
      checkedPaths: <String>['current directory: repo'],
    );

    expect(resolver, isA<MiniProgramPathResolver>());
    expect(exception.toString(), 'resolution failed');
    expect(result.miniProgramId, 'calculator');
    expect(result.isRepoManaged, isTrue);
  });
}
