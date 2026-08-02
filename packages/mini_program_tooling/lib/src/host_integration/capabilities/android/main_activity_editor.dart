import '../models.dart';

const String androidCapabilityRegistrationStart =
    '// <mini-program-native-capabilities>';
const String androidCapabilityRegistrationEnd =
    '// </mini-program-native-capabilities>';
const String androidNativeSetupRegistration =
    'MiniProgramNativeSetup.register(flutterEngine)';

const List<String> androidCapabilityRegistrations = <String>[
  'MiniProgramLocationChannel.register(flutterEngine)',
  'MiniProgramFileTransferChannel.register(flutterEngine)',
  'MiniProgramCameraChannel.register(flutterEngine)',
  'MiniProgramFlashlightChannel.register(flutterEngine)',
  'MiniProgramQrScannerChannel.register(flutterEngine)',
  'MiniProgramMediaPlaybackPlugin.register(flutterEngine)',
];

String patchAndroidMainActivityRegistration(
  String source, {
  required String registration,
  bool requiresFragmentActivity = false,
}) {
  if (!androidCapabilityRegistrations.contains(registration)) {
    throw MiniProgramHostCapabilityException(
      'Unsupported generated Android registration `$registration`.',
    );
  }
  _validateManagedBlock(source);
  final newline = source.contains('\r\n') ? '\r\n' : '\n';
  final registrations = readAndroidMainActivityRegistrations(source)
    ..add(registration);

  var updated = _removeManagedBlock(source);
  for (final candidate in androidCapabilityRegistrations) {
    updated = updated.replaceAll(
      RegExp(
        '^[ \\t]*${RegExp.escape(candidate)}[ \\t]*(?:\\r?\\n)?',
        multiLine: true,
      ),
      '',
    );
  }
  updated = updated.replaceAll(
    RegExp(
      '^[ \\t]*${RegExp.escape(androidNativeSetupRegistration)}[ \\t]*(?:\\r?\\n)?',
      multiLine: true,
    ),
    '',
  );

  final needsFragmentActivity =
      requiresFragmentActivity ||
      registrations.contains(
        'MiniProgramCameraChannel.register(flutterEngine)',
      );
  if (needsFragmentActivity) {
    updated = updated.replaceFirst(
      'import io.flutter.embedding.android.FlutterActivity',
      'import io.flutter.embedding.android.FlutterFragmentActivity',
    );
    updated = updated.replaceFirst(
      RegExp(r'class\s+MainActivity\s*:\s*FlutterActivity\(\)'),
      'class MainActivity : FlutterFragmentActivity()',
    );
  }

  final classMatch = RegExp(
    r'class\s+MainActivity\s*:\s*(FlutterActivity|FlutterFragmentActivity)\(\)',
  ).firstMatch(updated);
  if (classMatch == null) {
    throw const MiniProgramHostCapabilityException(
      'MainActivity.kt must extend FlutterActivity or '
      'FlutterFragmentActivity for automatic native capability installation.',
    );
  }
  updated = _ensureFlutterEngineImport(
    updated,
    activityBase: classMatch.group(1)!,
    newline: newline,
  );

  final refreshedClass = RegExp(
    r'class\s+MainActivity\s*:\s*(FlutterActivity|FlutterFragmentActivity)\(\)',
  ).firstMatch(updated)!;
  final tail = updated.substring(refreshedClass.end);
  final firstContent = tail.indexOf(RegExp(r'\S'));
  final block = _registrationBlock(newline);
  if (firstContent == -1) {
    return updated.replaceRange(
      refreshedClass.start,
      updated.length,
      'class MainActivity : ${refreshedClass.group(1)}() {$newline'
      '    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {$newline'
      '        super.configureFlutterEngine(flutterEngine)$newline'
      '$block$newline'
      '    }$newline'
      '}',
    );
  }
  if (tail[firstContent] != '{') {
    throw const MiniProgramHostCapabilityException(
      'MainActivity.kt uses an unsupported custom class declaration. Add the '
      'generated capability registry manually or simplify the declaration.',
    );
  }

  final classOpen = refreshedClass.end + firstContent;
  final classEnd = _matchingBrace(updated, classOpen);
  if (classEnd == -1) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely locate the end of MainActivity.kt.',
    );
  }
  final classBody = updated.substring(classOpen + 1, classEnd);
  final configureMatch = RegExp(
    r'override\s+fun\s+configureFlutterEngine\s*\(\s*flutterEngine\s*:\s*FlutterEngine\s*\)\s*\{',
  ).firstMatch(classBody);
  if (configureMatch == null) {
    final method =
        '$newline    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {$newline'
        '        super.configureFlutterEngine(flutterEngine)$newline'
        '$block$newline'
        '    }$newline';
    return updated.replaceRange(classEnd, classEnd, method);
  }

  final methodOpen = classOpen + 1 + configureMatch.end - 1;
  final methodEnd = _matchingBrace(updated, methodOpen);
  if (methodEnd == -1 || methodEnd > classEnd) {
    throw const MiniProgramHostCapabilityException(
      'Could not safely locate MainActivity.configureFlutterEngine.',
    );
  }
  const superCall = 'super.configureFlutterEngine(flutterEngine)';
  final superIndex = updated.indexOf(superCall, methodOpen);
  if (superIndex == -1 || superIndex > methodEnd) {
    throw const MiniProgramHostCapabilityException(
      'MainActivity.configureFlutterEngine must call '
      'super.configureFlutterEngine(flutterEngine) before generated native '
      'capabilities are registered.',
    );
  }
  final superLineEnd = updated.indexOf(newline, superIndex);
  final insertAt = superLineEnd == -1 || superLineEnd > methodEnd
      ? superIndex + superCall.length
      : superLineEnd;
  return updated.replaceRange(insertAt, insertAt, '$newline$block');
}

