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

String patchQrMainActivity(String source) => _patchMainActivity(
  source,
  'MiniProgramQrScannerChannel.register(flutterEngine)',
);

String patchQrGradle(String source, {required bool kotlinDsl}) {
  if (source.contains('mini-program-qr-capability')) return source;
  final quote = kotlinDsl ? '"' : "'";
  final callStart = kotlinDsl ? 'implementation(' : 'implementation ';
  final callEnd = kotlinDsl ? ')' : '';
  return '$source\n// mini-program-qr-capability\ndependencies {\n'
      '    $callStart${quote}androidx.camera:camera-camera2:1.4.2$quote$callEnd\n'
      '    $callStart${quote}androidx.camera:camera-lifecycle:1.4.2$quote$callEnd\n'
      '    $callStart${quote}androidx.camera:camera-view:1.4.2$quote$callEnd\n'
      '    $callStart${quote}com.google.mlkit:barcode-scanning:17.3.0$quote$callEnd\n'
      '}\n';
}

String _patchMainActivity(String source, String registration) {
  if (source.contains(registration)) return source;
  final newline = _newlineFor(source);
  var updated = _ensureImport(
    source,
    'import io.flutter.embedding.engine.FlutterEngine',
    before: 'import io.flutter.plugin',
    fallbackAfter: 'import io.flutter.embedding.android.FlutterActivity',
  );
  final match = RegExp(
    r'class\s+MainActivity\s*:\s*(FlutterActivity|FlutterFragmentActivity)\(\)',
  ).firstMatch(updated);
  if (match == null) {
    throw const MiniProgramHostCapabilityException(
      'MainActivity.kt must extend FlutterActivity or FlutterFragmentActivity.',
    );
  }
  if (updated.contains('override fun configureFlutterEngine(')) {
    const superCall = 'super.configureFlutterEngine(flutterEngine)';
    final index = updated.indexOf(superCall, match.end);
    if (index == -1) {
      throw const MiniProgramHostCapabilityException(
        'MainActivity.configureFlutterEngine must call super first.',
      );
    }
    return updated.replaceRange(
      index + superCall.length,
      index + superCall.length,
      '$newline        $registration',
    );
  }
  final tail = updated.substring(match.end);
  final first = tail.indexOf(RegExp(r'\S'));
  if (first == -1) {
    return updated.replaceRange(
      match.start,
      updated.length,
      'class MainActivity : ${match.group(1)}() {$newline'
      '    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {$newline'
      '        super.configureFlutterEngine(flutterEngine)$newline'
      '        $registration$newline'
      '    }$newline'
      '}',
    );
  }
  if (tail[first] != '{') {
    throw const MiniProgramHostCapabilityException(
      'MainActivity.kt uses an unsupported custom declaration.',
    );
  }
  final end = updated.lastIndexOf('}');
  return updated.replaceRange(
    end,
    end,
    '    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {$newline'
    '        super.configureFlutterEngine(flutterEngine)$newline'
    '        $registration$newline'
    '    }$newline$newline',
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
