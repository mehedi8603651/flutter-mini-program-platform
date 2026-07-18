import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../shared/files.dart';
import '../shared/json_io.dart';
import '../shared/paths.dart';

Future<void> writeArtifactChecksums(String stagingPath) async {
  final payloadFiles = await listArtifactFiles(stagingPath, recursive: true);
  final checksumRecords = <Map<String, Object?>>[];
  for (final file in payloadFiles) {
    final relativePath = relativePortableArtifactPath(file.path, stagingPath);
    if (relativePath == 'checksums.json') {
      continue;
    }
    final bytes = await file.readAsBytes();
    checksumRecords.add(<String, Object?>{
      'path': relativePath,
      'bytes': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
    });
  }
  checksumRecords.sort(
    (left, right) => '${left['path']}'.compareTo('${right['path']}'),
  );
  await writeCanonicalArtifactJson(path.join(stagingPath, 'checksums.json'), {
    'schemaVersion': 1,
    'algorithm': 'sha256',
    'files': checksumRecords,
  });
}
