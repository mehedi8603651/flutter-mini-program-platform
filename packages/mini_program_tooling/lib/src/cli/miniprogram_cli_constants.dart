part of '../miniprogram_cli.dart';

const List<String> _supportedPublishTargets = <String>['local', 'static'];

const String _miniProgramToolingVersion = '0.6.14';

const List<String> _capabilityIds = <String>[
  'publish.static',
  'artifact.build',
  'artifact.verify',
  'publisher_api.mock.scaffold',
  'publisher_api.mock.run',
  'publisher_backend.contract.init',
  'publisher_backend.contract.validate',
  'publisher_backend.contract.smoke',
  'publisher_api.contract.init',
  'publisher_api.contract.validate',
  'publisher_api.contract.smoke',
];
