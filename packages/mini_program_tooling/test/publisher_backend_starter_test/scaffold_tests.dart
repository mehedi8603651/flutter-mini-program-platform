part of '../publisher_backend_starter_test.dart';

void _registerScaffoldTests() {
  test('scaffolds mock Publisher API files and respects force', () async {
    final starter = const PublisherBackendStarter();
    final result = await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
      ),
    );

    expect(result.template, 'mock');
    expect(result.storageMode, 'bundled');
    expect(
      await File(
        p.join(miniProgramRoot.path, 'backend', 'mock', 'bin', 'server.dart'),
      ).exists(),
      isTrue,
    );
    expect(
      await File(
        p.join(
          miniProgramRoot.path,
          'backend',
          'mock',
          'data',
          'home_bootstrap.json',
        ),
      ).exists(),
      isTrue,
    );

    final readme = File(
      p.join(miniProgramRoot.path, 'backend', 'mock', 'README.md'),
    );
    await readme.writeAsString('custom');
    expect(
      () => starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
        ),
      ),
      throwsA(isA<PublisherBackendException>()),
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        force: true,
      ),
    );
    expect(await readme.readAsString(), contains('mock publisher backend'));
  });

  test('rejects removed provider templates with migration message', () {
    final starter = const PublisherBackendStarter();
    for (final template in <String>['aws-lambda', 'firebase-functions']) {
      expect(
        () => starter.scaffold(
          PublisherBackendScaffoldRequest(
            miniProgramRootPath: miniProgramRoot.path,
            template: template,
          ),
        ),
        throwsA(
          isA<PublisherBackendException>().having(
            (error) => error.message,
            'message',
            contains('provider templates were removed'),
          ),
        ),
      );
    }
  });

  test('rejects provider storage modes with migration message', () {
    final starter = const PublisherBackendStarter();
    expect(
      () => starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          storageMode: 'firestore',
        ),
      ),
      throwsA(
        isA<PublisherBackendException>().having(
          (error) => error.message,
          'message',
          contains('real storage belongs on your external middle server'),
        ),
      ),
    );
  });

  test('rejects removed starter UI flag with migration message', () {
    final starter = const PublisherBackendStarter();
    expect(
      () => starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          withStarterUi: true,
        ),
      ),
      throwsA(
        isA<PublisherBackendException>().having(
          (error) => error.message,
          'message',
          contains('--with-starter-ui was removed'),
        ),
      ),
    );
  });
}
