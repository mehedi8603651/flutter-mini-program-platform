import 'package:path/path.dart' as path;

import '../models.dart';

String relativePortableArtifactPath(String filePath, String rootPath) =>
    path.relative(filePath, from: rootPath).replaceAll('\\', '/');

void validatePortableArtifactPath(String value) {
  if (value.isEmpty ||
      value.contains('\\') ||
      value.startsWith('/') ||
      path.posix.isAbsolute(value) ||
      path.posix.normalize(value) != value ||
      value.split('/').any((segment) => segment.isEmpty || segment == '..')) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.pathUnsafe,
      message: 'Unsafe artifact path in checksums: $value',
    );
  }
}

void assertArtifactPathContained(String candidatePath, String rootPath) {
  final candidate = path.normalize(path.absolute(candidatePath));
  final root = path.normalize(path.absolute(rootPath));
  if (candidate != root && !path.isWithin(root, candidate)) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.pathUnsafe,
      message: 'Artifact path escaped its root: $candidate',
      details: <String, Object?>{'root': root},
    );
  }
}

bool isSha256(String value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
