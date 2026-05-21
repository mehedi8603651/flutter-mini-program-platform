import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('PublisherBackendStarter', () {
    late Directory tempDir;
    late Directory miniProgramRoot;
    int? runningPort;

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

    test('scaffolds mock backend files and respects force', () async {
      final starter = const PublisherBackendStarter();
      final result = await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
        ),
      );

      expect(result.template, 'mock');
      expect(
        await File(
          p.join(miniProgramRoot.path, 'backend', 'mock', 'bin', 'server.dart'),
        ).exists(),
        isTrue,
      );
      expect(
        await File(
          p.join(
            miniProgramRoot.path,
            'backend',
            'mock',
            'data',
            'home_bootstrap.json',
          ),
        ).exists(),
        isTrue,
      );

      final readme = File(
        p.join(miniProgramRoot.path, 'backend', 'mock', 'README.md'),
      );
      await readme.writeAsString('custom');
      expect(
        () => starter.scaffold(
          PublisherBackendScaffoldRequest(
            miniProgramRootPath: miniProgramRoot.path,
          ),
        ),
        throwsA(isA<PublisherBackendException>()),
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          force: true,
        ),
      );
      expect(await readme.readAsString(), contains('mock publisher backend'));
    });

    test('runs, serves mock routes, reports status, and stops', () async {
      final starter = const PublisherBackendStarter();
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
        ),
      );
      runningPort = await _freePort();

      final runResult = await starter.run(
        miniProgramRootPath: miniProgramRoot.path,
        port: runningPort!,
      );
      expect(runResult.alreadyRunning, isFalse);
      expect(runResult.state.port, runningPort);

      final health = await http.get(
        Uri.parse('http://127.0.0.1:$runningPort/health'),
      );
      expect(health.statusCode, 200);
      final home = await http.get(
        Uri.parse('http://127.0.0.1:$runningPort/home/bootstrap'),
      );
      expect(home.statusCode, 200);
      expect(home.body, contains('Coupon App backend starter'));
      final coupons = await http.get(
        Uri.parse('http://127.0.0.1:$runningPort/coupons/list'),
      );
      expect(coupons.statusCode, 200);
      expect(coupons.body, contains('imageUrl'));
      final options = await http.Request(
        'OPTIONS',
        Uri.parse('http://127.0.0.1:$runningPort/coupons/list'),
      ).send();
      expect(options.statusCode, HttpStatus.noContent);
      expect(
        options.headers['access-control-allow-headers'],
        contains('x-mini-program-app-id'),
      );
      expect(
        options.headers['access-control-allow-headers'],
        contains('x-mini-program-host-app'),
      );

      final status = await starter.status(
        miniProgramRootPath: miniProgramRoot.path,
      );
      expect(status.hasState, isTrue);
      expect(status.healthy, isTrue);

      final stop = await starter.stop(
        miniProgramRootPath: miniProgramRoot.path,
      );
      runningPort = null;
      expect(stop.stopped, isTrue);
    });
  });
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
