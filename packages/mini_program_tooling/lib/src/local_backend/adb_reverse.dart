import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'dependencies.dart';
import 'process_control.dart';

class LocalBackendAdbReverse {
  const LocalBackendAdbReverse(this.dependencies);

  final LocalBackendDependencies dependencies;

  Future<List<String>> configure({required int port}) async {
    if (!dependencies.enableAdbReverse) {
      return const <String>[];
    }

    final processControl = LocalBackendProcessControl(dependencies);
    final adbExecutable = await _resolveExecutable(processControl);
    if (adbExecutable == null) {
      return const <String>[];
    }

    final devicesResult = await processControl.tryShell(
      adbExecutable,
      const <String>['devices'],
    );
    if (devicesResult == null || devicesResult.exitCode != 0) {
      return const <String>[];
    }

    final deviceIds = const LineSplitter()
        .convert('${devicesResult.stdout}')
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty && !line.startsWith('List of devices attached'),
        )
        .map((line) => line.split(RegExp(r'\s+')))
        .where((parts) => parts.length >= 2 && parts[1] == 'device')
        .map((parts) => parts.first)
        .toList();

    if (deviceIds.isEmpty) {
      return const <String>[];
    }

    final reversedDeviceIds = <String>[];
    for (final deviceId in deviceIds) {
      final reverseResult = await processControl.tryShell(
        adbExecutable,
        <String>['-s', deviceId, 'reverse', 'tcp:$port', 'tcp:$port'],
      );
      if (reverseResult != null && reverseResult.exitCode == 0) {
        reversedDeviceIds.add(deviceId);
      }
    }

    return reversedDeviceIds;
  }

  Future<String?> _resolveExecutable(
    LocalBackendProcessControl processControl,
  ) async {
    final candidates = <String>[
      if (Platform.isWindows)
        p.join(
          _resolveLocalAppDataDirectoryPath(),
          'Android',
          'Sdk',
          'platform-tools',
          'adb.exe',
        ),
      if (Platform.environment['ANDROID_SDK_ROOT'] case final sdkRoot?
          when sdkRoot.trim().isNotEmpty)
        p.join(
          sdkRoot,
          'platform-tools',
          Platform.isWindows ? 'adb.exe' : 'adb',
        ),
      if (Platform.environment['ANDROID_HOME'] case final androidHome?
          when androidHome.trim().isNotEmpty)
        p.join(
          androidHome,
          'platform-tools',
          Platform.isWindows ? 'adb.exe' : 'adb',
        ),
      Platform.isWindows ? 'adb.exe' : 'adb',
    ];

    for (final candidate in candidates.toSet()) {
      final result = await processControl.tryShell(candidate, const <String>[
        'version',
      ]);
      if (result != null && result.exitCode == 0) {
        return candidate;
      }
    }

    return null;
  }

  String _resolveLocalAppDataDirectoryPath() {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.trim().isNotEmpty) {
      return localAppData;
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.trim().isNotEmpty) {
      return p.join(userProfile, 'AppData', 'Local');
    }

    return Directory.current.path;
  }
}
