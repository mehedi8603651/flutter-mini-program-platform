import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test('scaffolding public API remains available from the package barrel', () {
    const request = MiniProgramScaffoldRequest(miniProgramId: 'public_api_app');
    const result = MiniProgramScaffoldResult(
      repoRootPath: 'repo',
      miniProgramRootPath: 'repo/mini_programs/public_api_app',
      miniProgramId: 'public_api_app',
      title: 'Public API App',
      description: 'Public API compile guard.',
      capabilities: <String>['analytics'],
      screenFormat: 'mp',
      createdPaths: <String>['manifest.json'],
    );
    const exception = MiniProgramScaffoldException('scaffold failed');
    const scaffolder = MiniProgramScaffolder();

    expect(request.miniProgramId, 'public_api_app');
    expect(scaffolder, isA<MiniProgramScaffolder>());
    expect(exception.toString(), 'scaffold failed');
    expect(result.toJson().keys.toList(), <String>[
      'repoRootPath',
      'miniProgramRootPath',
      'miniProgramId',
      'title',
      'description',
      'capabilities',
      'screenFormat',
      'createdPaths',
    ]);
  });
}
