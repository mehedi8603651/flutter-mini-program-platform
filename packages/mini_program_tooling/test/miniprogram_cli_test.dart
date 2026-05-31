import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

part 'miniprogram_cli_test/core_and_preview_tests.dart';
part 'miniprogram_cli_test/env_publish_tests.dart';
part 'miniprogram_cli_test/publisher_backend_aws_smoke_tests.dart';
part 'miniprogram_cli_test/publisher_backend_firebase_tests.dart';
part 'miniprogram_cli_test/publisher_backend_aws_data_tests.dart';
part 'miniprogram_cli_test/cloud_host_partner_tests.dart';
part 'miniprogram_cli_test/workflow_validation_embed_backend_tests.dart';
part 'miniprogram_cli_test/helpers.dart';

late Directory tempDir;
late Directory repoRoot;
late LocalCliStateStore stateStore;

void main() {
  group('MiniprogramCli', () {
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_cli_',
      );
      repoRoot = Directory(p.join(tempDir.path, 'repo'));
      await Directory(
        p.join(repoRoot.path, 'backend', 'api'),
      ).create(recursive: true);
      await Directory(
        p.join(repoRoot.path, 'backend', 'local_backend_service', 'bin'),
      ).create(recursive: true);
      await Directory(
        p.join(repoRoot.path, 'mini_programs'),
      ).create(recursive: true);
      await File(
        p.join(
          repoRoot.path,
          'backend',
          'local_backend_service',
          'bin',
          'server.dart',
        ),
      ).writeAsString('void main() {}');
      await Directory(
        p.join(repoRoot.path, 'packages', 'mini_program_tooling'),
      ).create(recursive: true);
      await File(
        p.join(
          repoRoot.path,
          'packages',
          'mini_program_tooling',
          'pubspec.yaml',
        ),
      ).writeAsString('name: mini_program_tooling');
      stateStore = LocalCliStateStore(
        homeDirectoryPath: p.join(tempDir.path, 'fake_home'),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    _registerCoreAndPreviewTests();
    _registerEnvPublishTests();
    _registerPublisherBackendAwsSmokeTests();
    _registerPublisherBackendFirebaseTests();
    _registerPublisherBackendAwsDataTests();
    _registerCloudHostPartnerTests();
    _registerWorkflowValidationEmbedBackendTests();
  });
}
