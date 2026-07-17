import '../models.dart';

String patchLocationHostSetup(String source) {
  if (!source.contains(
    'Future<MiniProgramConfig> buildHostMiniProgramConfig(',
  )) {
    throw const MiniProgramHostCapabilityException(
      'mini_program_host_setup.dart does not contain the generated '
      'buildHostMiniProgramConfig function. Reconcile the host-owned setup '
      'before installing location support.',
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
    "import 'app_android_location_provider.dart';",
    before: "import 'app_host_bridge.dart';",
  );

  final signatureStart = updated.indexOf(
    'Future<MiniProgramConfig> buildHostMiniProgramConfig(',
  );
  final signatureEnd = updated.indexOf('}) async {', signatureStart);
  if (signatureEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely update buildHostMiniProgramConfig parameters.',
    );
  }
  final signature = updated.substring(signatureStart, signatureEnd);
  if (!signature.contains('MiniProgramLocationProvider? locationProvider')) {
    updated = updated.replaceRange(
      signatureEnd,
      signatureEnd,
      '  MiniProgramLocationProvider? locationProvider,$newline',
    );
  }

  if (!updated.contains('final resolvedLocationProvider =')) {
    final returnIndex = updated.indexOf(
      '  return buildMiniProgramConfig(',
      signatureStart,
    );
    if (returnIndex == -1) {
      throw const MiniProgramHostCapabilityException(
        'Could not safely locate buildMiniProgramConfig in the host setup.',
      );
    }
    final resolution =
        '  final resolvedLocationProvider =$newline'
        '      locationProvider ??$newline'
        '      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android$newline'
        '          ? const AppAndroidLocationProvider()$newline'
        '          : null);$newline';
    updated = updated.replaceRange(
      returnIndex,
      returnIndex,
      '$resolution$newline',
    );
  }

  final directProviderPattern = RegExp(
    r'locationProvider:\s*locationProvider,',
  );
  if (directProviderPattern.hasMatch(updated)) {
    updated = updated.replaceFirst(
      directProviderPattern,
      'locationProvider: resolvedLocationProvider,',
    );
  } else if (!updated.contains('locationProvider: resolvedLocationProvider,')) {
    final callStart = updated.indexOf(
      '  return buildMiniProgramConfig(',
      signatureStart,
    );
    final callEnd = updated.indexOf('  );', callStart);
    if (callStart == -1 || callEnd == -1) {
      throw const MiniProgramHostCapabilityException(
        'Could not safely wire the location provider into '
        'buildMiniProgramConfig.',
      );
    }
    updated = updated.replaceRange(
      callEnd,
      callEnd,
      '    locationProvider: resolvedLocationProvider,$newline',
    );
  }
  return updated;
}

String patchLocationAndroidManifest(String source) {
  const permission = 'android.permission.ACCESS_COARSE_LOCATION';
  if (source.contains(permission)) {
    return source;
  }
  final newline = _newlineFor(source);
  const declaration =
      '    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>';
  final internetPattern = RegExp(
    r'^[ \t]*<uses-permission\s+android:name="android\.permission\.INTERNET"\s*/>[ \t]*$',
    multiLine: true,
  );
  final internetMatch = internetPattern.firstMatch(source);
  if (internetMatch != null) {
    return source.replaceRange(
      internetMatch.end,
      internetMatch.end,
      '$newline$declaration',
    );
  }
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

String patchLocationMainActivity(String source) {
  if (source.contains('MiniProgramLocationChannel.register')) {
    return source;
  }
  final newline = _newlineFor(source);
  var updated = _ensureImport(
    source,
    'import io.flutter.embedding.engine.FlutterEngine',
    before: 'import io.flutter.plugin',
    fallbackAfter: 'import io.flutter.embedding.android.FlutterActivity',
  );

  final classMatch = RegExp(
    r'class\s+MainActivity\s*:\s*FlutterActivity\(\)',
  ).firstMatch(updated);
  if (classMatch == null) {
    throw const MiniProgramHostCapabilityException(
      'MainActivity.kt must define `class MainActivity : FlutterActivity()` '
      'for automatic location capability installation.',
    );
  }
  final classTail = updated.substring(classMatch.end);
  final firstContentIndex = classTail.indexOf(RegExp(r'\S'));
  if (firstContentIndex == -1) {
    final replacement =
        'class MainActivity : FlutterActivity() {$newline'
        '    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {$newline'
        '        super.configureFlutterEngine(flutterEngine)$newline'
        '        MiniProgramLocationChannel.register(flutterEngine)$newline'
        '    }$newline'
        '}';
    return updated.replaceRange(classMatch.start, updated.length, replacement);
  }
  if (classTail[firstContentIndex] != '{') {
    throw const MiniProgramHostCapabilityException(
      'MainActivity.kt uses an unsupported custom class declaration. Add '
      '`MiniProgramLocationChannel.register(flutterEngine)` manually.',
    );
  }

  if (updated.contains('override fun configureFlutterEngine(')) {
    const superCall = 'super.configureFlutterEngine(flutterEngine)';
    final superIndex = updated.indexOf(superCall, classMatch.end);
    if (superIndex == -1) {
      throw const MiniProgramHostCapabilityException(
        'MainActivity.configureFlutterEngine must call '
        'super.configureFlutterEngine(flutterEngine) before the location '
        'channel can be installed automatically.',
      );
    }
    final insertAt = superIndex + superCall.length;
    return updated.replaceRange(
      insertAt,
      insertAt,
      '$newline        MiniProgramLocationChannel.register(flutterEngine)',
    );
  }

  final classEnd = updated.lastIndexOf('}');
  if (classEnd == -1 || classEnd < classMatch.end) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely locate the end of MainActivity.kt.',
    );
  }
  final method =
      '    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {$newline'
      '        super.configureFlutterEngine(flutterEngine)$newline'
      '        MiniProgramLocationChannel.register(flutterEngine)$newline'
      '    }$newline';
  return updated.replaceRange(classEnd, classEnd, '$method$newline');
}

String _ensureImport(
  String source,
  String statement, {
  String? before,
  String? fallbackAfter,
}) {
  if (source.contains(statement)) {
    return source;
  }
  final newline = _newlineFor(source);
  if (before != null) {
    final beforeIndex = source.indexOf(before);
    if (beforeIndex != -1) {
      return source.replaceRange(
        beforeIndex,
        beforeIndex,
        '$statement$newline',
      );
    }
  }
  if (fallbackAfter != null) {
    final afterIndex = source.indexOf(fallbackAfter);
    if (afterIndex != -1) {
      final insertAt = afterIndex + fallbackAfter.length;
      return source.replaceRange(insertAt, insertAt, '$newline$statement');
    }
  }
  final lastImport = RegExp(
    r'^import .+?;?\s*$',
    multiLine: true,
  ).allMatches(source).lastOrNull;
  if (lastImport == null) {
    throw MiniProgramHostCapabilityException(
      'Could not safely add `$statement` because the target file has no '
      'recognized imports.',
    );
  }
  return source.replaceRange(
    lastImport.end,
    lastImport.end,
    '$newline$statement',
  );
}

String _newlineFor(String source) => source.contains('\r\n') ? '\r\n' : '\n';
