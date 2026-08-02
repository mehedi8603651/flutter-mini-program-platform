import '../android/main_activity_editor.dart';
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

String patchFileTransferMainActivity(String source) =>
    patchAndroidMainActivityRegistration(
      source,
      registration: 'MiniProgramFileTransferChannel.register(flutterEngine)',
    );

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
