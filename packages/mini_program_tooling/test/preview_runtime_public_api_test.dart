import 'dart:async';
import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test('preview runtime remains available through the public barrel', () {
    const request = MiniProgramPreviewRequest(
      miniProgramId: 'calculator',
      miniProgramRootPath: 'mini_programs/calculator',
      deviceId: 'chrome',
    );
    const bundle = MiniProgramPreviewBundle(
      miniProgramId: 'calculator',
      title: 'Calculator',
      manifestJson: <String, dynamic>{'id': 'calculator'},
      screenJsonById: <String, Map<String, dynamic>>{},
    );
    const hostRequest = MiniProgramPreviewHostInitRequest(
      hostRootPath: '.mini_program/preview_host',
    );
    const hostResult = MiniProgramPreviewHostInitResult(
      hostRootPath: '.mini_program/preview_host',
      managedPaths: <String>[],
      usedPathDependencies: false,
    );
    final target = PreviewLaunchTarget(
      deviceId: 'chrome',
      flutterPlatforms: const <String>{'web'},
      previewServerBindAddress: InternetAddress.loopbackIPv4,
      previewServerFallbackPublicHost: '127.0.0.1',
    );
    final process = StartedPreviewProcess(
      pid: 1,
      stdout: const Stream<List<int>>.empty(),
      stderr: const Stream<List<int>>.empty(),
      exitCode: Future<int>.value(0),
      kill: ([ProcessSignal signal = ProcessSignal.sigterm]) => true,
    );

    expect(const MiniProgramPreviewController(), isNotNull);
    expect(const MiniProgramPreviewHostInitializer(), isNotNull);
    expect(const MiniProgramPreviewBundleLoader(), isNotNull);
    expect(MiniProgramPreviewServer(), isNotNull);
    expect(MiniProgramPreviewWatcher(), isNotNull);
    expect(request.deviceId, 'chrome');
    expect(bundle.title, 'Calculator');
    expect(hostRequest.screenFormat, 'mp');
    expect(hostResult.usedPathDependencies, isFalse);
    expect(target.adbReverseMode, PreviewAdbReverseMode.none);
    expect(process.pid, 1);
    expect(
      MiniProgramPreviewController.supportedDeviceIds,
      containsAll(<String>['chrome', 'edge', 'windows']),
    );
    expect(
      const MiniProgramPreviewException('preview failed').toString(),
      'preview failed',
    );
    expect(
      const MiniProgramPreviewHostInitException('host failed').toString(),
      'host failed',
    );
  });
}
