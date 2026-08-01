import '../models.dart';

String patchFlashlightHostSetup(String source) {
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
    "import 'app_android_flashlight_provider.dart';",
    before: "import 'app_host_bridge.dart';",
  );
  final signatureStart = updated.indexOf(function);
  final signatureEnd = updated.indexOf('}) async {', signatureStart);
  if (signatureEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely update buildHostMiniProgramConfig parameters.',
    );
  }
  if (!updated
      .substring(signatureStart, signatureEnd)
      .contains('MiniProgramFlashlightProvider? flashlightProvider')) {
    updated = updated.replaceRange(
      signatureEnd,
      signatureEnd,
      '  MiniProgramFlashlightProvider? flashlightProvider,$newline',
    );
  }
  if (!updated.contains('final resolvedFlashlightProvider =')) {
    final returnIndex = updated.indexOf(
      '  return buildMiniProgramConfig(',
      signatureStart,
    );
    if (returnIndex == -1) {
      throw const MiniProgramHostCapabilityException(
        'Could not locate buildMiniProgramConfig in host setup.',
      );
    }
    final resolution =
        '  final resolvedFlashlightProvider =$newline'
        '      flashlightProvider ??$newline'
        '      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android$newline'
        '          ? const AppAndroidFlashlightProvider()$newline'
        '          : null);$newline$newline';
    updated = updated.replaceRange(returnIndex, returnIndex, resolution);
  }
  final direct = RegExp(r'flashlightProvider:\s*flashlightProvider,');
  if (direct.hasMatch(updated)) {
    return updated.replaceFirst(
      direct,
      'flashlightProvider: resolvedFlashlightProvider,',
    );
  }
  if (updated.contains('flashlightProvider: resolvedFlashlightProvider,')) {
    return updated;
  }
  final callStart = updated.indexOf(
    '  return buildMiniProgramConfig(',
    signatureStart,
  );
  final callEnd = updated.indexOf('  );', callStart);
  if (callStart == -1 || callEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely wire the flashlight provider.',
    );
  }
  return updated.replaceRange(
    callEnd,
    callEnd,
    '    flashlightProvider: resolvedFlashlightProvider,$newline',
  );
}

String patchFlashlightRuntimeSetup(String source) {
  const function = 'MiniProgramConfig buildMiniProgramConfig({';
  if (!source.contains(function)) {
    throw const MiniProgramHostCapabilityException(
      'mini_program_runtime_setup.dart does not contain '
      'buildMiniProgramConfig.',
    );
  }
  final newline = _newlineFor(source);
  var updated = source;
  final signatureStart = updated.indexOf(function);
  final signatureEnd = updated.indexOf('}) {', signatureStart);
  if (signatureEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely update buildMiniProgramConfig parameters.',
    );
  }
  if (!updated
      .substring(signatureStart, signatureEnd)
      .contains('MiniProgramFlashlightProvider? flashlightProvider')) {
    updated = updated.replaceRange(
      signatureEnd,
      signatureEnd,
      '  MiniProgramFlashlightProvider? flashlightProvider,$newline',
    );
  }

  const capabilitiesMarker = '  final supportedCapabilities = <CapabilityId>{';
  final capabilitiesStart = updated.indexOf(capabilitiesMarker, signatureStart);
  final capabilitiesEnd = updated.indexOf('  };', capabilitiesStart);
  if (capabilitiesStart == -1 || capabilitiesEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely locate the generated capability registry.',
    );
  }
  if (!updated
      .substring(capabilitiesStart, capabilitiesEnd)
      .contains('CapabilityIds.flashlightControl')) {
    updated = updated.replaceRange(
      capabilitiesEnd,
      capabilitiesEnd,
      '    if (flashlightProvider != null) '
      'CapabilityIds.flashlightControl,$newline',
    );
  }

  final configStart = updated.indexOf(
    '  return MiniProgramConfig(',
    capabilitiesEnd,
  );
  final configEnd = updated.indexOf('  );', configStart);
  if (configStart == -1 || configEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely locate the generated MiniProgramConfig call.',
    );
  }
  if (!updated
      .substring(configStart, configEnd)
      .contains('flashlightProvider: flashlightProvider,')) {
    updated = updated.replaceRange(
      configEnd,
      configEnd,
      '    flashlightProvider: flashlightProvider,$newline',
    );
  }
  return updated;
}

