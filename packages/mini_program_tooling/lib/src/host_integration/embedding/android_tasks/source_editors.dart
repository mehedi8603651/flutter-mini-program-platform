import '../models.dart';

const _manifestStart = '<!-- <mini-program-android-tasks> -->';
const _manifestEnd = '<!-- </mini-program-android-tasks> -->';
const _importStart = '// <mini-program-task-import>';
const _importEnd = '// </mini-program-task-import>';
const _entryStart = '// <mini-program-task-entrypoint>';
const _entryEnd = '// </mini-program-task-entrypoint>';

String patchAndroidTaskManifest(String source, String packageName) {
  final newline = source.contains('\r\n') ? '\r\n' : '\n';
  _removeBlock(source, _manifestStart, _manifestEnd);
  const positionMarker = '<!-- mini-program-task-block-position -->';
  if (source.contains(positionMarker)) {
    throw const MiniProgramEmbeddingInitException(
      'Conflicting Android task block position marker.',
    );
  }
  final placeholder = '        $positionMarker$newline';
  var updated = source.replaceFirst(
    _blockPattern(_manifestStart, _manifestEnd),
    placeholder,
  );
  final activities = RegExp(
    r'<activity\b[^>]*(?:/>|>[\s\S]*?</activity\s*>)',
  ).allMatches(_maskXmlComments(updated));
  final hosts = activities.where((match) {
    final name = _attribute(match.group(0)!, 'name');
    return name == '.MainActivity' || name == '$packageName.MainActivity';
  }).toList();
  if (hosts.length != 1) {
    throw const MiniProgramEmbeddingInitException(
      'Android separate tasks require one manifest-declared Kotlin MainActivity.',
    );
  }
  if (RegExp(
    r'MiniProgramTaskActivity[0-4]\b',
  ).hasMatch(_maskXmlComments(updated))) {
    throw const MiniProgramEmbeddingInitException(
      'AndroidManifest.xml already declares mini-program task Activities outside '
      'the managed block. Reconcile them before retrying.',
    );
  }
  final host = hosts.single;
  final hostSource = updated.substring(host.start, host.end);
  final openEnd = hostSource.indexOf('>') + 1;
  var hostOpen = hostSource.substring(0, openEnd);
  final launchMode = _attribute(hostOpen, 'launchMode');
  if (launchMode != null &&
      !const {'standard', 'singleTop', 'singleTask'}.contains(launchMode)) {
    throw MiniProgramEmbeddingInitException(
      'MainActivity launchMode="$launchMode" is incompatible with automatic '
      'Android separate task setup. Use a standard, singleTop, or singleTask host.',
    );
  }
  hostOpen = _setAttribute(hostOpen, 'launchMode', 'singleTask', newline);
  if ((_attribute(hostOpen, 'taskAffinity') ?? '').isEmpty) {
    hostOpen = _setAttribute(
      hostOpen,
      'taskAffinity',
      r'${applicationId}.host',
      newline,
    );
  }
  updated = updated.replaceRange(
    host.start,
    host.end,
    '$hostOpen${hostSource.substring(openEnd)}',
  );
  final applicationEnds = RegExp(
    r'</application\s*>',
  ).allMatches(_maskXmlComments(updated)).toList();
  if (applicationEnds.length != 1) {
    throw const MiniProgramEmbeddingInitException(
      'AndroidManifest.xml must contain one non-empty application element.',
    );
  }
  final block = <String>[
    '        $_manifestStart',
    for (var slot = 0; slot < 5; slot++) ...[
      '        <activity',
      '            android:name="$packageName.MiniProgramTaskActivity$slot"',
      '            android:taskAffinity="\${applicationId}.mini_program_task_$slot"',
      '            android:exported="false"',
      '            android:launchMode="singleTask"',
      '            android:alwaysRetainTaskState="true"',
      '            android:autoRemoveFromRecents="false"',
      '            android:excludeFromRecents="false"',
      '            android:resizeableActivity="true"',
      '            android:theme="@style/NormalTheme"',
      '            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"',
      '            android:hardwareAccelerated="true"',
      '            android:windowSoftInputMode="adjustResize" />',
    ],
    '        $_manifestEnd',
    '',
  ].join(newline);
  if (updated.contains(placeholder)) {
    return updated.replaceFirst(placeholder, block);
  }
  final end = applicationEnds.single.start;
  final lineStart = updated.lastIndexOf('\n', end) + 1;
  final insertion = updated.substring(lineStart, end).trim().isEmpty
      ? lineStart
      : end;
  return updated.replaceRange(insertion, insertion, block);
}

