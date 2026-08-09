import '../models.dart';

String patchDisplayBrightnessHostSetup(String source) {
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
    "import 'app_android_display_brightness_provider.dart';",
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
      .contains(
        'MiniProgramDisplayBrightnessProvider? displayBrightnessProvider',
      )) {
    updated = updated.replaceRange(
      signatureEnd,
      signatureEnd,
      '  MiniProgramDisplayBrightnessProvider? displayBrightnessProvider,$newline',
    );
  }
  if (!updated.contains('final resolvedDisplayBrightnessProvider =')) {
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
        '  final resolvedDisplayBrightnessProvider =$newline'
        '      displayBrightnessProvider ??$newline'
        '      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android$newline'
        '          ? const AppAndroidDisplayBrightnessProvider()$newline'
        '          : null);$newline$newline';
    updated = updated.replaceRange(returnIndex, returnIndex, resolution);
  }
  final direct = RegExp(
    r'displayBrightnessProvider:\s*displayBrightnessProvider,',
  );
  if (direct.hasMatch(updated)) {
    return updated.replaceFirst(
      direct,
      'displayBrightnessProvider: resolvedDisplayBrightnessProvider,',
    );
  }
  if (updated.contains(
    'displayBrightnessProvider: resolvedDisplayBrightnessProvider,',
  )) {
    return updated;
  }
  final callStart = updated.indexOf(
    '  return buildMiniProgramConfig(',
    signatureStart,
  );
  final callEnd = updated.indexOf('  );', callStart);
  if (callStart == -1 || callEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely wire the display brightness provider.',
    );
  }
  return updated.replaceRange(
    callEnd,
    callEnd,
    '    displayBrightnessProvider: resolvedDisplayBrightnessProvider,$newline',
  );
}

String patchDisplayBrightnessRuntimeSetup(String source) {
  const function = 'MiniProgramConfig buildMiniProgramConfig({';
  if (!source.contains(function)) {
    throw const MiniProgramHostCapabilityException(
      'mini_program_runtime_setup.dart does not contain buildMiniProgramConfig.',
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
      .contains(
        'MiniProgramDisplayBrightnessProvider? displayBrightnessProvider',
      )) {
    updated = updated.replaceRange(
      signatureEnd,
      signatureEnd,
      '  MiniProgramDisplayBrightnessProvider? displayBrightnessProvider,$newline',
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
      .contains('CapabilityIds.displayBrightness')) {
    updated = updated.replaceRange(
      capabilitiesEnd,
      capabilitiesEnd,
      '    if (displayBrightnessProvider != null) CapabilityIds.displayBrightness,$newline',
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
      .contains('displayBrightnessProvider: displayBrightnessProvider,')) {
    updated = updated.replaceRange(
      configEnd,
      configEnd,
      '    displayBrightnessProvider: displayBrightnessProvider,$newline',
    );
  }
  return updated;
}

String _ensureImport(String source, String statement, {String? before}) {
  if (source.contains(statement)) return source;
  final newline = _newlineFor(source);
  if (before != null) {
    final index = source.indexOf(before);
    if (index != -1) {
      return source.replaceRange(index, index, '$statement$newline');
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
