import 'package:path/path.dart' as p;

import 'manifest_identity.dart';
import 'mini_program_matching.dart';
import 'models.dart';
import 'normalization.dart';
import 'repo_discovery.dart';

Future<String?> inferResolvedMiniProgramId({
  String? miniProgramRootPath,
  String? currentWorkingDirectory,
}) async {
  final cwd = normalizeWorkingDirectory(currentWorkingDirectory);
  final candidates = <String>[
    if (miniProgramRootPath != null && miniProgramRootPath.trim().isNotEmpty)
      normalizeAbsolutePath(miniProgramRootPath),
    cwd,
  ];

  for (final candidate in candidates) {
    final manifestId = await readMiniProgramManifestId(candidate);
    if (manifestId != null && manifestId.isNotEmpty) {
      return manifestId;
    }
  }

  return null;
}

Future<ResolvedMiniProgramPaths> resolveMiniProgramPaths({
  required String miniProgramId,
  String? repoRootPath,
  String? miniProgramRootPath,
  String? currentWorkingDirectory,
  bool requireRepoRoot = false,
}) async {
  final normalizedMiniProgramId = miniProgramId.trim();
  if (normalizedMiniProgramId.isEmpty) {
    throw const MiniProgramPathResolutionException(
      'Mini-program id must not be blank.',
    );
  }

  final cwd = normalizeWorkingDirectory(currentWorkingDirectory);
  final normalizedRepoRootPath = repoRootPath == null
      ? null
      : normalizeAbsolutePath(repoRootPath);
  final checkedPaths = <String>[];
  final candidates = <MiniProgramPathCandidate>[
    if (miniProgramRootPath != null && miniProgramRootPath.trim().isNotEmpty)
      MiniProgramPathCandidate(
        path: normalizeAbsolutePath(miniProgramRootPath),
        label: '--mini-program-root',
        isExplicit: true,
      ),
    if (normalizedRepoRootPath != null)
      MiniProgramPathCandidate(
        path: p.join(
          normalizedRepoRootPath,
          'mini_programs',
          normalizedMiniProgramId,
        ),
        label: '--repo-root + mini_programs/<id>',
        isRepoManaged: true,
      ),
    MiniProgramPathCandidate(path: cwd, label: 'current directory'),
    MiniProgramPathCandidate(
      path: p.join(cwd, normalizedMiniProgramId),
      label: './<id>',
    ),
  ];

  for (final candidate in candidates) {
    checkedPaths.add('${candidate.label}: ${candidate.path}');
    final match = await matchMiniProgramRoot(
      candidate.path,
      expectedMiniProgramId: normalizedMiniProgramId,
    );
    if (match != null) {
      final resolvedRepoRoot =
          normalizedRepoRootPath ??
          await resolvePlatformRepoRoot(
            currentWorkingDirectory: cwd,
            additionalSearchPath: match.miniProgramRootPath,
            required: requireRepoRoot,
          );

      return ResolvedMiniProgramPaths(
        repoRootPath: resolvedRepoRoot,
        miniProgramRootPath: match.miniProgramRootPath,
        miniProgramId: match.miniProgramId,
        isRepoManaged:
            candidate.isRepoManaged ||
            (resolvedRepoRoot != null &&
                isMiniProgramInsideRepo(
                  repoRootPath: resolvedRepoRoot,
                  miniProgramRootPath: match.miniProgramRootPath,
                )),
        checkedPaths: checkedPaths,
      );
    }

    if (candidate.isExplicit) {
      throw MiniProgramPathResolutionException(
        'No usable manifest.json matching "$normalizedMiniProgramId" was '
        'found under ${candidate.path}.',
      );
    }
  }

  throw MiniProgramPathResolutionException(
    'Could not resolve mini-program "$normalizedMiniProgramId". Checked:\n'
    '${checkedPaths.map((path) => '- $path').join('\n')}',
  );
}