String patchFlashlightAndroidManifest(String source) {
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
      '    <uses-feature android:name="android.hardware.camera.any" '
      'android:required="false" />',
      newline,
    );
  }
  if (!updated.contains('android.hardware.camera.flash')) {
    updated = _insertAfterManifestRoot(
      updated,
      '    <uses-feature android:name="android.hardware.camera.flash" '
      'android:required="false" />',
      newline,
    );
  }
  return updated;
}

String patchFlashlightMainActivity(String source) {
  const registration = 'MiniProgramFlashlightChannel.register(flutterEngine)';
  if (source.contains(registration)) return source;
  final newline = _newlineFor(source);
  var updated = _ensureImport(
    source,
    'import io.flutter.embedding.engine.FlutterEngine',
    before: 'import io.flutter.plugin',
    fallbackAfter: 'import io.flutter.embedding.android.FlutterActivity',
  );
  final classMatch = RegExp(
    r'class\s+MainActivity\s*:\s*(FlutterActivity|FlutterFragmentActivity)\(\)',
  ).firstMatch(updated);
  if (classMatch == null) {
    throw const MiniProgramHostCapabilityException(
      'MainActivity.kt must extend FlutterActivity or '
      'FlutterFragmentActivity for automatic flashlight capability '
      'installation.',
    );
  }
  final activityBase = classMatch.group(1)!;
  final classTail = updated.substring(classMatch.end);
  final firstContentIndex = classTail.indexOf(RegExp(r'\S'));
  if (firstContentIndex == -1) {
    final replacement =
        'class MainActivity : $activityBase() {$newline'
        '    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {$newline'
        '        super.configureFlutterEngine(flutterEngine)$newline'
        '        $registration$newline'
        '    }$newline'
        '}';
    return updated.replaceRange(classMatch.start, updated.length, replacement);
  }
  if (classTail[firstContentIndex] != '{') {
    throw const MiniProgramHostCapabilityException(
      'MainActivity.kt uses an unsupported custom class declaration.',
    );
  }
  if (updated.contains('override fun configureFlutterEngine(')) {
    const superCall = 'super.configureFlutterEngine(flutterEngine)';
    final superIndex = updated.indexOf(superCall, classMatch.end);
    if (superIndex == -1) {
      throw const MiniProgramHostCapabilityException(
        'MainActivity.configureFlutterEngine must call super first.',
      );
    }
    return updated.replaceRange(
      superIndex + superCall.length,
      superIndex + superCall.length,
      '$newline        $registration',
    );
  }
  final classEnd = updated.lastIndexOf('}');
  if (classEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not locate the end of MainActivity.kt.',
    );
  }
  final method =
      '    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {$newline'
      '        super.configureFlutterEngine(flutterEngine)$newline'
      '        $registration$newline'
      '    }$newline$newline';
  return updated.replaceRange(classEnd, classEnd, method);
}

String _insertAfterManifestRoot(
  String source,
  String declaration,
  String newline,
) {
  final manifestEnd = source.indexOf('>');
  if (manifestEnd == -1 ||
      !source.substring(0, manifestEnd).contains('<manifest')) {
    throw const MiniProgramHostCapabilityException(
      'AndroidManifest.xml does not contain a valid <manifest> root.',
    );
  }
  return source.replaceRange(
    manifestEnd + 1,
    manifestEnd + 1,
    '$newline$declaration',
  );
}

String _ensureImport(
  String source,
  String statement, {
  String? before,
  String? fallbackAfter,
}) {
  if (source.contains(statement)) return source;
  final newline = _newlineFor(source);
  if (before != null) {
    final index = source.indexOf(before);
    if (index != -1) {
      return source.replaceRange(index, index, '$statement$newline');
    }
  }
  if (fallbackAfter != null) {
    final index = source.indexOf(fallbackAfter);
    if (index != -1) {
      return source.replaceRange(
        index + fallbackAfter.length,
        index + fallbackAfter.length,
        '$newline$statement',
      );
    }
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
