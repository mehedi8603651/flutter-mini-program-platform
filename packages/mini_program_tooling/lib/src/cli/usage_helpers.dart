part of '../miniprogram_cli.dart';

extension _MiniprogramCliUsageHelpers on MiniprogramCli {
  String _rootUsage() => '''
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
''';

  String _artifactUsage() => '''
Usage: miniprogram artifact <command> [arguments]

Commands:
  build [mini-program-id]   Create an immutable portable artifact bundle.
  verify [mini-program-id]  Verify structure, identity, and SHA-256 checksums.
''';

  String _workflowUsage() => '''
Usage: miniprogram workflow <command> [arguments]

Commands:
  status [--workspace <path>] [--env <env-name>] [--remote] [--json]
''';

  String _publisherBackendUsage({String commandName = 'publisher-backend'}) =>
      '''
Usage: miniprogram $commandName <command> [arguments]

Commands:
  scaffold [--template mock] [--mini-program-root <path>] [--force]
  run [--mini-program-root <path>] [--port 9090]
  status [--mini-program-root <path>] [--json]
  stop [--mini-program-root <path>]
  urls [--port 9090]
  contract init --publisher-api-url <url> [--permission-reason <text>] [--mini-program-root <path>]
  contract validate [--mini-program-root <path>] [--contract <file>] [--json]
  contract smoke [--mini-program-root <path>] [--contract <file>] [--auth-token <token>] [--json]
''';

  String _publisherBackendContractUsage({
    String commandName = 'publisher-backend',
  }) =>
      '''
Usage: miniprogram $commandName contract <command> [arguments]

Commands:
  init --publisher-api-url <url> [--permission-reason <text>] [--mini-program-root <path>]
  validate [--mini-program-root <path>] [--contract <file>] [--json]
  smoke [--mini-program-root <path>] [--contract <file>] [--auth-token <token>] [--json]
''';

  String _partnerUsage() => '''
Usage: miniprogram partner <command> [arguments]

Commands:
  package <mini-program-id> --artifact-base-url <url>
''';

  String _embedUsage() => '''
Usage: miniprogram embed <command> [arguments]

Commands:
  init [--project-root <path>] [--force]
''';

  String _envUsage() => '''
Usage: miniprogram env <command> [arguments]

Commands:
  init
  list
  use local
  status [--json]
''';

  String _hostUsage() => '''
Usage: miniprogram host <command> [arguments]

Commands:
  run -d <device>
  endpoint add <mini-program-id> --artifact-base-url <url>
  endpoint import <partner-package.json>
''';

  String _hostEndpointUsage() => '''
Usage: miniprogram host endpoint <command> [arguments]

Commands:
  add <mini-program-id> --artifact-base-url <url>
  import <partner-package.json>
''';

  String _backendUsage({String commandName = 'artifact-host'}) =>
      '''
Usage: miniprogram $commandName <command> [arguments]

Static artifact host for local mini-program frontend delivery.
${commandName == 'backend' ? '\nLegacy alias: use `miniprogram artifact-host ...` in new scripts.\n' : ''}

Commands:
  init [--root <path>]
  start --port 8080
  stop
  status [--json]
  reset-local --yes
''';
}
