import 'dart:async';
import 'dart:io';

typedef PreviewShellRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

typedef PreviewLanAddressResolver =
    Future<String?> Function({String? preferredPeerHost});

class PreviewLaunchTarget {
  const PreviewLaunchTarget({
    required this.deviceId,
    required this.flutterPlatforms,
    required this.previewServerBindAddress,
    required this.previewServerFallbackPublicHost,
    this.adbReverseMode = PreviewAdbReverseMode.none,
    this.requiresLanPreviewHost = false,
    this.preferredLanPeerHost,
  });

  final String deviceId;
  final Set<String> flutterPlatforms;
  final InternetAddress previewServerBindAddress;
  final String previewServerFallbackPublicHost;
  final PreviewAdbReverseMode adbReverseMode;
  final bool requiresLanPreviewHost;
  final String? preferredLanPeerHost;
}

enum PreviewAdbReverseMode { none, prefer, require }

enum PreviewAndroidConnectionKind { usb, wifi }

class ResolvedPreviewAdbDevice {
  const ResolvedPreviewAdbDevice({
    required this.deviceId,
    required this.connectionKind,
    this.peerHost,
  });

  final String deviceId;
  final PreviewAndroidConnectionKind connectionKind;
  final String? peerHost;
}

class PreparedPreviewTransport {
  const PreparedPreviewTransport({
    required this.publicHost,
    this.usedAdbReverse = false,
    this.diagnosticMessage,
  });

  final String publicHost;
  final bool usedAdbReverse;
  final String? diagnosticMessage;
}

typedef PreviewProcessStarter =
    Future<StartedPreviewProcess> Function({
      required String executable,
      required List<String> arguments,
      required String workingDirectory,
      Map<String, String>? environment,
    });

class MiniProgramPreviewRequest {
  const MiniProgramPreviewRequest({
    required this.miniProgramId,
    required this.miniProgramRootPath,
    required this.deviceId,
    this.repoRootPath,
    this.mpBuildScriptPath,
  });

  final String miniProgramId;
  final String miniProgramRootPath;
  final String deviceId;
  final String? repoRootPath;
  final String? mpBuildScriptPath;
}

class StartedPreviewProcess {
  const StartedPreviewProcess({
    required this.pid,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.kill,
  });

  final int pid;
  final Stream<List<int>> stdout;
  final Stream<List<int>> stderr;
  final Future<int> exitCode;
  final bool Function([ProcessSignal signal]) kill;
}
