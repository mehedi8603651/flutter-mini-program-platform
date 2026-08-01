import 'dart:io';

import 'package:path/path.dart' as p;

import '../models.dart';

Future<String> readCameraKotlinPackage(File mainActivityFile) async {
  final source = await mainActivityFile.readAsString();
  final match = RegExp(
    r'^\s*package\s+([A-Za-z_][A-Za-z0-9_.]*)\s*$',
    multiLine: true,
  ).firstMatch(source);
  final packageName = match?.group(1)?.trim() ?? '';
  if (packageName.isEmpty) {
    throw MiniProgramHostCapabilityException(
      'Could not read the Kotlin package from ${mainActivityFile.path}.',
    );
  }
  return packageName;
}

Future<String?> readCameraFileIfExists(File file) async =>
    await file.exists() ? file.readAsString() : null;

void validateCameraOwnedFile({
  required File file,
  required String? source,
  required String requiredMarker,
}) {
  if (source != null && !source.contains(requiredMarker)) {
    throw MiniProgramHostCapabilityException(
      'Refusing to overwrite the existing host-owned file ${file.path}. '
      'Move or reconcile that file, then run the capability installer again.',
    );
  }
}

Future<List<File>> findCameraMainActivities(Directory kotlinRoot) {
  return kotlinRoot
      .list(recursive: true, followLinks: false)
      .where(
        (entity) =>
            entity is File && p.basename(entity.path) == 'MainActivity.kt',
      )
      .cast<File>()
      .toList();
}

bool isAndroidCameraInstalled({
  required String hostSetupSource,
  required String manifestSource,
  required String mainActivitySource,
  required String? dartProviderSource,
  required String? nativeChannelSource,
  required String? pathsSource,
}) {
  return (dartProviderSource?.contains('class AppAndroidCameraProvider') ??
          false) &&
      hostSetupSource.contains('AppAndroidCameraProvider') &&
      hostSetupSource.contains('cameraProvider:') &&
      manifestSource.contains('.mini_program_camera_files') &&
      (pathsSource?.contains('mini_program_camera') ?? false) &&
      mainActivitySource.contains('FlutterFragmentActivity') &&
      mainActivitySource.contains('MiniProgramCameraChannel.register') &&
      (nativeChannelSource?.contains('class MiniProgramCameraChannel') ??
          false);
}

const String androidCameraPathsSource =
    '''<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <cache-path name="mini_program_camera" path="mini_program_camera/" />
</paths>
''';
