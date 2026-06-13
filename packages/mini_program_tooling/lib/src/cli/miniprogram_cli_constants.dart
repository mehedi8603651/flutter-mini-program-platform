part of '../miniprogram_cli.dart';

const List<String> _supportedPublishTargets = <String>[
  'local',
  'cloud',
  'static',
  'firebase-hosting',
];

const String _miniProgramToolingVersion = '0.5.2';

const List<String> _capabilityIds = <String>[
  'publish.firebase_hosting',
  'publisher_api.mock.scaffold',
  'publisher_api.mock.run',
  'publisher_backend.contract.init',
  'publisher_backend.contract.validate',
  'publisher_backend.contract.smoke',
  'publisher_backend.contract.handoff',
  'publisher_api.contract.init',
  'publisher_api.contract.validate',
  'publisher_api.contract.smoke',
  'publisher_api.contract.handoff',
];
