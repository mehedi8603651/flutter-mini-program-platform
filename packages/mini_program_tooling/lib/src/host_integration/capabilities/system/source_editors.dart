import '../models.dart';

String patchSystemHostSetup(String source, String feature) {
  final title = '${feature[0].toUpperCase()}${feature.substring(1)}';
  final newline = source.contains('\r\n') ? '\r\n' : '\n';
  var next = source;
  for (final statement in [
    "import 'package:flutter/foundation.dart';",
    "import 'app_android_${feature}_provider.dart';",
  ]) {
    if (!next.contains(statement)) {
      final index = next.indexOf('import ');
      if (index < 0) {
        throw const MiniProgramHostCapabilityException(
          'Host setup has no import block.',
        );
      }
      next = next.replaceRange(index, index, '$statement$newline');
    }
  }
  final start = next.indexOf(
    'Future<MiniProgramConfig> buildHostMiniProgramConfig(',
  );
  final end = start < 0 ? -1 : next.indexOf('}) async {', start);
  if (end < 0) {
    throw const MiniProgramHostCapabilityException(
      'Could not locate the host config signature.',
    );
  }
  if (!next
      .substring(start, end)
      .contains('MiniProgram${title}Provider? ${feature}Provider')) {
    next = next.replaceRange(
      end,
      end,
      '  MiniProgram${title}Provider? ${feature}Provider,$newline',
    );
  }
  final resolved = 'resolved${title}Provider';
  if (!next.contains('final $resolved =')) {
    final call = next.indexOf('  return buildMiniProgramConfig(', start);
    if (call < 0) {
      throw const MiniProgramHostCapabilityException(
        'Could not locate the runtime config call.',
      );
    }
    next = next.replaceRange(
      call,
      call,
      '  final $resolved = ${feature}Provider ??$newline'
      '      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android$newline'
      '          ? const AppAndroid${title}Provider() : null);$newline',
    );
  }
  final direct = RegExp('${feature}Provider:\\s*${feature}Provider,');
  if (direct.hasMatch(next)) {
    return next.replaceFirst(direct, '${feature}Provider: $resolved,');
  }
  if (!next.contains('${feature}Provider: $resolved,')) {
    final call = next.indexOf('  return buildMiniProgramConfig(', start);
    final close = call < 0 ? -1 : next.indexOf('  );', call);
    if (close < 0) {
      throw const MiniProgramHostCapabilityException(
        'Could not wire the host provider safely.',
      );
    }
    next = next.replaceRange(
      close,
      close,
      '    ${feature}Provider: $resolved,$newline',
    );
  }
  return next;
}

String patchSystemRuntimeSetup(String source, String feature) {
  final title = '${feature[0].toUpperCase()}${feature.substring(1)}';
  final newline = source.contains('\r\n') ? '\r\n' : '\n';
  var next = source;
  final start = next.indexOf('MiniProgramConfig buildMiniProgramConfig({');
  final end = start < 0 ? -1 : next.indexOf('}) {', start);
  if (end < 0) {
    throw const MiniProgramHostCapabilityException(
      'Could not locate the runtime config signature.',
    );
  }
  if (!next
      .substring(start, end)
      .contains('MiniProgram${title}Provider? ${feature}Provider')) {
    next = next.replaceRange(
      end,
      end,
      '  MiniProgram${title}Provider? ${feature}Provider,$newline',
    );
  }
  final capStart = next.indexOf(
    '  final supportedCapabilities = <CapabilityId>{',
    start,
  );
  var capEnd = capStart < 0 ? -1 : next.indexOf('  };', capStart);
  if (capEnd < 0) {
    throw const MiniProgramHostCapabilityException(
      'Could not locate the capability registry.',
    );
  }
  for (final capability in switch (feature) {
    'clipboard' => ['clipboardRead', 'clipboardWrite'],
    'vibration' => ['vibration'],
    'phone' => ['phoneDialer'],
    'maps' => ['mapsOpenLocation', 'mapsOpenDirections'],
    'bluetooth' => ['bluetoothBle'],
    'nfc' => ['nfcRead'],
    _ => throw ArgumentError.value(feature),
  }) {
    if (!next
        .substring(capStart, capEnd)
        .contains('CapabilityIds.$capability')) {
      final line =
          '    if (${feature}Provider != null) CapabilityIds.$capability,$newline';
      next = next.replaceRange(capEnd, capEnd, line);
      capEnd += line.length;
    }
  }
  final call = next.indexOf('  return MiniProgramConfig(', capEnd);
  final close = call < 0 ? -1 : next.indexOf('  );', call);
  if (close < 0) {
    throw const MiniProgramHostCapabilityException(
      'Could not locate MiniProgramConfig.',
    );
  }
  if (!next
      .substring(call, close)
      .contains('${feature}Provider: ${feature}Provider,')) {
    next = next.replaceRange(
      close,
      close,
      '    ${feature}Provider: ${feature}Provider,$newline',
    );
  }
  return next;
}
