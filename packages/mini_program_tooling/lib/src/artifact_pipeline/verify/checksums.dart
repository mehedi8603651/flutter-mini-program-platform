import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../models.dart';
import '../shared/files.dart';
import '../shared/json_io.dart';
import '../shared/metrics.dart';
import '../shared/paths.dart';

Future<ArtifactMetrics> verifyArtifactChecksums(String versionRoot) async {
  final checksumsPath = path.join(versionRoot, 'checksums.json');
  final checksums = await readArtifactJsonMap(
    checksumsPath,
    code: MiniProgramArtifactErrorCodes.fileMissing,
    label: 'Checksums document',
  );
  if (checksums['schemaVersion'] != 1 || checksums['algorithm'] != 'sha256') {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.structureInvalid,
      message: 'Unsupported checksums document: $checksumsPath',
    );
  }
  final rawRecords = checksums['files'];
  if (rawRecords is! List || rawRecords.isEmpty) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.structureInvalid,
      message: 'Checksums document must contain file records.',
    );
  }

  final records = <String, Map<String, Object?>>{};
  for (final rawRecord in rawRecords) {
    if (rawRecord is! Map) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'Checksums document contains a non-object record.',
      );
    }
    final record = rawRecord.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final path = '${record['path'] ?? ''}'.trim();
    validatePortableArtifactPath(path);
    if (path == 'checksums.json' || records.containsKey(path)) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'Invalid or duplicate checksum path: $path',
      );
    }
    if (record['bytes'] is! int ||
        (record['bytes'] as int) < 0 ||
        !isSha256('${record['sha256'] ?? ''}')) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'Invalid checksum record for: $path',
      );
    }
    records[path] = record;
  }

  final files = await listArtifactFiles(versionRoot, recursive: true);
  final actualPaths = <String>{};
  var totalBytes = 0;
  for (final file in files) {
    final relativePath = relativePortableArtifactPath(file.path, versionRoot);
    totalBytes += await file.length();
    if (relativePath == 'checksums.json') {
      continue;
    }
    actualPaths.add(relativePath);
    final record = records[relativePath];
    if (record == null) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'Artifact file is not recorded in checksums: $relativePath',
      );
    }
    final bytes = await file.readAsBytes();
    final actualHash = sha256.convert(bytes).toString();
    if (record['bytes'] != bytes.length || record['sha256'] != actualHash) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.checksumMismatch,
        message: 'Artifact checksum mismatch: $relativePath',
        details: <String, Object?>{
          'path': relativePath,
          'expectedBytes': record['bytes'],
          'actualBytes': bytes.length,
          'expectedSha256': record['sha256'],
          'actualSha256': actualHash,
        },
      );
    }
  }
  if (actualPaths.length != records.length ||
      !actualPaths.containsAll(records.keys)) {
    final missing = records.keys
        .where((path) => !actualPaths.contains(path))
        .toList();
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.fileMissing,
      message:
          'Checksums reference missing artifact files: ${missing.join(', ')}',
    );
  }

  return ArtifactMetrics(fileCount: files.length, totalBytes: totalBytes);
}