bool hasManagedAndroidCapabilityRegistration(
  String source,
  String registration,
) {
  final start = source.indexOf(androidCapabilityRegistrationStart);
  final end = source.indexOf(androidCapabilityRegistrationEnd, start + 1);
  return start != -1 &&
      end > start &&
      source.substring(start, end).contains(registration);
}

bool hasManagedAndroidNativeSetupRegistration(String source) {
  final start = source.indexOf(androidCapabilityRegistrationStart);
  final end = source.indexOf(androidCapabilityRegistrationEnd, start + 1);
  return start != -1 &&
      end > start &&
      source.substring(start, end).contains(androidNativeSetupRegistration);
}

String removeAndroidNativeSetupFromMainActivity(String source) {
  _validateManagedBlock(source);
  var updated = _removeManagedBlock(source);
  updated = updated.replaceAll(
    RegExp(
      '^[ \\t]*${RegExp.escape(androidNativeSetupRegistration)}[ \\t]*(?:\\r?\\n)?',
      multiLine: true,
    ),
    '',
  );
  return updated;
}

Set<String> readAndroidMainActivityRegistrations(String source) => <String>{
  for (final registration in androidCapabilityRegistrations)
    if (source.contains(registration)) registration,
};

String _registrationBlock(String newline) {
  return <String>[
    '        $androidCapabilityRegistrationStart',
    '        $androidNativeSetupRegistration',
    '        $androidCapabilityRegistrationEnd',
  ].join(newline);
}

void _validateManagedBlock(String source) {
  final starts = _occurrences(source, androidCapabilityRegistrationStart);
  final ends = _occurrences(source, androidCapabilityRegistrationEnd);
  if (starts > 1 || ends > 1 || starts != ends) {
    throw const MiniProgramHostCapabilityException(
      'MainActivity.kt contains a malformed generated native capability '
      'registration block. Reconcile the block before retrying.',
    );
  }
}

String _removeManagedBlock(String source) {
  return source.replaceFirst(
    RegExp(
      '^[ \\t]*${RegExp.escape(androidCapabilityRegistrationStart)}[ \\t]*'
      r'\r?\n[\s\S]*?'
      '^[ \\t]*${RegExp.escape(androidCapabilityRegistrationEnd)}[ \\t]*'
      r'(?:\r?\n)?',
      multiLine: true,
    ),
    '',
  );
}

String _ensureFlutterEngineImport(
  String source, {
  required String activityBase,
  required String newline,
}) {
  const statement = 'import io.flutter.embedding.engine.FlutterEngine';
  if (source.contains(statement)) return source;
  final activityImport = 'import io.flutter.embedding.android.$activityBase';
  final activityIndex = source.indexOf(activityImport);
  if (activityIndex != -1) {
    final insertAt = activityIndex + activityImport.length;
    return source.replaceRange(insertAt, insertAt, '$newline$statement');
  }
  final imports = RegExp(
    r'^import [^\r\n]+[ \t]*$',
    multiLine: true,
  ).allMatches(source);
  if (imports.isNotEmpty) {
    return source.replaceRange(
      imports.last.end,
      imports.last.end,
      '$newline$statement',
    );
  }
  final packageMatch = RegExp(
    r'^package [^\r\n]+[ \t]*$',
    multiLine: true,
  ).firstMatch(source);
  if (packageMatch != null) {
    return source.replaceRange(
      packageMatch.end,
      packageMatch.end,
      '$newline$newline$statement',
    );
  }
  throw const MiniProgramHostCapabilityException(
    'Could not safely add the FlutterEngine import to MainActivity.kt.',
  );
}

int _matchingBrace(String source, int openIndex) {
  var depth = 0;
  var quote = 0;
  var escaped = false;
  var lineComment = false;
  var blockComment = false;
  for (var index = openIndex; index < source.length; index += 1) {
    final code = source.codeUnitAt(index);
    final next = index + 1 < source.length ? source.codeUnitAt(index + 1) : 0;
    if (lineComment) {
      if (code == 10 || code == 13) lineComment = false;
      continue;
    }
    if (blockComment) {
      if (code == 42 && next == 47) {
        blockComment = false;
        index += 1;
      }
      continue;
    }
    if (quote != 0) {
      if (escaped) {
        escaped = false;
      } else if (code == 92) {
        escaped = true;
      } else if (code == quote) {
        quote = 0;
      }
      continue;
    }
    if (code == 47 && next == 47) {
      lineComment = true;
      index += 1;
      continue;
    }
    if (code == 47 && next == 42) {
      blockComment = true;
      index += 1;
      continue;
    }
    if (code == 34 || code == 39) {
      quote = code;
      continue;
    }
    if (code == 123) depth += 1;
    if (code == 125) {
      depth -= 1;
      if (depth == 0) return index;
    }
  }
  return -1;
}

int _occurrences(String source, String value) {
  var count = 0;
  var start = 0;
  while (true) {
    final index = source.indexOf(value, start);
    if (index == -1) return count;
    count += 1;
    start = index + value.length;
  }
}
