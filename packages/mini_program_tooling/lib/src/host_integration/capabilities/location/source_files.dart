import 'dart:io';

import '../models.dart';

Future<String> readLocationKotlinPackage(File mainActivityFile) async {
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

Future<String?> readLocationFileIfExists(File file) async {
  return await file.exists() ? file.readAsString() : null;
}

void validateLocationOwnedFile({
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

bool isAndroidLocationInstalled({
  required String hostSetupSource,
  required String manifestSource,
  required String mainActivitySource,
  required String? dartProviderSource,
  required String? nativeChannelSource,
}) {
  final hasProvider =
      dartProviderSource?.contains('class AppAndroidLocationProvider') ?? false;
  final hasHostProvider =
      hostSetupSource.contains('AppAndroidLocationProvider') &&
      hostSetupSource.contains('locationProvider:');
  final hasPermission = manifestSource.contains(
    'android.permission.ACCESS_COARSE_LOCATION',
  );
  final hasNativeChannel =
      mainActivitySource.contains('mini_program/location') ||
      (mainActivitySource.contains('MiniProgramLocationChannel.register') &&
          (nativeChannelSource?.contains('class MiniProgramLocationChannel') ??
              false));
  return hasProvider && hasHostProvider && hasPermission && hasNativeChannel;
}
