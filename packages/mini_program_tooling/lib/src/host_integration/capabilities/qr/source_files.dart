import 'dart:io';

import 'package:path/path.dart' as p;

import '../models.dart';

Future<String> readQrKotlinPackage(File mainActivityFile) async {
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

Future<String?> readQrFileIfExists(File file) async =>
    await file.exists() ? file.readAsString() : null;

void validateQrOwnedFile({
  required File file,
  required String? source,
  required String requiredMarker,
}) {
  if (source != null && !source.contains(requiredMarker)) {
    throw MiniProgramHostCapabilityException(
      'Refusing to overwrite the existing host-owned file ${file.path}. '
      'Adapt that provider manually or reconcile the file before retrying.',
    );
  }
}

Future<List<File>> findQrMainActivities(Directory kotlinRoot) {
  return kotlinRoot
      .list(recursive: true, followLinks: false)
      .where(
        (entity) =>
            entity is File && p.basename(entity.path) == 'MainActivity.kt',
      )
      .cast<File>()
      .toList();
}

bool isAndroidQrInstalled({
  required String hostSetupSource,
  required String runtimeSetupSource,
  required String manifestSource,
  required String mainActivitySource,
  required String gradleSource,
  required String? dartProviderSource,
  required String? nativeChannelSource,
  required String? scannerActivitySource,
}) {
  return (dartProviderSource?.contains('class AppAndroidQrScannerProvider') ??
          false) &&
      hostSetupSource.contains('AppAndroidQrScannerProvider') &&
      runtimeSetupSource.contains('CapabilityIds.qrScanner') &&
      manifestSource.contains('.MiniProgramQrScannerActivity') &&
      mainActivitySource.contains('MiniProgramQrScannerChannel.register') &&
      gradleSource.contains('mini-program-qr-capability') &&
      (nativeChannelSource?.contains('class MiniProgramQrScannerChannel') ??
          false) &&
      (scannerActivitySource?.contains('class MiniProgramQrScannerActivity') ??
          false);
}
