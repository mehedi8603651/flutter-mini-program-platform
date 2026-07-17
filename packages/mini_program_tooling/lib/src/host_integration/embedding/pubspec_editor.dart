import 'package:path/path.dart' as path;

String extractEmbeddingPubspecField(
  String source,
  String fieldName, {
  required String fallbackValue,
}) {
  final match = RegExp(
    '^\\s*$fieldName\\s*:\\s*([^\\r\\n#]+)',
    multiLine: true,
  ).firstMatch(source);
  if (match == null) {
    return fallbackValue;
  }

  return match.group(1)?.trim().replaceAll("'", '') ?? fallbackValue;
}

String extractEmbeddingVersion(String source) {
  final rawVersion = extractEmbeddingPubspecField(
    source,
    'version',
    fallbackValue: '1.0.0',
  );
  return rawVersion.split('+').first.trim();
}

String ensureEmbeddingDependencies(
  String source, {
  required String projectRootPath,
  required String? repoRootPath,
  required String sdkConstraint,
  required String contractsConstraint,
}) {
  final managedDependencies = <String, List<String>>{
    'mini_program_sdk': <String>['  mini_program_sdk: $sdkConstraint'],
    'mini_program_contracts': <String>[
      '  mini_program_contracts: $contractsConstraint',
    ],
  };
  var updated = _upsertPackageSection(
    source,
    sectionName: 'dependencies',
    managedPackages: managedDependencies,
    removePackages: const <String>{'mini_program_legacy_stac'},
  );
  if (repoRootPath == null) {
    return updated;
  }

  String relativePackagePath(String packageName) {
    return path
        .relative(
          path.join(repoRootPath, 'packages', packageName),
          from: projectRootPath,
        )
        .replaceAll('\\', '/');
  }

  updated = _upsertPackageSection(
    updated,
    sectionName: 'dependency_overrides',
    managedPackages: <String, List<String>>{
      'mini_program_sdk': <String>[
        '  mini_program_sdk:',
        '    path: ${relativePackagePath('mini_program_sdk')}',
      ],
      'mini_program_contracts': <String>[
        '  mini_program_contracts:',
        '    path: ${relativePackagePath('mini_program_contracts')}',
      ],
    },
    removePackages: const <String>{'mini_program_legacy_stac'},
  );
  return updated;
}

String _upsertPackageSection(
  String source, {
  required String sectionName,
  required Map<String, List<String>> managedPackages,
  Set<String> removePackages = const <String>{},
}) {
  final normalizedSource = source.replaceAll('\r\n', '\n');
  final lines = normalizedSource.split('\n');
  final dependenciesHeaderIndex = lines.indexWhere(
    (line) => line.trim() == '$sectionName:',
  );

  if (dependenciesHeaderIndex == -1) {
    final suffix = normalizedSource.endsWith('\n') || normalizedSource.isEmpty
        ? ''
        : '\n';
    return <String>[
      '$normalizedSource$suffix$sectionName:',
      ...managedPackages.values.expand((lines) => lines),
      '',
    ].join('\n');
  }

  var dependenciesEndIndex = dependenciesHeaderIndex + 1;
  while (dependenciesEndIndex < lines.length) {
    final line = lines[dependenciesEndIndex];
    if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*:\s*$').hasMatch(line)) {
      break;
    }
    dependenciesEndIndex += 1;
  }

  final sectionLines = lines.sublist(
    dependenciesHeaderIndex + 1,
    dependenciesEndIndex,
  );
  final rebuiltSectionLines = <String>[];
  final writtenPackages = <String>{};

  for (var index = 0; index < sectionLines.length; index++) {
    final line = sectionLines[index];
    final packageMatch = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(line);
    if (packageMatch == null) {
      rebuiltSectionLines.add(line);
      continue;
    }

    final packageName = packageMatch.group(1)!;
    final blockLines = <String>[line];
    while (index + 1 < sectionLines.length &&
        !RegExp(r'^  [A-Za-z0-9_]+:').hasMatch(sectionLines[index + 1])) {
      index += 1;
      blockLines.add(sectionLines[index]);
    }

    if (!managedPackages.containsKey(packageName) &&
        !removePackages.contains(packageName)) {
      rebuiltSectionLines.addAll(blockLines);
      continue;
    }
    final replacement = managedPackages[packageName];
    if (replacement != null) {
      writtenPackages.add(packageName);
      rebuiltSectionLines.addAll(replacement);
    }
  }

  for (final entry in managedPackages.entries) {
    if (writtenPackages.add(entry.key)) {
      rebuiltSectionLines.addAll(entry.value);
    }
  }

  final rebuiltLines = <String>[
    ...lines.sublist(0, dependenciesHeaderIndex + 1),
    ...rebuiltSectionLines,
    ...lines.sublist(dependenciesEndIndex),
  ];
  return rebuiltLines.join('\n');
}
