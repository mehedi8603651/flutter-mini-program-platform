import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';

Future<MiniProgramHostCapabilityInitResult> writeCapabilityFiles({
  required String projectRootPath,
  required String capability,
  required String platform,
  required Map<String, String> writes,
  Set<String> deletes = const <String>{},
}) async {
  if (writes.isEmpty && deletes.isEmpty) {
    return MiniProgramHostCapabilityInitResult(
      projectRootPath: projectRootPath,
      capability: capability,
      platform: platform,
      createdPaths: const <String>[],
      updatedPaths: const <String>[],
    );
  }
  final root = p.normalize(p.absolute(projectRootPath));
  final entries = writes.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  final deletePaths =
      deletes.map((path) => p.normalize(p.absolute(path))).toList()..sort();
  final writePaths = <String>{
    for (final entry in entries) p.normalize(p.absolute(entry.key)),
  };
  final overlap = deletePaths.where(writePaths.contains).toList();
  if (overlap.isNotEmpty) {
    throw MiniProgramHostCapabilityException(
      'Refusing to write and remove the same generated capability path: '
      '${overlap.first}',
    );
  }
  for (final entry in entries) {
    final target = p.normalize(p.absolute(entry.key));
    if (target != root && !p.isWithin(root, target)) {
      throw MiniProgramHostCapabilityException(
        'Refusing to write generated capability files outside the Flutter '
        'host root: $target',
      );
    }
    final type = await FileSystemEntity.type(target, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw MiniProgramHostCapabilityException(
        'Refusing to replace the non-file host path $target.',
      );
    }
  }
  for (final target in deletePaths) {
    if (target != root && !p.isWithin(root, target)) {
      throw MiniProgramHostCapabilityException(
        'Refusing to remove generated capability files outside the Flutter '
        'host root: $target',
      );
    }
    final type = await FileSystemEntity.type(target, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw MiniProgramHostCapabilityException(
        'Refusing to remove the non-file host path $target.',
      );
    }
  }

  final nonce = '${pid}_${DateTime.now().microsecondsSinceEpoch}';
  final staged = <String, File>{};
  final backups = <String, File>{};
  final promoted = <String>[];
  final existed = <String, bool>{};
  final deleted = <String>[];
  try {
    for (var index = 0; index < entries.length; index += 1) {
      final target = File(entries[index].key);
      existed[target.path] = await target.exists();
      await target.parent.create(recursive: true);
      final temporary = File('${target.path}.miniprogram_$nonce.$index.tmp');
      await temporary.writeAsString(entries[index].value, flush: true);
      staged[target.path] = temporary;
    }
    final backupPaths = <String>[
      ...entries
          .where((entry) => existed[entry.key]!)
          .map((entry) => entry.key),
      ...deletePaths.where((path) => File(path).existsSync()),
    ];
    for (var index = 0; index < backupPaths.length; index += 1) {
      final target = File(backupPaths[index]);
      if (await target.exists()) {
        final backup = File('${target.path}.miniprogram_$nonce.$index.bak');
        await target.rename(backup.path);
        backups[target.path] = backup;
        if (deletePaths.contains(target.path)) deleted.add(target.path);
      }
    }
    for (var index = 0; index < entries.length; index += 1) {
      final target = File(entries[index].key);
      await staged[target.path]!.rename(target.path);
      promoted.add(target.path);
    }
  } catch (error) {
    final rollbackErrors = <Object>[];
    for (final targetPath in promoted.reversed) {
      try {
        final target = File(targetPath);
        if (await target.exists()) await target.delete();
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
    }
    for (final entry in backups.entries) {
      try {
        if (await entry.value.exists()) {
          await entry.value.rename(entry.key);
        }
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
    }
    for (final temporary in staged.values) {
      try {
        if (await temporary.exists()) await temporary.delete();
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
    }
    throw MiniProgramHostCapabilityException(
      rollbackErrors.isEmpty
          ? 'Native capability installation failed before commit; all host '
                'files were restored. Cause: $error'
          : 'Native capability installation failed and rollback was '
                'incomplete. Review generated .bak/.tmp files before retrying. '
                'Cause: $error',
    );
  }

  // Promotion is the commit point. Backup cleanup is best-effort so a stale
  // backup can never turn a successful commit into a destructive rollback.
  for (final backup in backups.values) {
    try {
      if (await backup.exists()) await backup.delete();
    } on FileSystemException {
      // The generated backup is intentionally retained for manual cleanup.
    }
  }

  final created = <String>[
    for (final entry in entries)
      if (!existed[entry.key]!) entry.key,
  ];
  final updated = <String>[
    for (final entry in entries)
      if (existed[entry.key]!) entry.key,
    ...deleted,
  ];
  return MiniProgramHostCapabilityInitResult(
    projectRootPath: projectRootPath,
    capability: capability,
    platform: platform,
    createdPaths: List<String>.unmodifiable(created),
    updatedPaths: List<String>.unmodifiable(updated),
  );
}
