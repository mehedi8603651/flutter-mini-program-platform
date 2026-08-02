import '../android/gradle_editor.dart';
import '../android/main_activity_editor.dart';
import '../models.dart';

String patchMediaPlaybackHostSetup(String source) {
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
    "import 'app_android_media_playback_provider.dart';",
    before: "import 'app_host_bridge.dart';",
  );
  final start = updated.indexOf(function);
  final end = updated.indexOf('}) async {', start);
  if (end == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely update buildHostMiniProgramConfig parameters.',
    );
  }
  if (!updated
      .substring(start, end)
      .contains('MiniProgramMediaPlaybackProvider? mediaPlaybackProvider')) {
    updated = updated.replaceRange(
      end,
      end,
      '  MiniProgramMediaPlaybackProvider? mediaPlaybackProvider,$newline',
    );
  }
  if (!updated.contains('final resolvedMediaPlaybackProvider =')) {
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
      '  final resolvedMediaPlaybackProvider =$newline'
      '      mediaPlaybackProvider ??$newline'
      '      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android$newline'
      '          ? const AppAndroidMediaPlaybackProvider()$newline'
      '          : null);$newline$newline',
    );
  }
  final direct = RegExp(r'mediaPlaybackProvider:\s*mediaPlaybackProvider,');
  if (direct.hasMatch(updated)) {
    return updated.replaceFirst(
      direct,
      'mediaPlaybackProvider: resolvedMediaPlaybackProvider,',
    );
  }
  if (updated.contains(
    'mediaPlaybackProvider: resolvedMediaPlaybackProvider,',
  )) {
    return updated;
  }
  final callStart = updated.indexOf('  return buildMiniProgramConfig(', start);
  final callEnd = updated.indexOf('  );', callStart);
  if (callStart == -1 || callEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely wire the media playback provider.',
    );
  }
  return updated.replaceRange(
    callEnd,
    callEnd,
    '    mediaPlaybackProvider: resolvedMediaPlaybackProvider,$newline',
  );
}

String patchMediaPlaybackRuntimeSetup(String source) {
  const function = 'MiniProgramConfig buildMiniProgramConfig({';
  if (!source.contains(function)) {
    throw const MiniProgramHostCapabilityException(
      'mini_program_runtime_setup.dart does not contain buildMiniProgramConfig.',
    );
  }
  final newline = _newlineFor(source);
  var updated = source;
  final start = updated.indexOf(function);
  final end = updated.indexOf('}) {', start);
  if (end == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely update buildMiniProgramConfig parameters.',
    );
  }
  if (!updated
      .substring(start, end)
      .contains('MiniProgramMediaPlaybackProvider? mediaPlaybackProvider')) {
    updated = updated.replaceRange(
      end,
      end,
      '  MiniProgramMediaPlaybackProvider? mediaPlaybackProvider,$newline',
    );
  }
  const capabilitiesMarker = '  final supportedCapabilities = <CapabilityId>{';
  final capabilitiesStart = updated.indexOf(capabilitiesMarker, start);
  final capabilitiesEnd = updated.indexOf('  };', capabilitiesStart);
  if (capabilitiesStart == -1 || capabilitiesEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely locate the generated capability registry.',
    );
  }
  for (final capability in const <String>['mediaAudio', 'mediaVideo']) {
    if (!updated
        .substring(capabilitiesStart, capabilitiesEnd)
        .contains('CapabilityIds.$capability')) {
      updated = updated.replaceRange(
        capabilitiesEnd,
        capabilitiesEnd,
        '    if (mediaPlaybackProvider != null) '
        'CapabilityIds.$capability,$newline',
      );
    }
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
      .contains('mediaPlaybackProvider: mediaPlaybackProvider,')) {
    updated = updated.replaceRange(
      configEnd,
      configEnd,
      '    mediaPlaybackProvider: mediaPlaybackProvider,$newline',
    );
  }
  return updated;
}

String patchMediaPlaybackMainActivity(String source) =>
    patchAndroidMainActivityRegistration(
      source,
      registration: 'MiniProgramMediaPlaybackPlugin.register(flutterEngine)',
    );

String patchMediaPlaybackGradle(String source, {required bool kotlinDsl}) {
  return patchAndroidCapabilityDependencies(
    source,
    capability: androidMediaPlaybackDependencyCapability,
    kotlinDsl: kotlinDsl,
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
  if (before != null && source.contains(before)) {
    final index = source.indexOf(before);
    return source.replaceRange(index, index, '$statement$newline');
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
