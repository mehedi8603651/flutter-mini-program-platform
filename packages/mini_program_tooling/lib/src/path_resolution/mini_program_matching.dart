import 'package:path/path.dart' as p;

import 'manifest_identity.dart';
import 'models.dart';
import 'normalization.dart';

Future<MatchedMiniProgram?> matchMiniProgramRoot(
  String rootPath, {
  required String expectedMiniProgramId,
}) async {
  final manifestId = await readMiniProgramManifestId(rootPath);
  if (manifestId == null || manifestId != expectedMiniProgramId) {
    return null;
  }

  return MatchedMiniProgram(
    miniProgramRootPath: normalizeAbsolutePath(rootPath),
    miniProgramId: manifestId,
  );
}

bool isMiniProgramInsideRepo({
  required String repoRootPath,
  required String miniProgramRootPath,
}) => p.isWithin(p.join(repoRootPath, 'mini_programs'), miniProgramRootPath);
