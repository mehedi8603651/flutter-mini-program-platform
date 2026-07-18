import 'dart:io';

import 'package:path/path.dart' as p;

Future<Map<String, Object?>> detectWorkflowBackendUsage(
  String workspacePath,
) async {
  final roots = <Directory>[
    Directory(p.join(workspacePath, 'lib')),
    Directory(p.join(workspacePath, 'mp')),
  ];
  final sources = <String>[];
  for (final root in roots) {
    if (!await root.exists()) {
      continue;
    }
    await for (final entity in root.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final basename = p.basename(entity.path);
      if (!basename.endsWith('.dart') && !basename.endsWith('.json')) {
        continue;
      }
      try {
        sources.add(await entity.readAsString());
      } catch (_) {
        // Workflow status is best-effort and ignores unreadable build output.
      }
    }
  }
  final joined = sources.join('\n');
  final requestIds = <String>{};
  final requestIdPattern = RegExp(
    r'''requestId\s*:\s*(['"])(.*?)\1|"requestId"\s*:\s*"(.*?)"''',
    dotAll: true,
  );
  for (final match in requestIdPattern.allMatches(joined)) {
    final value = match.group(2) ?? match.group(3) ?? '';
    if (value.trim().isNotEmpty) {
      requestIds.add(value.trim());
    }
  }
  final usesAction =
      joined.contains('miniProgramBackendAction(') ||
      joined.contains('Mp.backend.call(') ||
      joined.contains('"actionType":"miniProgramBackend"') ||
      joined.contains('"actionType": "miniProgramBackend"') ||
      joined.contains('"type":"backend.call"') ||
      joined.contains('"type": "backend.call"');
  final usesQueryAction =
      joined.contains('miniProgramBackendQueryAction(') ||
      joined.contains('Mp.backend.query(') ||
      joined.contains('"actionType":"miniProgramBackendQuery"') ||
      joined.contains('"actionType": "miniProgramBackendQuery"') ||
      joined.contains('"type":"backend.query"') ||
      joined.contains('"type": "backend.query"');
  final usesBuilder =
      joined.contains('miniProgramBackendBuilder(') ||
      joined.contains('Mp.backendBuilder(') ||
      joined.contains('"type":"miniProgramBackendBuilder"') ||
      joined.contains('"type": "miniProgramBackendBuilder"') ||
      joined.contains('"type":"backendBuilder"') ||
      joined.contains('"type": "backendBuilder"');
  final usesPagedBuilder =
      joined.contains('miniProgramPagedBackendBuilder(') ||
      joined.contains('Mp.pagedBackendBuilder(') ||
      joined.contains('"type":"miniProgramPagedBackendBuilder"') ||
      joined.contains('"type": "miniProgramPagedBackendBuilder"') ||
      joined.contains('"type":"pagedBackendBuilder"') ||
      joined.contains('"type": "pagedBackendBuilder"');
  final usesLazyChunk =
      joined.contains('Mp.lazy.chunk(') ||
      joined.contains('"type":"lazyChunk"') ||
      joined.contains('"type": "lazyChunk"');
  final usesLoadMore =
      joined.contains('miniProgramLoadMore(') ||
      joined.contains('Mp.backend.loadMore(') ||
      joined.contains('"actionType":"miniProgramLoadMore"') ||
      joined.contains('"actionType": "miniProgramLoadMore"') ||
      joined.contains('"type":"backend.loadMore"') ||
      joined.contains('"type": "backend.loadMore"');
  final usesAuthBuilder =
      joined.contains('Mp.authBuilder(') ||
      joined.contains('"type":"authBuilder"') ||
      joined.contains('"type": "authBuilder"');
  return <String, Object?>{
    'usesBackendAction': usesAction,
    'usesBackendQueryAction': usesQueryAction,
    'usesBackendBuilder': usesBuilder,
    'usesPagedBackendBuilder': usesPagedBuilder,
    'usesLazyChunk': usesLazyChunk,
    'usesLoadMore': usesLoadMore,
    'usesAuthBuilder': usesAuthBuilder,
    'usesBackendState':
        usesQueryAction ||
        usesBuilder ||
        usesPagedBuilder ||
        usesLazyChunk ||
        usesLoadMore,
    'usesPublisherBackend':
        usesAction ||
        usesQueryAction ||
        usesBuilder ||
        usesPagedBuilder ||
        usesLazyChunk ||
        usesLoadMore,
    'requestIds': requestIds.toList()..sort(),
  };
}
