import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  group('CLI runtime parity', () {
    test('root help keeps its exact output and exit code', () async {
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final exitCode = await MiniprogramCli(
        stdoutSink: stdoutBuffer,
        stderrSink: stderrBuffer,
      ).run(const <String>[]);

      expect(exitCode, 0);
      expect(stderrBuffer.toString(), isEmpty);
      expect(stdoutBuffer.toString(), '''
Usage: miniprogram <command> [arguments]

Commands:
  create <mini-program-id> [--screen-format mp] [--with-backend mock]
  capabilities [--json]
  doctor [--json]
  env init|list|status
  env use local
  build [mini-program-id]
  artifact build [mini-program-id]
  artifact verify [mini-program-id]
  preview -d <chrome|edge|ios|linux|macos|windows|emulator-5554|android-device-id|android-wifi-device-id> [mini-program-id]
  validate [mini-program-id]
  publish [mini-program-id] [--target local|static] [--output <folder>] [--clean]
  workflow status [--workspace <path>] [--env <env-name>] [--remote] [--json]
  partner package <mini-program-id> --artifact-base-url <url>
  host run -d <device>
  host endpoint add <mini-program-id> --artifact-base-url <url> [--title <title>]
  host endpoint import <partner-package.json>
  host capability init location --platform android [--project-root <path>]
  embed init [--project-root <path>]
  artifact-host init [--root <path>]
  artifact-host start --port 8080
  artifact-host stop
  artifact-host status [--json]
  artifact-host reset-local --yes
  backend <command> (legacy alias for artifact-host)
  publisher-api scaffold --template mock
  publisher-api contract init|validate|smoke|handoff [options]
  publisher-api run --port 9090
  publisher-api status [--json]
  publisher-api stop
  publisher-api urls
  publisher-backend <command> (legacy alias for publisher-api)

Use `miniprogram <command> --help`, `miniprogram <group> --help`, or
`miniprogram <group> <command> --help` for command-specific options.

''');
    });

    test('unknown commands keep stderr routing and usage exit code', () async {
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final exitCode = await MiniprogramCli(
        stdoutSink: stdoutBuffer,
        stderrSink: stderrBuffer,
      ).run(const <String>['unknown']);

      expect(exitCode, 64);
      expect(stdoutBuffer.toString(), isEmpty);
      expect(
        stderrBuffer.toString(),
        startsWith('Unknown command: unknown\nUsage: miniprogram'),
      );
      expect(
        stderrBuffer.toString(),
        endsWith('for command-specific options.\n\n'),
      );
    });

    test('format failures keep exit code 64 and exact stderr text', () async {
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final exitCode = await MiniprogramCli(
        stdoutSink: stdoutBuffer,
        stderrSink: stderrBuffer,
      ).run(const <String>['create']);

      expect(exitCode, 64);
      expect(stdoutBuffer.toString(), isEmpty);
      expect(
        stderrBuffer.toString(),
        'create expects exactly one <mini-program-id> positional argument.\n',
      );
    });

    test('removed cloud command keeps its migration failure', () async {
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final exitCode = await MiniprogramCli(
        stdoutSink: stdoutBuffer,
        stderrSink: stderrBuffer,
      ).run(const <String>['cloud']);

      expect(exitCode, 64);
      expect(stdoutBuffer.toString(), isEmpty);
      expect(
        stderrBuffer.toString(),
        'provider delivery commands were removed. Build portable artifacts '
        'with `miniprogram artifact build`, verify them, and host the '
        'artifacts directory on any static file host.\n',
      );
    });
  });
}
