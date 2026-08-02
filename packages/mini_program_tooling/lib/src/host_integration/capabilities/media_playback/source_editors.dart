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

String patchMediaPlaybackMainActivity(String source) => _patchMainActivity(
  source,
  'MiniProgramMediaPlaybackPlugin.register(flutterEngine)',
);

String patchMediaPlaybackGradle(String source, {required bool kotlinDsl}) {
  if (source.contains('mini-program-media-playback-capability')) return source;
  final quote = kotlinDsl ? '"' : "'";
  final callStart = kotlinDsl ? 'implementation(' : 'implementation ';
  final callEnd = kotlinDsl ? ')' : '';
  return '$source\n// mini-program-media-playback-capability\ndependencies {\n'
      '    $callStart${quote}androidx.media3:media3-exoplayer:1.5.1$quote$callEnd\n'
      '    $callStart${quote}androidx.media3:media3-exoplayer-hls:1.5.1$quote$callEnd\n'
      '    $callStart${quote}androidx.media3:media3-ui:1.5.1$quote$callEnd\n'
      '    $callStart${quote}androidx.media3:media3-datasource:1.5.1$quote$callEnd\n'
      '    $callStart${quote}androidx.media3:media3-database:1.5.1$quote$callEnd\n'
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
