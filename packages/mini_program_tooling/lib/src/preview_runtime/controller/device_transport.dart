import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../server/models.dart';
import 'models.dart';

const Set<String> supportedPreviewDeviceIds = <String>{
  'chrome',
  'edge',
  'ios',
  'linux',
  'macos',
  'windows',
};

final RegExp _androidEmulatorDeviceIdPattern = RegExp(r'^emulator-\d+$');

class PreviewDeviceTransportResolver {
  const PreviewDeviceTransportResolver({
    required PreviewShellRunner shellRunner,
    required PreviewLanAddressResolver lanAddressResolver,
  }) : _shellRunner = shellRunner,
       _lanAddressResolver = lanAddressResolver;

  final PreviewShellRunner _shellRunner;
  final PreviewLanAddressResolver _lanAddressResolver;

  Future<PreviewLaunchTarget> resolveLaunchTarget(String deviceId) async {
    final trimmedDeviceId = deviceId.trim();
    final normalizedDeviceId = trimmedDeviceId.toLowerCase();
    if (normalizedDeviceId == 'chrome') {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'web'},
        previewServerBindAddress: InternetAddress.loopbackIPv4,
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
      );
    }

    if (normalizedDeviceId == 'edge') {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'web'},
        previewServerBindAddress: InternetAddress.loopbackIPv4,
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
      );
    }

    if (normalizedDeviceId == 'ios') {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'ios'},
        previewServerBindAddress: InternetAddress.loopbackIPv4,
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
      );
    }

    if (normalizedDeviceId == 'windows') {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'windows'},
        previewServerBindAddress: InternetAddress.loopbackIPv4,
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
      );
    }

    if (normalizedDeviceId == 'linux') {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'linux'},
        previewServerBindAddress: InternetAddress.loopbackIPv4,
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
      );
    }

    if (normalizedDeviceId == 'macos') {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'macos'},
        previewServerBindAddress: InternetAddress.loopbackIPv4,
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
      );
    }

    if (_androidEmulatorDeviceIdPattern.hasMatch(normalizedDeviceId)) {
      return PreviewLaunchTarget(
        deviceId: normalizedDeviceId,
        flutterPlatforms: const <String>{'android'},
        previewServerBindAddress: InternetAddress.anyIPv4,
        previewServerFallbackPublicHost: '10.0.2.2',
        adbReverseMode: PreviewAdbReverseMode.prefer,
      );
    }

    final adbDevice = await _resolveConnectedAdbDevice(trimmedDeviceId);
    if (adbDevice != null &&
        adbDevice.connectionKind == PreviewAndroidConnectionKind.usb) {
      return PreviewLaunchTarget(
        deviceId: adbDevice.deviceId,
        flutterPlatforms: const <String>{'android'},
        previewServerBindAddress: InternetAddress.anyIPv4,
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
        adbReverseMode: PreviewAdbReverseMode.require,
      );
    }

    if (adbDevice != null &&
        adbDevice.connectionKind == PreviewAndroidConnectionKind.wifi) {
      return PreviewLaunchTarget(
        deviceId: adbDevice.deviceId,
        flutterPlatforms: const <String>{'android'},
        previewServerBindAddress: InternetAddress.anyIPv4,
        previewServerFallbackPublicHost: InternetAddress.loopbackIPv4.address,
        requiresLanPreviewHost: true,
        preferredLanPeerHost: adbDevice.peerHost,
      );
    }

    throw MiniProgramPreviewException(_unsupportedDeviceMessage(deviceId));
  }

  String _unsupportedDeviceMessage(String deviceId) {
    final supported = <String>[
      ...supportedPreviewDeviceIds.toList()..sort(),
      'Android emulator ids like emulator-5554',
      'Android USB device ids like R58M123ABC',
      'Android Wi-Fi device ids like 192.168.1.25:5555',
    ];
    return 'Preview currently supports only these devices: '
        '${supported.join(', ')}. '
        'Received: $deviceId';
  }

  Future<ResolvedPreviewAdbDevice?> _resolveConnectedAdbDevice(
    String requestedDeviceId,
  ) async {
    final adbExecutable = await _resolveAdbExecutable();
    if (adbExecutable == null) {
      return null;
    }

    final devicesResult = await _tryShell(adbExecutable, const <String>[
      'devices',
    ]);
    if (devicesResult == null || devicesResult.exitCode != 0) {
      return null;
    }

    final connectedDeviceIds = const LineSplitter()
        .convert('${devicesResult.stdout}')
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty && !line.startsWith('List of devices attached'),
        )
        .map((line) => line.split(RegExp(r'\s+')))
        .where((parts) => parts.length >= 2 && parts[1] == 'device')
        .map((parts) => parts.first)
        .where(
          (deviceId) =>
              !_androidEmulatorDeviceIdPattern.hasMatch(deviceId.toLowerCase()),
        )
        .toList();

    for (final connectedDeviceId in connectedDeviceIds) {
      if (connectedDeviceId.toLowerCase() == requestedDeviceId.toLowerCase()) {
        if (_looksLikeWirelessAdbDeviceId(connectedDeviceId)) {
          return ResolvedPreviewAdbDevice(
            deviceId: connectedDeviceId,
            connectionKind: PreviewAndroidConnectionKind.wifi,
            peerHost: _extractWirelessDeviceHost(connectedDeviceId),
          );
        }

        return ResolvedPreviewAdbDevice(
          deviceId: connectedDeviceId,
          connectionKind: PreviewAndroidConnectionKind.usb,
        );
      }
    }

    return null;
  }

  Future<PreparedPreviewTransport> prepareTransport(
    PreviewLaunchTarget launchTarget, {
    required int port,
  }) async {
    if (launchTarget.requiresLanPreviewHost) {
      final lanPreviewHost = await _resolvePreviewLanHost(
        preferredPeerHost: launchTarget.preferredLanPeerHost,
      );
      return PreparedPreviewTransport(
        publicHost: lanPreviewHost,
        diagnosticMessage:
            'Android Wi-Fi preview: using LAN host $lanPreviewHost '
            'for ${launchTarget.deviceId}.',
      );
    }

    if (launchTarget.adbReverseMode == PreviewAdbReverseMode.none) {
      return PreparedPreviewTransport(
        publicHost: launchTarget.previewServerFallbackPublicHost,
      );
    }

    final adbExecutable = await _resolveAdbExecutable();
    if (adbExecutable == null) {
      if (launchTarget.adbReverseMode == PreviewAdbReverseMode.require) {
        throw const MiniProgramPreviewException(
          'Android USB preview requires adb, but no adb executable was found.',
        );
      }

      return PreparedPreviewTransport(
        publicHost: launchTarget.previewServerFallbackPublicHost,
        diagnosticMessage:
            'ADB reverse was not available for ${launchTarget.deviceId}. '
            'Falling back to ${launchTarget.previewServerFallbackPublicHost}.',
      );
    }

    final reverseResult = await _tryShell(adbExecutable, <String>[
      '-s',
      launchTarget.deviceId,
      'reverse',
      'tcp:$port',
      'tcp:$port',
    ]);
    if (reverseResult == null) {
      if (launchTarget.adbReverseMode == PreviewAdbReverseMode.require) {
        throw MiniProgramPreviewException(
          'Android USB preview could not run adb reverse for ${launchTarget.deviceId}.',
        );
      }

      return PreparedPreviewTransport(
        publicHost: launchTarget.previewServerFallbackPublicHost,
        diagnosticMessage:
            'ADB reverse could not run for ${launchTarget.deviceId}. '
            'Falling back to ${launchTarget.previewServerFallbackPublicHost}.',
      );
    }
    if (reverseResult.exitCode == 0) {
      return const PreparedPreviewTransport(
        publicHost: '127.0.0.1',
        usedAdbReverse: true,
      );
    }

    final stderrText = '${reverseResult.stderr}'.trim();
    final stdoutText = '${reverseResult.stdout}'.trim();
    final details = [
      'Command: adb -s ${launchTarget.deviceId} reverse tcp:$port tcp:$port',
      if (stdoutText.isNotEmpty) 'stdout:\n$stdoutText',
      if (stderrText.isNotEmpty) 'stderr:\n$stderrText',
    ].join('\n');

    if (launchTarget.adbReverseMode == PreviewAdbReverseMode.require) {
      throw MiniProgramPreviewException(
        [
          'Android USB preview requires adb reverse, but it failed for ${launchTarget.deviceId}.',
          details,
        ].join('\n'),
      );
    }

    return PreparedPreviewTransport(
      publicHost: launchTarget.previewServerFallbackPublicHost,
      diagnosticMessage:
          'ADB reverse failed for ${launchTarget.deviceId}. '
          'Falling back to ${launchTarget.previewServerFallbackPublicHost}.\n'
          '$details',
    );
  }

  Future<String> _resolvePreviewLanHost({String? preferredPeerHost}) async {
    final manualHost =
        Platform.environment['MINI_PROGRAM_PREVIEW_LAN_HOST']?.trim() ?? '';
    final fallbackManualHost =
        Platform.environment['MINI_PROGRAM_PREVIEW_PUBLIC_HOST']?.trim() ?? '';
    if (manualHost.isNotEmpty) {
      return manualHost;
    }
    if (fallbackManualHost.isNotEmpty) {
      return fallbackManualHost;
    }

    final resolvedHost = await _lanAddressResolver(
      preferredPeerHost: preferredPeerHost,
    );
    if (resolvedHost case final host? when host.trim().isNotEmpty) {
      return host.trim();
    }

    throw MiniProgramPreviewException(
      'Android Wi-Fi preview requires a reachable LAN IPv4 address on this '
      'machine, but none could be resolved. Set MINI_PROGRAM_PREVIEW_LAN_HOST '
      'to your dev machine IP and try again.',
    );
  }

  Future<String?> _resolveAdbExecutable() async {
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
      final result = await _tryShell(candidate, const <String>['version']);
      if (result != null && result.exitCode == 0) {
        return candidate;
      }
    }

    return null;
  }

  Future<ProcessResult?> _tryShell(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    try {
      return await _shellRunner(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      );
    } on ProcessException {
      return null;
    }
  }
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

