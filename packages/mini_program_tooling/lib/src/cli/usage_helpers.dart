part of '../miniprogram_cli.dart';

extension _MiniprogramCliUsageHelpers on MiniprogramCli {
  String _rootUsage() => '''
Usage: miniprogram <command> [arguments]

Commands:
  create <mini-program-id> [--screen-format mp] [--with-backend mock]
  capabilities [--json]
  doctor [--json]
  env init|list|status
  env configure <env-name> --provider aws|firebase [provider options]
  env use <local|env-name>
  build [mini-program-id]
  preview -d <chrome|edge|ios|linux|macos|windows|emulator-5554|android-device-id|android-wifi-device-id> [mini-program-id]
  validate [mini-program-id]
  publish [mini-program-id] [--target local|cloud|static|firebase-hosting] [--env <env-name>] [--output <folder>] [--clean]
  access-key create|list|revoke|rotate <mini-program-id> [--env <env-name>]
  cloud deploy|status|outputs|logs|destroy|doctor|rollback [options]
  cloud app list|info|disable|delete [options]
  cloud outputs [--format text|dart-define]
  workflow status [--workspace <path>] [--env <env-name>] [--remote] [--json]
  partner package <mini-program-id> (--access-key <key>|--public) [--env <env-name>] [--backend-base-url <url>]
  host run -d <device> [--env <env-name>]
  host endpoint add <mini-program-id> --title <title> --api-base-url <url> (--access-key <key>|--public) [--backend-base-url <url>|--backend-local-mock]
  host endpoint import <partner-package.json>
  embed init [--project-root <path>]
  embed cloud configure [--env <env-name>]
  backend init [--root <path>]
  backend start --port 8080
  backend stop
  backend status [--json]
  backend reset-local --yes
  publisher-api contract init|validate|smoke|handoff [options]
  publisher-backend scaffold --template mock
  publisher-backend contract init|validate|smoke|handoff [options]
  publisher-backend run --port 9090
  publisher-backend status [--json]
  publisher-backend stop
  publisher-backend urls

Use `miniprogram <command> --help`, `miniprogram <group> --help`, or
`miniprogram <group> <command> --help` for command-specific options.
''';

  String _workflowUsage() => '''
Usage: miniprogram workflow <command> [arguments]

Commands:
  status [--workspace <path>] [--env <env-name>] [--remote] [--json]
''';

  String _publisherBackendUsage({String commandName = 'publisher-backend'}) => '''
Usage: miniprogram $commandName <command> [arguments]

Commands:
  scaffold [--template mock] [--mini-program-root <path>] [--force]
  run [--mini-program-root <path>] [--port 9090]
  status [--mini-program-root <path>] [--json]
  stop [--mini-program-root <path>]
  urls [--port 9090]
  contract init --backend-base-url <url> [--mini-program-root <path>] [--public]
  contract validate [--mini-program-root <path>] [--contract <file>] [--json]
  contract smoke [--mini-program-root <path>] [--contract <file>] [--access-key <key>] [--auth-token <token>] [--json]
  contract handoff --delivery-url <url> [--mini-program-root <path>] [--contract <file>] [--access-key <key>|--public] [--json]
''';

  String _publisherBackendContractUsage() => '''
Usage: miniprogram publisher-backend contract <command> [arguments]

Commands:
  init --backend-base-url <url> [--mini-program-root <path>] [--public]
  validate [--mini-program-root <path>] [--contract <file>] [--json]
  smoke [--mini-program-root <path>] [--contract <file>] [--access-key <key>] [--auth-token <token>] [--json]
  handoff --delivery-url <url> [--mini-program-root <path>] [--contract <file>] [--access-key <key>|--public] [--json]
''';

  String _partnerUsage() => '''
Usage: miniprogram partner <command> [arguments]

Commands:
  package <mini-program-id> (--access-key <key>|--public) [--api-base-url <url>|--env <env-name>]
''';

  String _accessKeyUsage() => '''
Usage: miniprogram access-key <command> [arguments]

Commands:
  create <mini-program-id> --key-id <id> [--env <env-name>]
  list <mini-program-id> [--env <env-name>] [--json]
  revoke <mini-program-id> --key-id <id> [--env <env-name>]
  rotate <mini-program-id> --key-id <id> [--new-key-id <id>] [--env <env-name>]
''';

  String _embedUsage() => '''
Usage: miniprogram embed <command> [arguments]

Commands:
  init [--project-root <path>] [--force]
  cloud configure [--env <env-name>]
''';

  String _embedCloudUsage() => '''
Usage: miniprogram embed cloud <command> [arguments]

Commands:
  configure [--env <env-name>]
''';

  String _envUsage() => '''
Usage: miniprogram env <command> [arguments]

Commands:
  init
  configure <env-name> --provider aws --bucket <bucket> --region <region>
  list
  use <local|env-name>
  status [--json]
''';

  String _cloudUsage() => '''
Usage: miniprogram cloud <command> [arguments]

Commands:
  deploy [--env <env-name>]
  status [--env <env-name>] [--json]
  outputs [--env <env-name>] [--format text|dart-define]
  logs [--env <env-name>]
  destroy [--env <env-name>]
  doctor [--env <env-name>]
  rollback <version> [mini-program-id] [--env <env-name>]
  app list [--env <env-name>]
  app info <mini-program-id> [--env <env-name>]
  app disable <mini-program-id> [--yes] [--env <env-name>]
  app delete <mini-program-id> [--yes] [--env <env-name>]
''';

  String _cloudAppUsage() => '''
Usage: miniprogram cloud app <command> [arguments]

Commands:
  list [--env <env-name>]
  info <mini-program-id> [--env <env-name>]
  disable <mini-program-id> [--yes] [--env <env-name>]
  delete <mini-program-id> [--yes] [--env <env-name>]
''';

  String _hostUsage() => '''
Usage: miniprogram host <command> [arguments]

Commands:
  run -d <device> [--env <env-name>]
  endpoint add <mini-program-id> --api-base-url <url> (--access-key <key>|--public)
  endpoint import <partner-package.json>
''';

  String _hostEndpointUsage() => '''
Usage: miniprogram host endpoint <command> [arguments]

Commands:
  add <mini-program-id> --api-base-url <url> (--access-key <key>|--public)
  import <partner-package.json>
''';

  String _backendUsage() => '''
Usage: miniprogram backend <command> [arguments]

Commands:
  init [--root <path>]
  start --port 8080
  stop
  status [--json]
  reset-local --yes
''';
}
