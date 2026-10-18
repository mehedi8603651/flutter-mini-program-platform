import 'dart:io';

import 'package:path/path.dart' as p;

import '../models.dart';

Future<String> readGalleryKotlinPackage(File mainActivityFile) async {
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

Future<String?> readGalleryFileIfExists(File file) async =>
    await file.exists() ? file.readAsString() : null;

void validateGalleryOwnedFile({
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

Future<List<File>> findGalleryMainActivities(Directory kotlinRoot) {
  return kotlinRoot
      .list(recursive: true, followLinks: false)
      .where(
        (entity) =>
            entity is File && p.basename(entity.path) == 'MainActivity.kt',
      )
      .cast<File>()
      .toList();
}

bool isAndroidGalleryInstalled({
  required String hostSetupSource,
  required String runtimeSetupSource,
  required String mainActivitySource,
  required String? dartProviderSource,
  required String? nativeChannelSource,
  required String? mediaRegistrySource,
}) {
  return (dartProviderSource?.contains('class AppAndroidGalleryProvider') ??
          false) &&
      hostSetupSource.contains('AppAndroidGalleryProvider') &&
      hostSetupSource.contains('galleryProvider:') &&
      runtimeSetupSource.contains(
        'MiniProgramGalleryProvider? galleryProvider',
      ) &&
      runtimeSetupSource.contains('CapabilityIds.galleryImages') &&
      runtimeSetupSource.contains('galleryProvider: galleryProvider,') &&
      (mainActivitySource.contains('MiniProgramGalleryChannel.register') ||
          mainActivitySource.contains('MiniProgramNativeSetup.register')) &&
      (nativeChannelSource?.contains('class MiniProgramGalleryChannel') ??
          false) &&
      (mediaRegistrySource?.contains('object MiniProgramHostMediaRegistry') ??
          false);
}
