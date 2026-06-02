part of '../miniprogram_cli.dart';

const List<String> _supportedPublishTargets = <String>[
  'local',
  'cloud',
  'static',
  'firebase-hosting',
];

const String _miniProgramToolingVersion = '0.3.50';

const List<String> _capabilityIds = <String>[
  'publish.firebase_hosting',
  'publisher_backend.aws.status',
  'publisher_backend.aws.outputs',
  'publisher_backend.aws.smoke',
  'publisher_backend.aws.smoke.write',
  'publisher_backend.aws.paged_routes',
  'publisher_backend.aws.dynamodb.seed',
  'publisher_backend.aws.dynamodb.data.status',
  'publisher_backend.aws.dynamodb.data.export',
  'publisher_backend.aws.dynamodb.data.import',
  'publisher_backend.aws.dynamodb.data.redemptions',
  'publisher_backend.aws.destroy.data_loss_guard',
  'publisher_backend.firebase_functions.scaffold',
  'publisher_backend.firebase.deploy',
  'publisher_backend.firebase.status',
  'publisher_backend.firebase.outputs',
  'publisher_backend.firebase.host_command',
  'publisher_backend.firebase.handoff',
  'publisher_backend.firebase.starter_ui',
  'publisher_backend.firebase.paged_routes',
  'publisher_backend.firebase.access_keys',
  'publisher_backend.firebase.auth.email',
  'publisher_backend.firebase.auth.status',
  'publisher_backend.firebase.host.auth_diagnostics',
  'publisher_backend.firebase.smoke',
  'publisher_backend.firebase.smoke.write',
  'publisher_backend.firebase.smoke.auth',
  'publisher_backend.firebase.firestore.seed',
  'publisher_backend.firebase.firestore.data.status',
  'publisher_backend.firebase.firestore.data.export',
  'publisher_backend.firebase.firestore.data.import',
  'publisher_backend.firebase.firestore.data.redemptions',
  'publisher_backend.firebase.destroy.data_loss_guard',
];
