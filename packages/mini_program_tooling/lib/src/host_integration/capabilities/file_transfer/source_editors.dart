import '../models.dart';

String patchFileTransferHostSetup(String source) {
  if (!source.contains(
    'Future<MiniProgramConfig> buildHostMiniProgramConfig(',
  )) {
    throw const MiniProgramHostCapabilityException(
      'mini_program_host_setup.dart does not contain '
      'buildHostMiniProgramConfig. Run or repair embed initialization first.',
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
    "import 'app_android_file_transfer_provider.dart';",
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
  if (!signature.contains(
    'MiniProgramFileTransferProvider? fileTransferProvider',
  )) {
    updated = updated.replaceRange(
      signatureEnd,
      signatureEnd,
      '  MiniProgramFileTransferProvider? fileTransferProvider,$newline',
    );
  }

  if (!updated.contains('final resolvedFileTransferProvider =')) {
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
        '  final resolvedFileTransferProvider =$newline'
        '      fileTransferProvider ??$newline'
        '      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android$newline'
        '          ? AppAndroidFileTransferProvider()$newline'
        '          : null);$newline';
    updated = updated.replaceRange(
      returnIndex,
      returnIndex,
      '$resolution$newline',
    );
  }

  final directProviderPattern = RegExp(
    r'fileTransferProvider:\s*fileTransferProvider,',
  );
  if (directProviderPattern.hasMatch(updated)) {
    updated = updated.replaceFirst(
      directProviderPattern,
      'fileTransferProvider: resolvedFileTransferProvider,',
    );
  } else if (!updated.contains(
    'fileTransferProvider: resolvedFileTransferProvider,',
  )) {
    final callStart = updated.indexOf(
      '  return buildMiniProgramConfig(',
      signatureStart,
    );
    final callEnd = updated.indexOf('  );', callStart);
    if (callStart == -1 || callEnd == -1) {
      throw const MiniProgramHostCapabilityException(
        'Could not safely wire the file transfer provider into '
        'buildMiniProgramConfig.',
      );
    }
    updated = updated.replaceRange(
      callEnd,
      callEnd,
      '    fileTransferProvider: resolvedFileTransferProvider,$newline',
    );
  }
  return updated;
}

String patchFileTransferMainActivity(String source) {
  if (source.contains('MiniProgramFileTransferChannel.register')) {
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
      'for automatic file capability installation.',
    );
  }
  final classTail = updated.substring(classMatch.end);
  final firstContentIndex = classTail.indexOf(RegExp(r'\S'));
  if (firstContentIndex == -1) {
    final replacement =
        'class MainActivity : FlutterActivity() {$newline'
        '    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {$newline'
        '        super.configureFlutterEngine(flutterEngine)$newline'
        '        MiniProgramFileTransferChannel.register(flutterEngine)$newline'
        '    }$newline'
        '}';
    return updated.replaceRange(classMatch.start, updated.length, replacement);
  }
  if (classTail[firstContentIndex] != '{') {
    throw const MiniProgramHostCapabilityException(
      'MainActivity.kt uses an unsupported custom class declaration. Add '
      '`MiniProgramFileTransferChannel.register(flutterEngine)` manually.',
    );
  }
  if (updated.contains('override fun configureFlutterEngine(')) {
    const superCall = 'super.configureFlutterEngine(flutterEngine)';
    final superIndex = updated.indexOf(superCall, classMatch.end);
    if (superIndex == -1) {
      throw const MiniProgramHostCapabilityException(
        'MainActivity.configureFlutterEngine must call '
        'super.configureFlutterEngine(flutterEngine).',
      );
    }
    final insertAt = superIndex + superCall.length;
    return updated.replaceRange(
      insertAt,
      insertAt,
      '$newline        MiniProgramFileTransferChannel.register(flutterEngine)',
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
      '        MiniProgramFileTransferChannel.register(flutterEngine)$newline'
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
    final index = source.indexOf(before);
    if (index != -1) {
      return source.replaceRange(index, index, '$statement$newline');
    }
  }
  if (fallbackAfter != null) {
    final index = source.indexOf(fallbackAfter);
    if (index != -1) {
      final insertAt = index + fallbackAfter.length;
      return source.replaceRange(insertAt, insertAt, '$newline$statement');
    }
  }
  final matches = RegExp(
    r'^import .+?;?\s*$',
    multiLine: true,
  ).allMatches(source);
  if (matches.isEmpty) {
    throw MiniProgramHostCapabilityException(
      'Could not safely add `$statement`; no import block was found.',
    );
  }
  final last = matches.last;
  return source.replaceRange(last.end, last.end, '$newline$statement');
}

String _newlineFor(String source) => source.contains('\r\n') ? '\r\n' : '\n';