bool _looksLikeWirelessAdbDeviceId(String deviceId) {
  if (!deviceId.contains(':')) {
    return false;
  }

  final host = _extractWirelessDeviceHost(deviceId);
  return host != null && host.trim().isNotEmpty;
}

String? _extractWirelessDeviceHost(String deviceId) {
  final separatorIndex = deviceId.lastIndexOf(':');
  if (separatorIndex <= 0 || separatorIndex == deviceId.length - 1) {
    return null;
  }

  return deviceId.substring(0, separatorIndex).trim();
}

Future<String?> defaultPreviewLanAddressResolver({
  String? preferredPeerHost,
}) async {
  List<NetworkInterface> interfaces;
  try {
    interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
  } on SocketException {
    return null;
  }

  final candidates = <String>[];
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      final host = address.address.trim();
      if (host.isEmpty ||
          address.isLoopback ||
          host == InternetAddress.anyIPv4.address ||
          _isLinkLocalIpv4(host)) {
        continue;
      }
      candidates.add(host);
    }
  }

  if (candidates.isEmpty) {
    return null;
  }

  final uniqueCandidates = candidates.toSet().toList();
  if (preferredPeerHost != null && preferredPeerHost.trim().isNotEmpty) {
    uniqueCandidates.sort(
      (left, right) => _compareLanCandidates(
        left,
        right,
        preferredPeerHost: preferredPeerHost,
      ),
    );
  } else {
    uniqueCandidates.sort((left, right) {
      final leftPrivate = _isPrivateIpv4(left);
      final rightPrivate = _isPrivateIpv4(right);
      if (leftPrivate != rightPrivate) {
        return leftPrivate ? -1 : 1;
      }
      return left.compareTo(right);
    });
  }

  return uniqueCandidates.first;
}

