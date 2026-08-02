import '../models.dart';

const String androidCapabilityDependenciesStart =
    '// <mini-program-native-dependencies>';
const String androidCapabilityDependenciesEnd =
    '// </mini-program-native-dependencies>';

const String androidQrDependencyCapability = 'qr';
const String androidMediaPlaybackDependencyCapability = 'media-playback';

const Map<String, List<String>> _dependencies = <String, List<String>>{
  androidMediaPlaybackDependencyCapability: <String>[
    'androidx.media3:media3-exoplayer:1.5.1',
    'androidx.media3:media3-exoplayer-hls:1.5.1',
    'androidx.media3:media3-ui:1.5.1',
    'androidx.media3:media3-datasource:1.5.1',
    'androidx.media3:media3-database:1.5.1',
  ],
  androidQrDependencyCapability: <String>[
    'androidx.camera:camera-camera2:1.4.2',
    'androidx.camera:camera-lifecycle:1.4.2',
    'androidx.camera:camera-view:1.4.2',
    'com.google.mlkit:barcode-scanning:17.3.0',
  ],
};

String patchAndroidCapabilityDependencies(
  String source, {
  required String capability,
  required bool kotlinDsl,
}) {
  if (!_dependencies.containsKey(capability)) {
    throw MiniProgramHostCapabilityException(
      'Unsupported generated Android dependency capability `$capability`.',
    );
  }
  _validateManagedBlock(source);
  final newline = source.contains('\r\n') ? '\r\n' : '\n';
  final capabilities = _managedCapabilities(source)
    ..addAll(_legacyCapabilities(source))
    ..add(capability);
  var base = _removeManagedBlock(source);
  base = _removeLegacyBlock(base, 'mini-program-qr-capability');
  base = _removeLegacyBlock(base, 'mini-program-media-playback-capability');
  base = base.trimRight();

  final quote = kotlinDsl ? '"' : "'";
  final dependencyLines = <String>[];
  for (final capabilityName in _dependencies.keys.where(
    capabilities.contains,
  )) {
    for (final dependency in _dependencies[capabilityName]!) {
      if (base.contains(dependency)) continue;
      dependencyLines.add(
        kotlinDsl
            ? '    implementation($quote$dependency$quote)'
            : '    implementation $quote$dependency$quote',
      );
    }
  }
  final orderedCapabilities = _dependencies.keys.where(capabilities.contains);
  final block = <String>[
    androidCapabilityDependenciesStart,
    '// capabilities: ${orderedCapabilities.join(', ')}',
    if (dependencyLines.isNotEmpty) ...<String>[
      'dependencies {',
      ...dependencyLines,
      '}',
    ],
    androidCapabilityDependenciesEnd,
  ].join(newline);
  return '$base$newline$newline$block$newline';
}

bool hasManagedAndroidCapabilityDependencies(
  String source,
  String capability,
) => _managedCapabilities(source).contains(capability);

Set<String> _managedCapabilities(String source) {
  final start = source.indexOf(androidCapabilityDependenciesStart);
  final end = source.indexOf(androidCapabilityDependenciesEnd, start + 1);
  if (start == -1 || end <= start) return <String>{};
  final block = source.substring(start, end);
  final match = RegExp(
    r'^// capabilities:\s*(.*)$',
    multiLine: true,
  ).firstMatch(block);
  if (match == null) return <String>{};
  return match
      .group(1)!
      .split(',')
      .map((value) => value.trim())
      .where(_dependencies.containsKey)
      .toSet();
}

Set<String> _legacyCapabilities(String source) => <String>{
  if (source.contains('mini-program-qr-capability'))
    androidQrDependencyCapability,
  if (source.contains('mini-program-media-playback-capability'))
    androidMediaPlaybackDependencyCapability,
};

void _validateManagedBlock(String source) {
  final starts = _occurrences(source, androidCapabilityDependenciesStart);
  final ends = _occurrences(source, androidCapabilityDependenciesEnd);
  if (starts > 1 || ends > 1 || starts != ends) {
    throw const MiniProgramHostCapabilityException(
      'The Android app Gradle file contains a malformed generated native '
      'dependency block. Reconcile the block before retrying.',
    );
  }
}

String _removeManagedBlock(String source) => source.replaceFirst(
  RegExp(
    '${RegExp.escape(androidCapabilityDependenciesStart)}'
    r'[\s\S]*?'
    '${RegExp.escape(androidCapabilityDependenciesEnd)}(?:\\r?\\n)?',
  ),
  '',
);

String _removeLegacyBlock(String source, String marker) => source.replaceFirst(
  RegExp(
    '(?:\\r?\\n)?// ${RegExp.escape(marker)}\\s*\\r?\\n'
    r'dependencies\s*\{[\s\S]*?\}\s*',
  ),
  '',
);

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
