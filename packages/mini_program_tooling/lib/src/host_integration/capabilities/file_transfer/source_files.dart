import 'dart:io';

import 'package:path/path.dart' as p;

import '../models.dart';

Future<String> readFileKotlinPackage(File mainActivityFile) async {
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

Future<String?> readFileCapabilityFileIfExists(File file) async =>
    await file.exists() ? file.readAsString() : null;

void validateFileCapabilityOwnedFile({
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

bool isAndroidFileCapabilityInstalled({
  required String hostSetupSource,
  required String mainActivitySource,
  required String? dartProviderSource,
  required String? nativeChannelSource,
}) {
  final hasProvider =
      dartProviderSource?.contains('class AppAndroidFileTransferProvider') ??
      false;
  final hasHostProvider =
      hostSetupSource.contains('AppAndroidFileTransferProvider') &&
      hostSetupSource.contains('fileTransferProvider:');
  final hasNativeChannel =
      mainActivitySource.contains('mini_program/files') ||
      (mainActivitySource.contains('MiniProgramFileTransferChannel.register') &&
          (nativeChannelSource?.contains(
                'class MiniProgramFileTransferChannel',
              ) ??
              false));
  return hasProvider && hasHostProvider && hasNativeChannel;
}

Future<List<File>> findFileCapabilityMainActivities(Directory kotlinRoot) {
  return kotlinRoot
      .list(recursive: true, followLinks: false)
      .where(
        (entity) =>
            entity is File && p.basename(entity.path) == 'MainActivity.kt',
      )
      .cast<File>()
      .toList();
}
