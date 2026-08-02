import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:mini_program_tooling/src/host_integration/capabilities/android/generated_source.dart';
import 'package:mini_program_tooling/src/host_integration/capabilities/android/gradle_editor.dart';
import 'package:mini_program_tooling/src/host_integration/capabilities/android/main_activity_editor.dart';
import 'package:mini_program_tooling/src/host_integration/capabilities/android/native_setup.dart';
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
      expect(_occurrences(output, androidNativeSetupRegistration), 1);
      for (final registration in androidCapabilityRegistrations) {
        expect(_occurrences(output, registration), 0, reason: registration);
      }
    });

    test('generated setup output is stable across capability order', () {
      final orders = <List<String>>[
        androidCapabilityRegistrations,
        androidCapabilityRegistrations.reversed.toList(),
      ];
      final outputs = <String>[];
      for (final order in orders) {
        String? setup;
        for (final registration in order) {
          setup = buildAndroidNativeSetupSource(
            packageName: 'com.example.host',
            mainActivitySource: _mainActivityFixture,
            currentSource: setup,
            registration: registration,
          );
        }
        outputs.add(setup!);
      }
      expect(outputs.last, outputs.first);
      for (final registration in androidCapabilityRegistrations) {
        expect(_occurrences(outputs.first, registration), 1);
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
      expect(hasManagedAndroidNativeSetupRegistration(migrated), isTrue);
      expect(migrated, isNot(contains('MiniProgramLocationChannel.register')));
      expect(migrated, isNot(contains('MiniProgramQrScannerChannel.register')));
    });

    test('Gradle output is stable and keeps host dependencies', () {
      final qr = buildAndroidCapabilityGradleEdit(
        _gradleFixture,
        generatedSource: null,
        capability: androidQrDependencyCapability,
        kotlinDsl: true,
      );
      final qrThenMedia = buildAndroidCapabilityGradleEdit(
        qr.appGradleSource,
        generatedSource: qr.generatedGradleSource,
        capability: androidMediaPlaybackDependencyCapability,
        kotlinDsl: true,
      );
      final media = buildAndroidCapabilityGradleEdit(
        _gradleFixture,
        generatedSource: null,
        capability: androidMediaPlaybackDependencyCapability,
        kotlinDsl: true,
      );
      final mediaThenQr = buildAndroidCapabilityGradleEdit(
        media.appGradleSource,
        generatedSource: media.generatedGradleSource,
        capability: androidQrDependencyCapability,
        kotlinDsl: true,
      );

      expect(mediaThenQr.appGradleSource, qrThenMedia.appGradleSource);
      expect(
        mediaThenQr.generatedGradleSource,
        qrThenMedia.generatedGradleSource,
      );
      expect(
        qrThenMedia.appGradleSource,
        contains('implementation("host:owned:1.0")'),
      );
      expect(
        _occurrences(
          qrThenMedia.appGradleSource,
          androidCapabilityDependenciesStart,
        ),
        1,
      );
      expect(
        _occurrences(qrThenMedia.generatedGradleSource, 'camera-camera2:1.4.2'),
        1,
      );
      expect(
        _occurrences(
          qrThenMedia.generatedGradleSource,
          'media3-exoplayer:1.5.1',
        ),
        1,
      );
      expect(
        hasManagedAndroidCapabilityDependencies(
          qrThenMedia.generatedGradleSource,
          androidQrDependencyCapability,
        ),
        isTrue,
      );
      expect(
        hasManagedAndroidCapabilityDependencies(
          qrThenMedia.generatedGradleSource,
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

      final migrated = buildAndroidCapabilityGradleEdit(
        legacy,
        generatedSource: null,
        capability: androidQrDependencyCapability,
        kotlinDsl: true,
      );

      expect(
        migrated.appGradleSource,
        isNot(contains('mini-program-qr-capability')),
      );
      expect(
        migrated.appGradleSource,
        isNot(contains('mini-program-media-playback-capability')),
      );
      expect(
        _occurrences(
          migrated.appGradleSource,
          androidCapabilityDependenciesStart,
        ),
        1,
      );
      expect(
        _occurrences(migrated.generatedGradleSource, 'camera-camera2:1.4.2'),
        1,
      );
      expect(
        _occurrences(migrated.generatedGradleSource, 'media3-exoplayer:1.5.1'),
        1,
      );
      expect(
        hasManagedAndroidCapabilityDependencies(
          migrated.generatedGradleSource,
          androidQrDependencyCapability,
        ),
        isTrue,
      );
      expect(
        hasManagedAndroidCapabilityDependencies(
          migrated.generatedGradleSource,
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

    test(
      'moves a recognized legacy native source in one transaction',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'mini_program_native_source_migration_',
        );
        addTearDown(() => root.delete(recursive: true));
        final legacy = File(p.join(root.path, 'MiniProgramLocationChannel.kt'));
        final generated = File(
          p.join(
            root.path,
            'mini_program',
            'generated',
            'location',
            'MiniProgramLocationChannel.kt',
          ),
        );
        const source =
            'package com.example.host\n\n'
            'internal class MiniProgramLocationChannel\n';
        await legacy.writeAsString(source);

        final migration = await resolveAndroidGeneratedSource(
          generatedFile: generated,
          legacyFile: legacy,
          requiredMarker: 'class MiniProgramLocationChannel',
          buildSource: () => throw StateError('legacy source should be reused'),
        );
        await writeCapabilityFiles(
          projectRootPath: root.path,
          capability: 'location',
          platform: 'android',
          writes: migration.writes,
          deletes: migration.deletes,
        );

        expect(await legacy.exists(), isFalse);
        expect(await generated.readAsString(), source);
      },
    );

    test('refuses an unrecognized legacy native source', () async {
      final root = await Directory.systemTemp.createTemp(
        'mini_program_native_source_conflict_',
      );
      addTearDown(() => root.delete(recursive: true));
      final legacy = File(p.join(root.path, 'MiniProgramLocationChannel.kt'));
      final generated = File(
        p.join(
          root.path,
          'mini_program',
          'generated',
          'location',
          'MiniProgramLocationChannel.kt',
        ),
      );
      await legacy.writeAsString(
        'package com.example.host\n// custom host code\n',
      );

      await expectLater(
        resolveAndroidGeneratedSource(
          generatedFile: generated,
          legacyFile: legacy,
          requiredMarker: 'class MiniProgramLocationChannel',
          buildSource: () => 'generated',
        ),
        throwsA(isA<MiniProgramHostCapabilityException>()),
      );
      expect(await legacy.exists(), isTrue);
      expect(await generated.exists(), isFalse);
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
