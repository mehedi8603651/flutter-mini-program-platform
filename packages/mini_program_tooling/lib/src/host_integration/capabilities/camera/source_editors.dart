import '../android/main_activity_editor.dart';
import '../models.dart';

String patchCameraHostSetup(String source) {
  const function = 'Future<MiniProgramConfig> buildHostMiniProgramConfig(';
  if (!source.contains(function)) {
    throw const MiniProgramHostCapabilityException(
      'mini_program_host_setup.dart does not contain '
      'buildHostMiniProgramConfig.',
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
    "import 'app_android_camera_provider.dart';",
    before: "import 'app_host_bridge.dart';",
  );
  final signatureStart = updated.indexOf(function);
  final signatureEnd = updated.indexOf('}) async {', signatureStart);
  if (signatureEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely update buildHostMiniProgramConfig parameters.',
    );
  }
  final signature = updated.substring(signatureStart, signatureEnd);
  if (!signature.contains('MiniProgramCameraProvider? cameraProvider')) {
    updated = updated.replaceRange(
      signatureEnd,
      signatureEnd,
      '  MiniProgramCameraProvider? cameraProvider,$newline',
    );
  }
  final mediaSignatureEnd = updated.indexOf('}) async {', signatureStart);
  final mediaSignature = updated.substring(signatureStart, mediaSignatureEnd);
  if (!mediaSignature.contains('MiniProgramMediaProvider? mediaProvider')) {
    updated = updated.replaceRange(
      mediaSignatureEnd,
      mediaSignatureEnd,
      '  MiniProgramMediaProvider? mediaProvider,$newline',
    );
  }
  if (!updated.contains('final resolvedCameraProvider =')) {
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
        '  final resolvedCameraProvider =$newline'
        '      cameraProvider ??$newline'
        '      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android$newline'
        '          ? const AppAndroidCameraProvider()$newline'
        '          : null);$newline$newline';
    updated = updated.replaceRange(returnIndex, returnIndex, resolution);
  }
  if (!updated.contains('resolvedMediaProvider =')) {
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
        '  final MiniProgramMediaProvider? resolvedMediaProvider =$newline'
        '      mediaProvider ??$newline'
        '      (resolvedCameraProvider is MiniProgramMediaProvider$newline'
        '          ? resolvedCameraProvider as MiniProgramMediaProvider$newline'
        '          : null);$newline$newline';
    updated = updated.replaceRange(returnIndex, returnIndex, resolution);
  }
  updated = _wireProvider(
    updated,
    functionStart: signatureStart,
    argumentName: 'cameraProvider',
    resolvedName: 'resolvedCameraProvider',
    newline: newline,
  );
  updated = _wireProvider(
    updated,
    functionStart: signatureStart,
    argumentName: 'mediaProvider',
    resolvedName: 'resolvedMediaProvider',
    newline: newline,
  );
  return updated;
}

String patchCameraAndroidManifest(String source) {
  if (source.contains('.mini_program_camera_files')) return source;
  final newline = _newlineFor(source);
  final applicationEnd = source.lastIndexOf('</application>');
  if (applicationEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'AndroidManifest.xml does not contain an <application> element.',
    );
  }
  final declaration =
      '        <provider$newline'
      '            android:name="androidx.core.content.FileProvider"$newline'
      r'            android:authorities="${applicationId}.mini_program_camera_files"'
      '$newline'
      '            android:exported="false"$newline'
      '            android:grantUriPermissions="true">$newline'
      '            <meta-data$newline'
      '                android:name="android.support.FILE_PROVIDER_PATHS"$newline'
      '                android:resource="@xml/mini_program_camera_paths" />$newline'
      '        </provider>$newline';
  return source.replaceRange(applicationEnd, applicationEnd, declaration);
}

String patchCameraMainActivity(String source) =>
    patchAndroidMainActivityRegistration(
      source,
      registration: 'MiniProgramCameraChannel.register(flutterEngine)',
      requiresFragmentActivity: true,
    );

String _wireProvider(
  String source, {
  required int functionStart,
  required String argumentName,
  required String resolvedName,
  required String newline,
}) {
  final direct = RegExp('$argumentName:\\s*$argumentName,');
  if (direct.hasMatch(source)) {
    return source.replaceFirst(direct, '$argumentName: $resolvedName,');
  }
  if (source.contains('$argumentName: $resolvedName,')) return source;
  final callStart = source.indexOf(
    '  return buildMiniProgramConfig(',
    functionStart,
  );
  final callEnd = source.indexOf('  );', callStart);
  if (callStart == -1 || callEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely wire the camera provider.',
    );
  }
  return source.replaceRange(
    callEnd,
    callEnd,
    '    $argumentName: $resolvedName,$newline',
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
