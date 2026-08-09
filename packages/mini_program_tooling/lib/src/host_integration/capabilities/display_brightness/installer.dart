import 'dart:io';

import 'package:path/path.dart' as p;

import '../android/generated_source.dart';
import '../android/integration_editor.dart';
import '../file_transaction.dart';
import '../location/installer.dart' show androidPlatform;
import '../models.dart';
import 'android_channel_template.dart';
import 'dart_provider_template.dart';
import 'source_editors.dart';
import 'source_files.dart';

const String displayBrightnessCapability = 'display-brightness';

Future<MiniProgramHostCapabilityInitResult>
initializeMiniProgramHostDisplayBrightnessCapability(
  MiniProgramHostCapabilityInitRequest request,
) async {
  final capability = request.capability.trim().toLowerCase();
  final platform = request.platform.trim().toLowerCase();
  if (capability != displayBrightnessCapability ||
      platform != androidPlatform) {
    throw MiniProgramHostCapabilityException(
      'Host capability "$capability" currently supports only '
      '`$displayBrightnessCapability --platform android`.',
    );
  }
  final rootPath = p.normalize(p.absolute(request.projectRootPath));
  final pubspec = File(p.join(rootPath, 'pubspec.yaml'));
  if (!await pubspec.exists() ||
      !RegExp(
        r'^\s*flutter\s*:\s*$',
        multiLine: true,
      ).hasMatch(await pubspec.readAsString())) {
    throw MiniProgramHostCapabilityException(
      'Host display brightness installation requires a Flutter application: $rootPath',
    );
  }
  final integrationRoot = p.join(rootPath, 'lib', 'mini_program');
  final hostSetup = File(
    p.join(integrationRoot, 'mini_program_host_setup.dart'),
  );
  final runtimeSetup = File(
    p.join(integrationRoot, 'mini_program_runtime_setup.dart'),
  );
  final kotlinRoot = Directory(
    p.join(rootPath, 'android', 'app', 'src', 'main', 'kotlin'),
  );
  if (!await hostSetup.exists() ||
      !await runtimeSetup.exists() ||
      !await kotlinRoot.exists()) {
    throw const MiniProgramHostCapabilityException(
      'Host embedding and Android files must exist before installing display brightness support.',
    );
  }
  final activities = await findDisplayBrightnessMainActivities(kotlinRoot);
  if (activities.length != 1) {
    throw MiniProgramHostCapabilityException(
      'Expected exactly one Kotlin MainActivity.kt under ${kotlinRoot.path}, '
      'found ${activities.length}.',
    );
  }
  final mainActivity = activities.single;
  final packageName = await readDisplayBrightnessKotlinPackage(mainActivity);
  final mainSource = await mainActivity.readAsString();
  final nativeIntegration = await buildAndroidNativeIntegrationEdit(
    mainActivityFile: mainActivity,
    packageName: packageName,
    mainActivitySource: mainSource,
    registration: 'MiniProgramDisplayBrightnessChannel.register(flutterEngine)',
  );
  final nativeChannel = nativeIntegration.paths.generatedFile(
    'display_brightness',
    'MiniProgramDisplayBrightnessChannel.kt',
  );
  final dartProvider = File(
    p.join(integrationRoot, 'app_android_display_brightness_provider.dart'),
  );
  final hostSetupSource = await hostSetup.readAsString();
  final runtimeSetupSource = await runtimeSetup.readAsString();
  final dartSource = await readDisplayBrightnessFileIfExists(dartProvider);
  final nativeMigration = await resolveAndroidGeneratedSource(
    generatedFile: nativeChannel,
    legacyFile: nativeIntegration.paths.legacyFile(
      'MiniProgramDisplayBrightnessChannel.kt',
    ),
    requiredMarker: 'class MiniProgramDisplayBrightnessChannel',
    buildSource: () => buildAndroidDisplayBrightnessChannelSource(packageName),
  );
  validateDisplayBrightnessOwnedFile(
    file: dartProvider,
    source: dartSource,
    requiredMarker: 'class AppAndroidDisplayBrightnessProvider',
  );
  validateDisplayBrightnessOwnedFile(
    file: nativeChannel,
    source: nativeMigration.source,
    requiredMarker: 'class MiniProgramDisplayBrightnessChannel',
  );
  final installed = isAndroidDisplayBrightnessInstalled(
    hostSetupSource: hostSetupSource,
    runtimeSetupSource: runtimeSetupSource,
    mainActivitySource: mainSource,
    dartProviderSource: dartSource,
    nativeChannelSource: nativeMigration.source,
  );
  final writes = <String, String>{
    if (dartSource == null)
      dartProvider.path: androidDisplayBrightnessProviderSource,
    ...nativeMigration.writes,
    ...nativeIntegration.writes,
  };
  final patchedSetup = patchDisplayBrightnessHostSetup(hostSetupSource);
  final patchedRuntimeSetup = patchDisplayBrightnessRuntimeSetup(
    runtimeSetupSource,
  );
  if (patchedSetup != hostSetupSource) writes[hostSetup.path] = patchedSetup;
  if (patchedRuntimeSetup != runtimeSetupSource) {
    writes[runtimeSetup.path] = patchedRuntimeSetup;
  }
  if (writes.isEmpty && !installed) {
    throw const MiniProgramHostCapabilityException(
      'Android display brightness is partially configured and could not be updated safely.',
    );
  }
  return writeCapabilityFiles(
    projectRootPath: rootPath,
    capability: capability,
    platform: platform,
    writes: writes,
    deletes: nativeMigration.deletes,
  );
}
