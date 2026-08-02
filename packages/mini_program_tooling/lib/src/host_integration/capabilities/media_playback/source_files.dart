import 'dart:io';

import 'package:path/path.dart' as p;

import '../android/gradle_editor.dart';
import '../models.dart';
import 'dart_provider_template.dart';

Future<List<File>> findMediaPlaybackMainActivities(Directory kotlinRoot) {
  return kotlinRoot
      .list(recursive: true, followLinks: false)
      .where(
        (entity) =>
            entity is File && p.basename(entity.path) == 'MainActivity.kt',
      )
      .cast<File>()
      .toList();
}

Future<String> readMediaPlaybackKotlinPackage(File mainActivityFile) async {
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

Future<String?> readMediaPlaybackFileIfExists(File file) async =>
    await file.exists() ? file.readAsString() : null;

void validateMediaPlaybackOwnedFile({
  required File file,
  required String? source,
  required String requiredMarker,
}) {
  if (source != null && !source.contains(requiredMarker)) {
    throw MiniProgramHostCapabilityException(
      'Refusing to overwrite the existing host-owned file ${file.path}. '
      'Adapt that integration manually or reconcile the file before retrying.',
    );
  }
}

bool isLegacyGeneratedMediaPlaybackProvider(String source) =>
    _normalized(source) ==
        _normalized(legacyAndroidMediaPlaybackProviderSource) ||
    (source.contains("package:video_player/video_player.dart") &&
        source.contains('class AppAndroidMediaPlaybackProvider') &&
        source.contains('class _AppMediaPlaybackSession') &&
        source.contains('class _AppInlineVideoView') &&
        source.contains('VideoPlayerController.networkUrl') &&
        source.contains('candidateUris'));

bool isCurrentGeneratedMediaPlaybackProvider(String source) =>
    _normalized(source) == _normalized(androidMediaPlaybackProviderSource);

bool isAndroidMediaPlaybackInstalled({
  required String hostSetupSource,
  required String runtimeSetupSource,
  required String mainActivitySource,
  required String gradleSource,
  required String? dartProviderSource,
  required String? nativePluginSource,
}) {
  return (dartProviderSource?.contains(
            'class AppAndroidMediaPlaybackProvider',
          ) ??
          false) &&
      hostSetupSource.contains('AppAndroidMediaPlaybackProvider') &&
      runtimeSetupSource.contains('CapabilityIds.mediaAudio') &&
      runtimeSetupSource.contains('CapabilityIds.mediaVideo') &&
      mainActivitySource.contains(
        'MiniProgramMediaPlaybackPlugin.register(flutterEngine)',
      ) &&
      hasManagedAndroidCapabilityDependencies(
        gradleSource,
        androidMediaPlaybackDependencyCapability,
      ) &&
      (nativePluginSource?.contains('class MiniProgramMediaPlaybackPlugin') ??
          false);
}

String _normalized(String source) => source.replaceAll('\r\n', '\n').trim();
