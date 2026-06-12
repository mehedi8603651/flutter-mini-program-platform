import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

part 'publisher_backend_starter_test/helpers.dart';
part 'publisher_backend_starter_test/local_runtime_tests.dart';
part 'publisher_backend_starter_test/scaffold_tests.dart';

late Directory tempDir;
late Directory miniProgramRoot;
int? runningPort;

void main() {
  group('PublisherBackendStarter', () {
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_publisher_backend_',
      );
      miniProgramRoot = Directory(p.join(tempDir.path, 'coupon_app'));
      await miniProgramRoot.create(recursive: true);
      await File(p.join(miniProgramRoot.path, 'manifest.json')).writeAsString(
        jsonEncode(<String, Object?>{
          'id': 'coupon_app',
          'version': '1.0.0',
          'entry': 'coupon_app_home',
        }),
      );
    });

    tearDown(() async {
      if (runningPort != null) {
        try {
          await const PublisherBackendStarter().stop(
            miniProgramRootPath: miniProgramRoot.path,
          );
        } catch (_) {
          // Best-effort cleanup for failed process tests.
        }
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    _registerScaffoldTests();
    _registerLocalRuntimeTests();
  });
}
