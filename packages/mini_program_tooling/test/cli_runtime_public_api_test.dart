import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test('MiniprogramCli remains available through the public barrel', () async {
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stdoutSink: stdoutBuffer,
      stderrSink: stderrBuffer,
      workingDirectory: 'workspace',
    );

    final exitCode = await cli.run(const <String>['help']);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), contains('Usage: miniprogram'));
    expect(stderrBuffer.toString(), isEmpty);
  });
}
