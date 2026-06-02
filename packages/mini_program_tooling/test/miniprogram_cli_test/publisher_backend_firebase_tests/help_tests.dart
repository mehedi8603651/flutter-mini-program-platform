part of '../../miniprogram_cli_test.dart';

void _registerPublisherBackendFirebaseHelpTests() {
  test('publisher-backend firebase help includes operations', () async {
    final stdoutBuffer = StringBuffer();

    final exitCode = await MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      workingDirectory: tempDir.path,
    ).run(<String>['publisher-backend', 'firebase', '--help']);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), contains('deploy --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('status --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('outputs --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('host-command --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('handoff --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('auth status --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('smoke --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('seed --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('data status --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('data export --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('data import --env <env-name>'));
    expect(
      stdoutBuffer.toString(),
      contains('data redemptions --env <env-name>'),
    );
    expect(stdoutBuffer.toString(), contains('destroy --env <env-name>'));
  });
}
