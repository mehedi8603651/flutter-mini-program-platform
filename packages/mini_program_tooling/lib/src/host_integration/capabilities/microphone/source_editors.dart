import '../models.dart';

String patchMicrophoneHostSetup(String source) {
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
    "import 'app_android_microphone_provider.dart';",
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
      .contains('MiniProgramMicrophoneProvider? microphoneProvider')) {
    updated = updated.replaceRange(
      signatureEnd,
      signatureEnd,
      '  MiniProgramMicrophoneProvider? microphoneProvider,$newline',
    );
  }
  if (!updated.contains('final resolvedMicrophoneProvider =')) {
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
        '  final resolvedMicrophoneProvider =$newline'
        '      microphoneProvider ??$newline'
        '      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android$newline'
        '          ? const AppAndroidMicrophoneProvider()$newline'
        '          : null);$newline$newline';
    updated = updated.replaceRange(returnIndex, returnIndex, resolution);
  }
  final direct = RegExp(r'microphoneProvider:\s*microphoneProvider,');
  if (direct.hasMatch(updated)) {
    return updated.replaceFirst(
      direct,
      'microphoneProvider: resolvedMicrophoneProvider,',
    );
  }
  if (updated.contains('microphoneProvider: resolvedMicrophoneProvider,')) {
    return updated;
  }
  final callStart = updated.indexOf(
    '  return buildMiniProgramConfig(',
    signatureStart,
  );
  final callEnd = updated.indexOf('  );', callStart);
  if (callStart == -1 || callEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely wire the microphone provider.',
    );
  }
  return updated.replaceRange(
    callEnd,
    callEnd,
    '    microphoneProvider: resolvedMicrophoneProvider,$newline',
  );
}

String patchMicrophoneRuntimeSetup(String source) {
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
      .contains('MiniProgramMicrophoneProvider? microphoneProvider')) {
    updated = updated.replaceRange(
      signatureEnd,
      signatureEnd,
      '  MiniProgramMicrophoneProvider? microphoneProvider,$newline',
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
      .contains('CapabilityIds.microphoneRecord')) {
    updated = updated.replaceRange(
      capabilitiesEnd,
      capabilitiesEnd,
      '    if (microphoneProvider != null) CapabilityIds.microphoneRecord,$newline',
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
      .contains('microphoneProvider: microphoneProvider,')) {
    updated = updated.replaceRange(
      configEnd,
      configEnd,
      '    microphoneProvider: microphoneProvider,$newline',
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

String patchMicrophoneAndroidManifest(
  String source, {
  required String packageName,
}) {
  final providerName = '$packageName.MiniProgramMicrophoneFileProvider';
  const permission = 'android.permission.RECORD_AUDIO';
  final declared = RegExp(r'<uses-permission\b[^>]*>', dotAll: true)
      .allMatches(source)
      .where((match) => match.group(0)!.contains(permission))
      .toList();
  if (declared.length > 1 ||
      declared.any(
        (match) =>
            match.group(0)!.contains('maxSdkVersion') ||
            match.group(0)!.contains('usesPermissionFlags'),
      )) {
    throw const MiniProgramHostCapabilityException(
      'Reconcile the host-owned RECORD_AUDIO permission before installing microphone recording.',
    );
  }
  if (declared.isEmpty) {
    final application = source.indexOf('<application');
    if (application < 0) {
      throw const MiniProgramHostCapabilityException(
        'AndroidManifest.xml has no application element.',
      );
    }
    final newline = _newlineFor(source);
    source = source.replaceRange(
      application,
      application,
      '<uses-permission android:name="android.permission.RECORD_AUDIO" />$newline    ',
    );
  }
  if (!RegExp(
    r'<uses-feature\b[^>]*android\.hardware\.microphone[^>]*>',
  ).hasMatch(source)) {
    final application = source.indexOf('<application');
    if (application < 0) {
      throw const MiniProgramHostCapabilityException(
        'AndroidManifest.xml has no application element.',
      );
    }
    source = source.replaceRange(
      application,
      application,
      '<uses-feature android:name="android.hardware.microphone" android:required="false" />${_newlineFor(source)}    ',
    );
  }

  if (source.contains(r'${applicationId}.mini_program_microphone_files')) {
    final providers = RegExp(r'<provider\b[^>]*>.*?</provider>', dotAll: true)
        .allMatches(source)
        .where(
          (match) => match
              .group(0)!
              .contains(r'${applicationId}.mini_program_microphone_files'),
        )
        .toList();
    if (providers.length != 1 ||
        ![
          'android:name="androidx.core.content.FileProvider"',
          'android:name="$providerName"',
        ].any(
          (attribute) => providers.single
              .group(0)!
              .replaceAll("'", '"')
              .contains(attribute),
        ) ||
        ![
          'android:exported="false"',
          'android:grantUriPermissions="true"',
          'android:resource="@xml/mini_program_microphone_paths"',
        ].every(
          (attribute) => providers.single
              .group(0)!
              .replaceAll("'", '"')
              .contains(attribute),
        )) {
      throw const MiniProgramHostCapabilityException(
        'The existing microphone FileProvider must be private and use mini_program_microphone_paths.',
      );
    }
    final provider = providers.single;
    final migrated = provider
        .group(0)!
        .replaceFirst(
          RegExp(
            r'''android:name=(["'])androidx\.core\.content\.FileProvider\1''',
          ),
          'android:name="$providerName"',
        );
    return source.replaceRange(provider.start, provider.end, migrated);
  }
  final closing = source.indexOf('</application>');
  if (closing < 0) {
    throw const MiniProgramHostCapabilityException(
      'AndroidManifest.xml has no application element.',
    );
  }
  final newline = _newlineFor(source);
  final provider =
      r'''    <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.mini_program_microphone_files"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/mini_program_microphone_paths" />
        </provider>
    '''
          .replaceFirst('androidx.core.content.FileProvider', providerName)
          .replaceAll('\n', newline);
  return source.replaceRange(closing, closing, provider);
}

const String androidMicrophonePathsSource =
    '''<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <cache-path name="mini_program_microphone" path="mini_program_microphone/" />
</paths>
''';
