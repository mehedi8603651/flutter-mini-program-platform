import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class MiniProgramPathResolutionException implements Exception {
  const MiniProgramPathResolutionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ResolvedMiniProgramPaths {
  const ResolvedMiniProgramPaths({
    required this.repoRootPath,
    required this.miniProgramRootPath,
    required this.miniProgramId,
    required this.isRepoManaged,
    required this.checkedPaths,
  });

  final String? repoRootPath;
  final String miniProgramRootPath;
  final String miniProgramId;
  final bool isRepoManaged;
  final List<String> checkedPaths;
}

class MiniProgramPathResolver {
  const MiniProgramPathResolver();

  Future<String?> inferMiniProgramId({
    String? miniProgramRootPath,
    String? currentWorkingDirectory,
  }) async {
    final cwd = p.normalize(
      p.absolute(currentWorkingDirectory ?? Directory.current.path),
    );

    final candidates = <String>[
      if (miniProgramRootPath != null && miniProgramRootPath.trim().isNotEmpty)
        p.normalize(p.absolute(miniProgramRootPath)),
      cwd,
    ];

    for (final candidate in candidates) {
      final manifestId = await _readManifestId(candidate);
      if (manifestId != null && manifestId.isNotEmpty) {
        return manifestId;
      }
    }

    return null;
  }

  Future<ResolvedMiniProgramPaths> resolve({
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

    final cwd = p.normalize(
      p.absolute(currentWorkingDirectory ?? Directory.current.path),
    );
    final normalizedRepoRootPath = repoRootPath == null
        ? null
        : p.normalize(p.absolute(repoRootPath));

    final checkedPaths = <String>[];
    final candidates = <_MiniProgramCandidate>[
      if (miniProgramRootPath != null && miniProgramRootPath.trim().isNotEmpty)
        _MiniProgramCandidate(
          path: p.normalize(p.absolute(miniProgramRootPath)),
          label: '--mini-program-root',
          isExplicit: true,
        ),
      if (normalizedRepoRootPath != null)
        _MiniProgramCandidate(
          path: p.join(normalizedRepoRootPath, 'mini_programs', normalizedMiniProgramId),
          label: '--repo-root + mini_programs/<id>',
          isRepoManaged: true,
        ),
      _MiniProgramCandidate(
        path: p.join(cwd, normalizedMiniProgramId),
        label: './<id>',
      ),
      _MiniProgramCandidate(
        path: cwd,
        label: 'current directory',
      ),
    ];

    for (final candidate in candidates) {
      checkedPaths.add('${candidate.label}: ${candidate.path}');

      final match = await _matchMiniProgramRoot(
        candidate.path,
        expectedMiniProgramId: normalizedMiniProgramId,
      );
      if (match != null) {
        final resolvedRepoRoot = normalizedRepoRootPath ??
            await resolveRepoRoot(
              currentWorkingDirectory: cwd,
              additionalSearchPath: match.miniProgramRootPath,
              required: requireRepoRoot,
            );

        return ResolvedMiniProgramPaths(
          repoRootPath: resolvedRepoRoot,
          miniProgramRootPath: match.miniProgramRootPath,
          miniProgramId: match.miniProgramId,
          isRepoManaged: candidate.isRepoManaged ||
              (resolvedRepoRoot != null &&
                  p.isWithin(
                    p.join(resolvedRepoRoot, 'mini_programs'),
                    match.miniProgramRootPath,
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

  Future<String?> resolveRepoRoot({
    String? explicitRepoRootPath,
    String? currentWorkingDirectory,
    String? additionalSearchPath,
    bool required = false,
  }) async {
    if (explicitRepoRootPath != null && explicitRepoRootPath.trim().isNotEmpty) {
      final normalizedRepoRoot = p.normalize(p.absolute(explicitRepoRootPath));
      if (!await _looksLikeRepoRoot(normalizedRepoRoot)) {
        throw MiniProgramPathResolutionException(
          'Repo root does not look like the platform repository: '
          '$normalizedRepoRoot',
        );
      }
      return normalizedRepoRoot;
    }

    final startDirectories = <String>{
      p.normalize(
        p.absolute(currentWorkingDirectory ?? Directory.current.path),
      ),
      if (additionalSearchPath != null && additionalSearchPath.trim().isNotEmpty)
        p.normalize(p.absolute(additionalSearchPath)),
    };

    for (final startDirectory in startDirectories) {
      final discovered = await discoverRepoRoot(startDirectory: startDirectory);
      if (discovered != null) {
        return discovered;
      }
    }

    if (required) {
      throw const MiniProgramPathResolutionException(
        'Could not find the platform repo root. Provide --repo-root or run the '
        'command from inside the platform repository.',
      );
    }

    return null;
  }

  Future<String?> discoverRepoRoot({
    required String startDirectory,
  }) async {
    var current = p.normalize(p.absolute(startDirectory));

    while (true) {
      if (await _looksLikeRepoRoot(current)) {
        return current;
      }

      final parent = p.dirname(current);
      if (parent == current) {
        return null;
      }
      current = parent;
    }
  }

  Future<bool> _looksLikeRepoRoot(String directoryPath) async {
    final miniProgramsRoot = Directory(p.join(directoryPath, 'mini_programs'));
    final backendApiRoot = Directory(p.join(directoryPath, 'backend', 'api'));
    final toolingPackage = File(
      p.join(
        directoryPath,
        'packages',
        'mini_program_tooling',
        'pubspec.yaml',
      ),
    );

    return await miniProgramsRoot.exists() &&
        await backendApiRoot.exists() &&
        await toolingPackage.exists();
  }

  Future<_MatchedMiniProgram?> _matchMiniProgramRoot(
    String rootPath, {
    required String expectedMiniProgramId,
  }) async {
    final manifestId = await _readManifestId(rootPath);
    if (manifestId == null || manifestId != expectedMiniProgramId) {
      return null;
    }

    return _MatchedMiniProgram(
      miniProgramRootPath: p.normalize(p.absolute(rootPath)),
      miniProgramId: manifestId,
    );
  }

  Future<String?> _readManifestId(String rootPath) async {
    final rootDirectory = Directory(rootPath);
    if (!await rootDirectory.exists()) {
      return null;
    }

    final manifestFile = File(p.join(rootPath, 'manifest.json'));
    if (!await manifestFile.exists()) {
      return null;
    }

    try {
      final decoded = jsonDecode(await manifestFile.readAsString());
      if (decoded is! Map) {
        return null;
      }

      final manifest = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final manifestId = '${manifest['id'] ?? ''}'.trim();
      return manifestId.isEmpty ? null : manifestId;
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }
}

class _MiniProgramCandidate {
  const _MiniProgramCandidate({
    required this.path,
    required this.label,
    this.isExplicit = false,
    this.isRepoManaged = false,
  });

  final String path;
  final String label;
  final bool isExplicit;
  final bool isRepoManaged;
}

class _MatchedMiniProgram {
  const _MatchedMiniProgram({
    required this.miniProgramRootPath,
    required this.miniProgramId,
  });

  final String miniProgramRootPath;
  final String miniProgramId;
}
