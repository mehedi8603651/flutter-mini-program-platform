import 'dart:io';

import 'package:path/path.dart' as p;

import '../location/installer.dart' show androidPlatform;
import '../models.dart';
import 'dart_provider_template.dart';
import 'source_editors.dart';

const String audioCapability = 'audio';
const String videoCapability = 'video';

Future<MiniProgramHostCapabilityInitResult>
initializeMiniProgramHostMediaPlaybackCapability(
  MiniProgramHostCapabilityInitRequest request,
) async {
  final capability = request.capability.trim().toLowerCase();
  final platform = request.platform.trim().toLowerCase();
  if ((capability != audioCapability && capability != videoCapability) ||
      platform != androidPlatform) {
    throw MiniProgramHostCapabilityException(
      'Host capability "$capability" currently supports only '
      '`audio|video --platform android`.',
    );
  }
  final rootPath = p.normalize(p.absolute(request.projectRootPath));
  final pubspec = File(p.join(rootPath, 'pubspec.yaml'));
  final hostSetup = File(
    p.join(rootPath, 'lib', 'mini_program', 'mini_program_host_setup.dart'),
  );
  final runtimeSetup = File(
    p.join(rootPath, 'lib', 'mini_program', 'mini_program_runtime_setup.dart'),
  );
  final android = Directory(p.join(rootPath, 'android'));
  if (!await pubspec.exists() ||
      !await hostSetup.exists() ||
      !await runtimeSetup.exists() ||
      !await android.exists()) {
    throw const MiniProgramHostCapabilityException(
      'Host embedding and Android files must exist before installing media playback.',
    );
  }
  final provider = File(
    p.join(
      rootPath,
      'lib',
      'mini_program',
      'app_android_media_playback_provider.dart',
    ),
  );
  final existingProvider = await provider.exists()
      ? await provider.readAsString()
      : null;
  if (existingProvider != null &&
      !existingProvider.contains('class AppAndroidMediaPlaybackProvider')) {
    throw MiniProgramHostCapabilityException(
      'Refusing to overwrite the existing host-owned file ${provider.path}.',
    );
  }

  final pubspecSource = await pubspec.readAsString();
  final hostSource = await hostSetup.readAsString();
  final runtimeSource = await runtimeSetup.readAsString();
  final patchedPubspec = patchMediaPlaybackPubspec(pubspecSource);
  final patchedHost = patchMediaPlaybackHostSetup(hostSource);
  final patchedRuntime = patchMediaPlaybackRuntimeSetup(runtimeSource);
  final writes = <String, String>{
    if (existingProvider == null)
      provider.path: androidMediaPlaybackProviderSource,
    if (patchedPubspec != pubspecSource) pubspec.path: patchedPubspec,
    if (patchedHost != hostSource) hostSetup.path: patchedHost,
    if (patchedRuntime != runtimeSource) runtimeSetup.path: patchedRuntime,
  };
  final created = <String>[];
  final updated = <String>[];
  for (final entry in writes.entries) {
    final file = File(entry.key);
    final existed = await file.exists();
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
    (existed ? updated : created).add(file.path);
  }
  created.sort();
  updated.sort();
  return MiniProgramHostCapabilityInitResult(
    projectRootPath: rootPath,
    capability: capability,
    platform: platform,
    createdPaths: List<String>.unmodifiable(created),
    updatedPaths: List<String>.unmodifiable(updated),
  );
}
