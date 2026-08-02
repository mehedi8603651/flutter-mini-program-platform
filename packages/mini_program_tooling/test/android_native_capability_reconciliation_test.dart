import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:mini_program_tooling/src/host_integration/capabilities/android/gradle_editor.dart';
import 'package:mini_program_tooling/src/host_integration/capabilities/android/main_activity_editor.dart';
import 'package:mini_program_tooling/src/host_integration/capabilities/file_transaction.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Android native capability reconciliation', () {
    test('MainActivity output is stable across capability install order', () {
      final orders = <List<String>>[
        androidCapabilityRegistrations,
        androidCapabilityRegistrations.reversed.toList(),
        <String>[
          androidCapabilityRegistrations[4],
          androidCapabilityRegistrations[1],
          androidCapabilityRegistrations[5],
          androidCapabilityRegistrations[0],
          androidCapabilityRegistrations[3],
          androidCapabilityRegistrations[2],
        ],
      ];
      final outputs = <String>[];
      for (final order in orders) {
        var source = _mainActivityFixture;
        for (final registration in order) {
          source = patchAndroidMainActivityRegistration(
            source,
            registration: registration,
            requiresFragmentActivity: registration.contains('CameraChannel'),
          );
        }
        outputs.add(source);
      }

      for (var index = 1; index < outputs.length; index += 1) {
        expect(outputs[index], outputs.first, reason: 'order $index');
      }
      final output = outputs.first;
      expect(output, contains('registerExistingHostChannel(flutterEngine)'));
      expect(output, contains('FlutterFragmentActivity'));
      expect(_occurrences(output, androidCapabilityRegistrationStart), 1);
      expect(_occurrences(output, androidCapabilityRegistrationEnd), 1);
      for (final registration in androidCapabilityRegistrations) {
        expect(_occurrences(output, registration), 1, reason: registration);
      }
    });

    test('migrates direct registrations into the managed block', () {
      final source = _mainActivityFixture.replaceFirst(
        'registerExistingHostChannel(flutterEngine)',
        'registerExistingHostChannel(flutterEngine)\n'
            '        MiniProgramLocationChannel.register(flutterEngine)\n'
            '        MiniProgramQrScannerChannel.register(flutterEngine)',
      );

      final migrated = patchAndroidMainActivityRegistration(
        source,
        registration: 'MiniProgramFileTransferChannel.register(flutterEngine)',
      );

      expect(_occurrences(migrated, androidCapabilityRegistrationStart), 1);
      expect(
        hasManagedAndroidCapabilityRegistration(
          migrated,
          'MiniProgramLocationChannel.register(flutterEngine)',
        ),
        isTrue,
      );
      expect(
        hasManagedAndroidCapabilityRegistration(
          migrated,
          'MiniProgramQrScannerChannel.register(flutterEngine)',
        ),
        isTrue,
      );
    });

    test('Gradle output is stable and keeps host dependencies', () {
      final qrThenMedia = patchAndroidCapabilityDependencies(
        patchAndroidCapabilityDependencies(
          _gradleFixture,
          capability: androidQrDependencyCapability,
          kotlinDsl: true,
        ),
        capability: androidMediaPlaybackDependencyCapability,
        kotlinDsl: true,
      );
      final mediaThenQr = patchAndroidCapabilityDependencies(
        patchAndroidCapabilityDependencies(
          _gradleFixture,
          capability: androidMediaPlaybackDependencyCapability,
          kotlinDsl: true,
        ),
        capability: androidQrDependencyCapability,
        kotlinDsl: true,
      );

      expect(mediaThenQr, qrThenMedia);
      expect(qrThenMedia, contains('implementation("host:owned:1.0")'));
      expect(_occurrences(qrThenMedia, androidCapabilityDependenciesStart), 1);
      expect(_occurrences(qrThenMedia, 'camera-camera2:1.4.2'), 1);
      expect(_occurrences(qrThenMedia, 'media3-exoplayer:1.5.1'), 1);
      expect(
        hasManagedAndroidCapabilityDependencies(
          qrThenMedia,
          androidQrDependencyCapability,
        ),
        isTrue,
      );
      expect(
        hasManagedAndroidCapabilityDependencies(
          qrThenMedia,
          androidMediaPlaybackDependencyCapability,
        ),
        isTrue,
      );
    });

    test('migrates both legacy Gradle marker blocks together', () {
      const legacy =
          '''
$_gradleFixture

// mini-program-qr-capability
dependencies {
    implementation("androidx.camera:camera-camera2:1.4.2")
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
}

// mini-program-media-playback-capability
dependencies {
    implementation("androidx.media3:media3-exoplayer:1.5.1")
    implementation("androidx.media3:media3-exoplayer-hls:1.5.1")
}
''';

      final migrated = patchAndroidCapabilityDependencies(
        legacy,
        capability: androidQrDependencyCapability,
        kotlinDsl: true,
      );

      expect(migrated, isNot(contains('mini-program-qr-capability')));
      expect(
        migrated,
        isNot(contains('mini-program-media-playback-capability')),
      );
      expect(_occurrences(migrated, androidCapabilityDependenciesStart), 1);
      expect(_occurrences(migrated, 'camera-camera2:1.4.2'), 1);
      expect(_occurrences(migrated, 'media3-exoplayer:1.5.1'), 1);
      expect(
        hasManagedAndroidCapabilityDependencies(
          migrated,
          androidQrDependencyCapability,
        ),
        isTrue,
      );
      expect(
        hasManagedAndroidCapabilityDependencies(
          migrated,
          androidMediaPlaybackDependencyCapability,
        ),
        isTrue,
      );
    });

    test('rejects malformed managed blocks before editing', () {
      expect(
        () => patchAndroidMainActivityRegistration(
          '$_mainActivityFixture\n$androidCapabilityRegistrationStart\n',
          registration: androidCapabilityRegistrations.first,
        ),
        throwsA(isA<MiniProgramHostCapabilityException>()),
      );
      expect(
        () => patchAndroidCapabilityDependencies(
          '$_gradleFixture\n$androidCapabilityDependenciesEnd\n',
          capability: androidQrDependencyCapability,
          kotlinDsl: true,
        ),
        throwsA(isA<MiniProgramHostCapabilityException>()),
      );
    });

    test('transaction preflight leaves host files unchanged', () async {
      final root = await Directory.systemTemp.createTemp(
        'mini_program_capability_transaction_',
      );
      addTearDown(() => root.delete(recursive: true));
      final existing = File(p.join(root.path, 'existing.txt'));
      await existing.writeAsString('host-owned');
      final outside = File('${root.path}_outside.txt');
      addTearDown(() async {
        if (await outside.exists()) await outside.delete();
      });

      await expectLater(
        writeCapabilityFiles(
          projectRootPath: root.path,
          capability: 'test',
          platform: 'android',
          writes: <String, String>{
            existing.path: 'generated',
            outside.path: 'outside',
          },
        ),
        throwsA(isA<MiniProgramHostCapabilityException>()),
      );
      expect(await existing.readAsString(), 'host-owned');
      expect(await outside.exists(), isFalse);
    });
  });
}

const String _mainActivityFixture = '''
package com.example.host

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerExistingHostChannel(flutterEngine)
    }

    private fun registerExistingHostChannel(flutterEngine: FlutterEngine) = Unit
}
''';

const String _gradleFixture = '''
plugins {
    id("com.android.application")
}

dependencies {
    implementation("host:owned:1.0")
}
''';

int _occurrences(String source, String value) {
  var count = 0;
  var offset = 0;
  while (true) {
    final index = source.indexOf(value, offset);
    if (index == -1) return count;
    count += 1;
    offset = index + value.length;
  }
}