int _compareLanCandidates(
  String left,
  String right, {
  required String preferredPeerHost,
}) {
  final leftScore = _sharedIpv4OctetPrefixLength(left, preferredPeerHost);
  final rightScore = _sharedIpv4OctetPrefixLength(right, preferredPeerHost);
  if (leftScore != rightScore) {
    return rightScore.compareTo(leftScore);
  }

  final leftPrivate = _isPrivateIpv4(left);
  final rightPrivate = _isPrivateIpv4(right);
  if (leftPrivate != rightPrivate) {
    return leftPrivate ? -1 : 1;
  }

  return left.compareTo(right);
}

int _sharedIpv4OctetPrefixLength(String left, String right) {
  final leftParts = left.split('.');
  final rightParts = right.split('.');
  if (leftParts.length != 4 || rightParts.length != 4) {
    return 0;
  }

  var score = 0;
  for (var index = 0; index < 4; index += 1) {
    if (leftParts[index] != rightParts[index]) {
      break;
    }
    score += 1;
  }
  return score;
}

bool _isPrivateIpv4(String host) {
  final octets = host.split('.').map(int.tryParse).toList();
  if (octets.length != 4 || octets.any((value) => value == null)) {
    return false;
  }

  final first = octets[0]!;
  final second = octets[1]!;
  return first == 10 ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168);
}

bool _isLinkLocalIpv4(String host) {
  final octets = host.split('.').map(int.tryParse).toList();
  if (octets.length != 4 || octets.any((value) => value == null)) {
    return false;
  }
  return octets[0] == 169 && octets[1] == 254;
}
