import 'dart:convert';
import 'dart:io';

import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  group('writeMpBuildOutput', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mini_program_ui_build_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes deterministic screen JSON under screens/', () async {
      final outputPath = _join(tempDir.path, 'mp_build');
      final staleFile = File(_join(_join(outputPath, 'screens'), 'old.json'));
      await staleFile.parent.create(recursive: true);
      await staleFile.writeAsString('{}');

      final program = MpProgram(
        screens: <String, MpScreenBuilder>{
          'coupon_home': () => Mp.heading('Coupons'),
          'coupon_details': () => Mp.text('Details'),
        },
      );

      await writeMpBuildOutput(
        program,
        arguments: <String>['--output', outputPath],
      );

      expect(await staleFile.exists(), isFalse);
      final home =
          jsonDecode(
                await File(
                  _join(_join(outputPath, 'screens'), 'coupon_home.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      final details =
          jsonDecode(
                await File(
                  _join(_join(outputPath, 'screens'), 'coupon_details.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;

      expect(home['schemaVersion'], 1);
      expect(home['screenId'], 'coupon_home');
      expect((home['root'] as Map<String, dynamic>)['type'], 'heading');
      expect(details['screenId'], 'coupon_details');
    });
  });
}

String _join(String first, String second) {
  if (first.endsWith(Platform.pathSeparator)) {
    return '$first$second';
  }
  return '$first${Platform.pathSeparator}$second';
}
