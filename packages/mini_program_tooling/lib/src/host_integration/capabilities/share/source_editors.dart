import '../models.dart';

String patchShareHostSetup(String source) {
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
    "import 'app_android_share_provider.dart';",
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
      .contains('MiniProgramShareProvider? shareProvider')) {
    updated = updated.replaceRange(
      signatureEnd,
      signatureEnd,
      '  MiniProgramShareProvider? shareProvider,$newline',
    );
  }
  if (!updated.contains('final resolvedShareProvider =')) {
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
        '  final resolvedShareProvider =$newline'
        '      shareProvider ??$newline'
        '      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android$newline'
        '          ? const AppAndroidShareProvider()$newline'
        '          : null);$newline$newline';
    updated = updated.replaceRange(returnIndex, returnIndex, resolution);
  }
  final direct = RegExp(r'shareProvider:\s*shareProvider,');
  if (direct.hasMatch(updated)) {
    return updated.replaceFirst(
      direct,
      'shareProvider: resolvedShareProvider,',
    );
  }
  if (updated.contains('shareProvider: resolvedShareProvider,')) {
    return updated;
  }
  final callStart = updated.indexOf(
    '  return buildMiniProgramConfig(',
    signatureStart,
  );
  final callEnd = updated.indexOf('  );', callStart);
  if (callStart == -1 || callEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely wire the share provider.',
    );
  }
  return updated.replaceRange(
    callEnd,
    callEnd,
    '    shareProvider: resolvedShareProvider,$newline',
  );
}

String patchShareRuntimeSetup(String source) {
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
      .contains('MiniProgramShareProvider? shareProvider')) {
    updated = updated.replaceRange(
      signatureEnd,
      signatureEnd,
      '  MiniProgramShareProvider? shareProvider,$newline',
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
      .contains('CapabilityIds.systemShare')) {
    updated = updated.replaceRange(
      capabilitiesEnd,
      capabilitiesEnd,
      '    if (shareProvider != null) CapabilityIds.systemShare,$newline',
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
      .contains('shareProvider: shareProvider,')) {
    updated = updated.replaceRange(
      configEnd,
      configEnd,
      '    shareProvider: shareProvider,$newline',
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
