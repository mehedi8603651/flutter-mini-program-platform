import '../android/gradle_editor.dart';
import '../android/main_activity_editor.dart';
import '../models.dart';

String patchQrHostSetup(String source) {
  const function = 'Future<MiniProgramConfig> buildHostMiniProgramConfig(';
  if (!source.contains(function)) {
    throw const MiniProgramHostCapabilityException(
      'mini_program_host_setup.dart does not contain buildHostMiniProgramConfig.',
    );
  }
  final newline = _newlineFor(source);
  var updated = _ensureImport(
    source,
    "import 'package:flutter/foundation.dart';",
    before: "import 'package:mini_program_sdk/mini_program_sdk.dart';",
  );
  updated = _ensureImport(
    updated,
    "import 'app_android_qr_scanner_provider.dart';",
    before: "import 'app_host_bridge.dart';",
  );
  final start = updated.indexOf(function);
  var end = updated.indexOf('}) async {', start);
  if (end == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely update buildHostMiniProgramConfig parameters.',
    );
  }
  if (!updated
      .substring(start, end)
      .contains('MiniProgramQrScannerProvider? qrScannerProvider')) {
    updated = updated.replaceRange(
      end,
      end,
      '  MiniProgramQrScannerProvider? qrScannerProvider,$newline',
    );
  }
  if (!updated.contains('final resolvedQrScannerProvider =')) {
    final returnIndex = updated.indexOf(
      '  return buildMiniProgramConfig(',
      start,
    );
    if (returnIndex == -1) {
      throw const MiniProgramHostCapabilityException(
        'Could not locate buildMiniProgramConfig in host setup.',
      );
    }
    updated = updated.replaceRange(
      returnIndex,
      returnIndex,
      '  final resolvedQrScannerProvider =$newline'
      '      qrScannerProvider ??$newline'
      '      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android$newline'
      '          ? const AppAndroidQrScannerProvider()$newline'
      '          : null);$newline$newline',
    );
  }
  final direct = RegExp(r'qrScannerProvider:\s*qrScannerProvider,');
  if (direct.hasMatch(updated)) {
    return updated.replaceFirst(
      direct,
      'qrScannerProvider: resolvedQrScannerProvider,',
    );
  }
  if (updated.contains('qrScannerProvider: resolvedQrScannerProvider,')) {
    return updated;
  }
  final callStart = updated.indexOf('  return buildMiniProgramConfig(', start);
  final callEnd = updated.indexOf('  );', callStart);
  if (callStart == -1 || callEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely wire the QR scanner provider.',
    );
  }
  return updated.replaceRange(
    callEnd,
    callEnd,
    '    qrScannerProvider: resolvedQrScannerProvider,$newline',
  );
}

String patchQrRuntimeSetup(String source) {
  const function = 'MiniProgramConfig buildMiniProgramConfig({';
  final newline = _newlineFor(source);
  var updated = source;
  final start = updated.indexOf(function);
  var end = updated.indexOf('}) {', start);
  if (start == -1 || end == -1) {
    throw const MiniProgramHostCapabilityException(
      'mini_program_runtime_setup.dart has an unsupported structure.',
    );
  }
  if (!updated
      .substring(start, end)
      .contains('MiniProgramQrScannerProvider? qrScannerProvider')) {
    updated = updated.replaceRange(
      end,
      end,
      '  MiniProgramQrScannerProvider? qrScannerProvider,$newline',
    );
  }
  const capabilities = '  final supportedCapabilities = <CapabilityId>{';
  final capabilitiesStart = updated.indexOf(capabilities, start);
  final capabilitiesEnd = updated.indexOf('  };', capabilitiesStart);
  if (capabilitiesStart == -1 || capabilitiesEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not locate the generated capability registry.',
    );
  }
  if (!updated
      .substring(capabilitiesStart, capabilitiesEnd)
      .contains('CapabilityIds.qrScanner')) {
    updated = updated.replaceRange(
      capabilitiesEnd,
      capabilitiesEnd,
      '    if (qrScannerProvider != null) CapabilityIds.qrScanner,$newline',
    );
  }
  final configStart = updated.indexOf(
    '  return MiniProgramConfig(',
    capabilitiesEnd,
  );
  final configEnd = updated.indexOf('  );', configStart);
  if (configStart == -1 || configEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not locate the generated MiniProgramConfig call.',
    );
  }
  if (!updated
      .substring(configStart, configEnd)
      .contains('qrScannerProvider: qrScannerProvider,')) {
    updated = updated.replaceRange(
      configEnd,
      configEnd,
      '    qrScannerProvider: qrScannerProvider,$newline',
    );
  }
  return updated;
}

String patchQrAndroidManifest(String source, String packageName) {
  final newline = _newlineFor(source);
  var updated = source;
  if (!updated.contains('android.permission.CAMERA')) {
    updated = _insertAfterManifestRoot(
      updated,
      '    <uses-permission android:name="android.permission.CAMERA" />',
      newline,
    );
  }
  if (!updated.contains('android.hardware.camera.any')) {
    updated = _insertAfterManifestRoot(
      updated,
      '    <uses-feature android:name="android.hardware.camera.any" android:required="false" />',
      newline,
    );
  }
  if (!updated.contains('.MiniProgramQrScannerActivity')) {
    final end = updated.lastIndexOf('</application>');
    if (end == -1) {
      throw const MiniProgramHostCapabilityException(
        'AndroidManifest.xml does not contain an application element.',
      );
    }
    updated = updated.replaceRange(
      end,
      end,
      '        <activity$newline'
      '            android:name="$packageName.MiniProgramQrScannerActivity"$newline'
      '            android:exported="false"$newline'
      '            android:screenOrientation="portrait"$newline'
      '            android:theme="@android:style/Theme.Material.NoActionBar" />$newline',
    );
  }
  return updated;
}

String patchQrMainActivity(String source) =>
    patchAndroidMainActivityRegistration(
      source,
      registration: 'MiniProgramQrScannerChannel.register(flutterEngine)',
    );

String patchQrGradle(String source, {required bool kotlinDsl}) {
  return patchAndroidCapabilityDependencies(
    source,
    capability: androidQrDependencyCapability,
    kotlinDsl: kotlinDsl,
  );
}

String _insertAfterManifestRoot(String source, String value, String newline) {
  final end = source.indexOf('>');
  if (end == -1 || !source.substring(0, end).contains('<manifest')) {
    throw const MiniProgramHostCapabilityException(
      'AndroidManifest.xml does not contain a valid manifest root.',
    );
  }
  return source.replaceRange(end + 1, end + 1, '$newline$value');
}

String _ensureImport(
  String source,
  String statement, {
  String? before,
  String? fallbackAfter,
}) {
  if (source.contains(statement)) return source;
  final newline = _newlineFor(source);
  if (before != null && source.contains(before)) {
    return source.replaceFirst(before, '$statement$newline$before');
  }
  if (fallbackAfter != null && source.contains(fallbackAfter)) {
    return source.replaceFirst(
      fallbackAfter,
      '$fallbackAfter$newline$statement',
    );
  }
  final imports = RegExp(
    r'^import .+?;?\s*$',
    multiLine: true,
  ).allMatches(source);
  if (imports.isEmpty) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely update the import block.',
    );
  }
  return source.replaceRange(
    imports.last.end,
    imports.last.end,
    '$newline$statement',
  );
}

String _newlineFor(String source) => source.contains('\r\n') ? '\r\n' : '\n';