String patchAndroidTaskDartEntrypoint(String source) {
  final newline = source.contains('\r\n') ? '\r\n' : '\n';
  final import = <String>[
    _importStart,
    "import 'mini_program/app_android_task_setup.dart' as mini_program_task_setup;",
    _importEnd,
  ].join(newline);
  final entry = <String>[
    _entryStart,
    "@pragma('vm:entry-point')",
    'Future<void> miniProgramTaskMain() =>',
    '    mini_program_task_setup.runHostMiniProgramTask();',
    _entryEnd,
  ].join(newline);
  // Reject partial or edited blocks instead of adding a second entrypoint.
  _removeBlock(source, _importStart, _importEnd);
  _removeBlock(source, _entryStart, _entryEnd);
  if (source.contains(_importStart) || source.contains(_entryStart)) {
    final compact = source.replaceAll(RegExp(r'\s+'), '');
    if (!compact.contains(import.replaceAll(RegExp(r'\s+'), '')) ||
        !compact.contains(entry.replaceAll(RegExp(r'\s+'), ''))) {
      throw const MiniProgramEmbeddingInitException(
        'lib/main.dart contains an incomplete or edited Android task entrypoint. '
        'Reconcile its managed blocks before retrying.',
      );
    }
    return source;
  }
  if (RegExp(r'^\s*part\s+of\b', multiLine: true).hasMatch(source) ||
      source.contains('miniProgramTaskMain') ||
      source.contains('mini_program_task_setup')) {
    throw const MiniProgramEmbeddingInitException(
      'lib/main.dart cannot safely receive the Android task entrypoint. '
      'It must be a root library without conflicting task entrypoint names.',
    );
  }
  final library = RegExp(
    r'^\s*library\b[^;]*;',
    multiLine: true,
  ).firstMatch(source);
  final insertAt =
      library?.end ?? (source.startsWith('#!') ? source.indexOf('\n') + 1 : 0);
  return '${source.substring(0, insertAt)}'
      '${insertAt == 0 ? '' : '$newline$newline'}$import$newline'
      '${source.substring(insertAt)}'
      '${source.endsWith('\n') ? '' : newline}$newline$entry$newline';
}

String _maskXmlComments(String source) => source.replaceAllMapped(
  RegExp(r'<!--[\s\S]*?-->'),
  (match) => match.group(0)!.replaceAll(RegExp(r'[^\r\n]'), ' '),
);

String? _attribute(String source, String name) => RegExp(
  'android:$name\\s*=\\s*["\x27]([^"\x27]*)["\x27]',
).firstMatch(source)?.group(1);

String _setAttribute(String source, String name, String value, String newline) {
  final pattern = RegExp('android:$name\\s*=\\s*["\x27][^"\x27]*["\x27]');
  if (pattern.hasMatch(source)) {
    return source.replaceFirst(pattern, 'android:$name="$value"');
  }
  final end = source.endsWith('/>') ? source.length - 2 : source.length - 1;
  return source.replaceRange(
    end,
    end,
    '$newline            android:$name="$value"',
  );
}

String _removeBlock(String source, String start, String end) {
  final starts = start.allMatches(source).length;
  final ends = end.allMatches(source).length;
  if (starts != ends ||
      starts > 1 ||
      (starts == 1 && source.indexOf(end) < source.indexOf(start))) {
    throw MiniProgramEmbeddingInitException(
      'Malformed managed Android task block ($start). Reconcile it before retrying.',
    );
  }
  return source.replaceFirst(_blockPattern(start, end), '');
}

RegExp _blockPattern(String start, String end) => RegExp(
  '^[ \\t]*${RegExp.escape(start)}[\\s\\S]*?${RegExp.escape(end)}[ \\t]*(?:\\r?\\n)?',
  multiLine: true,
);
