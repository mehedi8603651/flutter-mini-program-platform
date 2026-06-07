import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as p;

import 'publisher_backend_starter.dart';

class MiniProgramScaffoldRequest {
  const MiniProgramScaffoldRequest({
    required this.miniProgramId,
    this.repoRootPath,
    this.outputRootPath,
    this.title,
    this.description,
    this.capabilities = const <String>{'analytics'},
    this.backendTemplate,
    this.screenFormat = MiniProgramScreenFormats.mp,
    this.force = false,
  });

  final String miniProgramId;
  final String? repoRootPath;
  final String? outputRootPath;
  final String? title;
  final String? description;
  final Set<String> capabilities;
  final String? backendTemplate;
  final String screenFormat;
  final bool force;
}

class MiniProgramScaffoldResult {
  const MiniProgramScaffoldResult({
    required this.repoRootPath,
    required this.miniProgramRootPath,
    required this.miniProgramId,
    required this.title,
    required this.description,
    required this.capabilities,
    required this.screenFormat,
    required this.createdPaths,
  });

  final String? repoRootPath;
  final String miniProgramRootPath;
  final String miniProgramId;
  final String title;
  final String description;
  final List<String> capabilities;
  final String screenFormat;
  final List<String> createdPaths;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'repoRootPath': repoRootPath,
    'miniProgramRootPath': miniProgramRootPath,
    'miniProgramId': miniProgramId,
    'title': title,
    'description': description,
    'capabilities': capabilities,
    'screenFormat': screenFormat,
    'createdPaths': createdPaths,
  };
}

class MiniProgramScaffoldException implements Exception {
  const MiniProgramScaffoldException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MiniProgramScaffolder {
  const MiniProgramScaffolder();

  static final RegExp _miniProgramIdPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  static const List<CapabilityId> _scaffoldCapabilityOrder = <CapabilityId>[
    CapabilityIds.auth,
    CapabilityIds.analytics,
    CapabilityIds.secureApi,
    CapabilityIds.nativeNavigation,
  ];

  static const Set<CapabilityId> _knownCapabilities = <CapabilityId>{
    CapabilityIds.auth,
    CapabilityIds.analytics,
    CapabilityIds.secureApi,
    CapabilityIds.nativeNavigation,
  };

  Future<MiniProgramScaffoldResult> scaffold(
    MiniProgramScaffoldRequest request,
  ) async {
    final repoRootPath = request.repoRootPath == null
        ? null
        : p.normalize(p.absolute(request.repoRootPath!));

    final miniProgramId = request.miniProgramId.trim();
    if (!_miniProgramIdPattern.hasMatch(miniProgramId)) {
      throw const MiniProgramScaffoldException(
        r'Mini-program ID must match ^[a-z][a-z0-9_]*$',
      );
    }

    final orderedCapabilities = _normalizeCapabilities(request.capabilities);
    final backendTemplate = _normalizeBackendTemplate(request.backendTemplate);
    final screenFormat = _normalizeScreenFormat(request.screenFormat);
    final withMockBackend = backendTemplate == 'mock';
    final title = _normalizeTitle(request.title, miniProgramId);
    final description = _normalizeDescription(request.description, title);
    final miniProgramRootPath = await _resolveMiniProgramRootPath(
      repoRootPath: repoRootPath,
      outputRootPath: request.outputRootPath,
      miniProgramId: miniProgramId,
    );
    final miniProgramRootDir = Directory(miniProgramRootPath);

    if (await miniProgramRootDir.exists() &&
        !request.force &&
        await _directoryHasEntries(miniProgramRootDir)) {
      throw MiniProgramScaffoldException(
        'Mini-program already exists: $miniProgramRootPath '
        '(use --force to overwrite scaffold-managed files)',
      );
    }

    await miniProgramRootDir.create(recursive: true);

    final entryScreenId = '${miniProgramId}_home';
    final detailsScreenId = '${miniProgramId}_details';
    final packageName = '${miniProgramId}_mini_program';

    final managedFiles = await _buildMpManagedFiles(
      miniProgramRootPath: miniProgramRootPath,
      miniProgramId: miniProgramId,
      title: title,
      description: description,
      capabilities: orderedCapabilities,
      entryScreenId: entryScreenId,
      detailsScreenId: detailsScreenId,
      packageName: packageName,
      withMockBackend: withMockBackend,
    );
    if (withMockBackend) {
      managedFiles.addAll(
        _buildMockBackendFiles(
          miniProgramRootPath: miniProgramRootPath,
          miniProgramId: miniProgramId,
          title: title,
        ),
      );
    }

    final createdPaths = <String>[];
    for (final entry in managedFiles.entries) {
      final file = File(entry.key);
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
      createdPaths.add(file.path);
    }

    return MiniProgramScaffoldResult(
      repoRootPath: repoRootPath,
      miniProgramRootPath: miniProgramRootPath,
      miniProgramId: miniProgramId,
      title: title,
      description: description,
      capabilities: orderedCapabilities,
      screenFormat: screenFormat,
      createdPaths: createdPaths,
    );
  }

  Future<String> _resolveMiniProgramRootPath({
    required String? repoRootPath,
    required String? outputRootPath,
    required String miniProgramId,
  }) async {
    if (outputRootPath != null && outputRootPath.trim().isNotEmpty) {
      return p.normalize(p.absolute(outputRootPath.trim()));
    }

    if (repoRootPath == null || repoRootPath.trim().isEmpty) {
      throw const MiniProgramScaffoldException(
        'Provide either --repo-root or --output-root.',
      );
    }

    final normalizedRepoRoot = p.normalize(p.absolute(repoRootPath));
    final repoRootDir = Directory(normalizedRepoRoot);
    if (!await repoRootDir.exists()) {
      throw MiniProgramScaffoldException(
        'Repo root does not exist: $normalizedRepoRoot',
      );
    }

    final miniProgramsRootPath = p.join(normalizedRepoRoot, 'mini_programs');
    final miniProgramsRootDir = Directory(miniProgramsRootPath);
    if (!await miniProgramsRootDir.exists()) {
      throw MiniProgramScaffoldException(
        'Repo root is missing mini_programs/: $normalizedRepoRoot',
      );
    }

    return p.join(miniProgramsRootPath, miniProgramId);
  }

  List<String> _normalizeCapabilities(Set<String> rawCapabilities) {
    final normalized = rawCapabilities
        .map((capability) => capability.trim())
        .where((capability) => capability.isNotEmpty)
        .toSet();

    if (normalized.isEmpty) {
      throw const MiniProgramScaffoldException(
        'At least one capability must be selected.',
      );
    }

    final unknownCapabilities =
        normalized
            .where((capability) => !_knownCapabilities.contains(capability))
            .toList()
          ..sort();

    if (unknownCapabilities.isNotEmpty) {
      throw MiniProgramScaffoldException(
        'Unknown capability values: ${unknownCapabilities.join(', ')}',
      );
    }

    final ordered = _scaffoldCapabilityOrder
        .where(normalized.contains)
        .toList();

    return ordered;
  }

  String? _normalizeBackendTemplate(String? rawTemplate) {
    final template = rawTemplate?.trim();
    if (template == null || template.isEmpty) {
      return null;
    }
    if (template != 'mock') {
      throw MiniProgramScaffoldException(
        'Unsupported backend starter template: $rawTemplate',
      );
    }
    return template;
  }

  String _normalizeScreenFormat(String rawScreenFormat) {
    final screenFormat = rawScreenFormat.trim();
    if (screenFormat == MiniProgramScreenFormats.mp) {
      return screenFormat;
    }

    throw MiniProgramScaffoldException(
      'Unsupported screen format: $rawScreenFormat',
    );
  }

  String _normalizeTitle(String? rawTitle, String miniProgramId) {
    if (rawTitle != null && rawTitle.trim().isNotEmpty) {
      return rawTitle.trim();
    }

    return miniProgramId
        .split('_')
        .where((segment) => segment.isNotEmpty)
        .map(
          (segment) =>
              '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _normalizeDescription(String? rawDescription, String title) {
    if (rawDescription != null && rawDescription.trim().isNotEmpty) {
      return rawDescription.trim();
    }

    return 'Portable $title mini-program.';
  }

  Future<bool> _directoryHasEntries(Directory directory) async {
    await for (final _ in directory.list(followLinks: false)) {
      return true;
    }

    return false;
  }

  Future<Map<String, String>> _buildMpManagedFiles({
    required String miniProgramRootPath,
    required String miniProgramId,
    required String title,
    required String description,
    required List<String> capabilities,
    required String entryScreenId,
    required String detailsScreenId,
    required String packageName,
    required bool withMockBackend,
  }) async {
    final homeFunctionName = 'build${_toPascalCase(miniProgramId)}Home';
    final detailsFunctionName = 'build${_toPascalCase(miniProgramId)}Details';
    final miniProgramUiDependency = await _resolveMiniProgramUiDependency();
    final dependencyOverrides = await _resolveMiniProgramDependencyOverrides();

    return <String, String>{
      p.join(miniProgramRootPath, 'manifest.json'): _buildManifestJson(
        miniProgramId: miniProgramId,
        capabilities: capabilities,
        entryScreenId: entryScreenId,
        screenFormat: MiniProgramScreenFormats.mp,
      ),
      p.join(miniProgramRootPath, 'README.md'): _buildMpReadme(
        miniProgramId: miniProgramId,
        title: title,
        description: description,
        capabilities: capabilities,
        entryScreenId: entryScreenId,
        withMockBackend: withMockBackend,
      ),
      p.join(miniProgramRootPath, 'pubspec.yaml'): _buildMpPubspec(
        packageName: packageName,
        title: title,
        miniProgramUiDependency: miniProgramUiDependency,
        dependencyOverrides: dependencyOverrides,
      ),
      p.join(miniProgramRootPath, '.gitignore'): _buildGitignore(),
      p.join(miniProgramRootPath, 'tool', 'build_mp.dart'):
          _buildMpBuildScript(),
      p.join(miniProgramRootPath, 'mp', 'program.dart'): _buildMpProgram(
        entryScreenId: entryScreenId,
        detailsScreenId: detailsScreenId,
        homeFunctionName: homeFunctionName,
        detailsFunctionName: detailsFunctionName,
      ),
      p.join(
        miniProgramRootPath,
        'mp',
        'screens',
        '$entryScreenId.dart',
      ): _buildMpHomeScreen(
        title: title,
        capabilities: capabilities,
        detailsScreenId: detailsScreenId,
        homeFunctionName: homeFunctionName,
        withMockBackend: withMockBackend,
      ),
      p.join(
        miniProgramRootPath,
        'mp',
        'screens',
        '$detailsScreenId.dart',
      ): _buildMpDetailsScreen(
        title: title,
        detailsFunctionName: detailsFunctionName,
      ),
      p.join(miniProgramRootPath, 'assets', '.gitkeep'): '',
    };
  }

  String _buildManifestJson({
    required String miniProgramId,
    required List<String> capabilities,
    required String entryScreenId,
    required String screenFormat,
  }) {
    final usesSecureApi = capabilities.contains(CapabilityIds.secureApi);
    final manifest = <String, dynamic>{
      'id': miniProgramId,
      'version': '1.0.0',
      'entry': entryScreenId,
      'contractVersion': '1.0.0',
      'sdkVersionRange': '>=1.0.0 <2.0.0',
      'requiredCapabilities': capabilities,
      'screenFormat': MiniProgramScreenFormats.mp,
      'screenSchemaVersion': 1,
      'cachePolicy': usesSecureApi
          ? <String, dynamic>{
              'manifest': <String, dynamic>{'mode': 'noCache'},
              'entryScreen': <String, dynamic>{'mode': 'noCache'},
            }
          : <String, dynamic>{
              'manifest': <String, dynamic>{
                'mode': 'staleWhileError',
                'maxStaleSeconds': 86400,
              },
              'entryScreen': <String, dynamic>{
                'mode': 'staleWhileError',
                'maxStaleSeconds': 21600,
              },
            },
      'fallback': <String, dynamic>{
        'strategy': 'errorView',
        'message':
            '$miniProgramId is temporarily unavailable in this host app.',
      },
    };

    return const JsonEncoder.withIndent('  ').convert(manifest);
  }

  Future<String> _resolveMiniProgramUiDependency() async {
    final toolingUri = await Isolate.resolvePackageUri(
      Uri.parse('package:mini_program_tooling/mini_program_tooling.dart'),
    );
    if (toolingUri != null && toolingUri.isScheme('file')) {
      final toolingPackageRoot = p.dirname(p.dirname(toolingUri.toFilePath()));
      final candidate = p.normalize(
        p.join(p.dirname(toolingPackageRoot), 'mini_program_ui'),
      );
      if (await File(p.join(candidate, 'pubspec.yaml')).exists()) {
        return '''
  mini_program_ui:
    path: ${_yamlSingleQuote(candidate)}
''';
      }
    }

    return '''
  mini_program_ui: ^0.1.2
''';
  }

  Future<String> _resolveMiniProgramDependencyOverrides() async {
    final toolingUri = await Isolate.resolvePackageUri(
      Uri.parse('package:mini_program_tooling/mini_program_tooling.dart'),
    );
    if (toolingUri == null || !toolingUri.isScheme('file')) {
      return '';
    }

    final toolingPackageRoot = p.dirname(p.dirname(toolingUri.toFilePath()));
    final contractsPath = p.normalize(
      p.join(p.dirname(toolingPackageRoot), 'mini_program_contracts'),
    );
    if (!await File(p.join(contractsPath, 'pubspec.yaml')).exists()) {
      return '';
    }

    return '''

dependency_overrides:
  mini_program_contracts:
    path: ${_yamlSingleQuote(contractsPath)}
''';
  }

  String _yamlSingleQuote(String value) => "'${value.replaceAll("'", "''")}'";

  String _buildMpPubspec({
    required String packageName,
    required String title,
    required String miniProgramUiDependency,
    required String dependencyOverrides,
  }) =>
      '''
name: $packageName
description: Portable Mp-authored $title mini-program.
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.10.0

dependencies:
$miniProgramUiDependency
dev_dependencies:
  lints: ^6.0.0
$dependencyOverrides
''';

  String _buildMpBuildScript() => '''
import 'package:mini_program_ui/mini_program_ui.dart';

import '../mp/program.dart';

Future<void> main(List<String> arguments) async {
  await writeMpBuildOutput(miniProgram, arguments: arguments);
}
''';

  String _buildMpProgram({
    required String entryScreenId,
    required String detailsScreenId,
    required String homeFunctionName,
    required String detailsFunctionName,
  }) =>
      '''
import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/$detailsScreenId.dart';
import 'screens/$entryScreenId.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    '$entryScreenId': $homeFunctionName,
    '$detailsScreenId': $detailsFunctionName,
  },
);
''';

  String _buildMpHomeScreen({
    required String title,
    required List<String> capabilities,
    required String detailsScreenId,
    required String homeFunctionName,
    required bool withMockBackend,
  }) {
    final capabilitiesLabel = capabilities.join(', ');
    return '''
import 'package:mini_program_ui/mini_program_ui.dart';

MpNode $homeFunctionName() {
  return Mp.column(
    children: <MpNode>[
      Mp.heading('$title profile starter'),
      Mp.text(
        'Start from a lightweight Mp JSON flow. Replace this copy and data '
        'shape with your business case, then publish the same JSON to Firebase, '
        'AWS, GitHub, or any static delivery host.',
      ),
      Mp.sizedBox(height: 12),
      Mp.card(
        child: Mp.column(
          children: <MpNode>[
            Mp.text('Starter capabilities: $capabilitiesLabel'),
          ],
        ),
      ),
${withMockBackend ? _buildMpBackendUiSection() : ''}
      Mp.heading('Publisher account'),
      Mp.authBuilder(
        loading: Mp.text('Checking saved sign-in...'),
        signedOut: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.text('Sign in to unlock protected publisher data.'),
              Mp.primaryButton(
                label: 'Sign in with email',
                action: Mp.auth.showEmailAuth(),
              ),
            ],
          ),
        ),
        signedIn: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.text('Signed in as {{auth.user.email}}'),
              Mp.secondaryButton(
                label: 'Sign out',
                action: Mp.auth.signOut(),
              ),
            ],
          ),
        ),
        error: Mp.text('{{auth.message}}'),
      ),
      Mp.card(
        child: Mp.column(
          children: <MpNode>[
            Mp.heading('Preview User'),
            Mp.text('Email: preview.user@example.com'),
            Mp.text('Tier: $title starter'),
            Mp.text('Status: Ready for your real profile fields'),
          ],
        ),
      ),
      Mp.primaryButton(
        label: 'Open profile details',
        action: Mp.navigation.openScreen('$detailsScreenId'),
      ),
      Mp.text(
        'Keep the default starter simple: one internal route from home to '
        'details, then grow the flow around your real use case.',
      ),
    ],
  );
}
''';
  }

  String _buildMpBackendUiSection() => '''
      Mp.heading('Publisher backend data'),
      Mp.backendBuilder(
        requestId: 'home',
        endpoint: 'home/bootstrap',
        cacheTtlSeconds: 60,
        loading: Mp.text('Loading backend home data...'),
        error: Mp.text('{{backend.home.message}}'),
        child: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.image(src: '{{backend.home.data.imageUrl}}'),
              Mp.heading('{{backend.home.data.title}}'),
              Mp.text('{{backend.home.data.subtitle}}'),
              Mp.text('{{backend.home.data.user.summary}}'),
            ],
          ),
        ),
      ),
      Mp.heading('Paged coupons'),
      Mp.pagedBackendBuilder(
        requestId: 'coupons',
        endpoint: 'coupons/page',
        limit: 2,
        loading: Mp.text('Loading coupons...'),
        loadingMore: Mp.text('Loading more coupons...'),
        empty: Mp.text('No coupons yet.'),
        error: Mp.text('{{backend.coupons.message}}'),
        end: Mp.text('No more coupons.'),
        itemTemplate: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.image(src: '{{item.imageUrl}}'),
              Mp.heading('{{item.title}}'),
              Mp.text('{{item.description}}'),
            ],
          ),
        ),
        loadMore: Mp.secondaryButton(
          label: 'Load more coupons',
          action: Mp.backend.loadMore(requestId: 'coupons'),
        ),
      ),
''';

  String _buildMpDetailsScreen({
    required String title,
    required String detailsFunctionName,
  }) =>
      '''
import 'package:mini_program_ui/mini_program_ui.dart';

MpNode $detailsFunctionName() {
  return Mp.column(
    children: <MpNode>[
      Mp.heading('$title details'),
      Mp.text(
        'This screen proves Mp navigation without host app route code. Add '
        'real settings, claim history, support, or account details here.',
      ),
      Mp.card(
        child: Mp.column(
          children: <MpNode>[
            Mp.heading('Next customization'),
            Mp.text('Replace the preview copy with your production model.'),
          ],
        ),
      ),
      Mp.secondaryButton(
        label: 'Back',
        action: Mp.navigation.popScreen(),
      ),
    ],
  );
}
''';

  String _buildMpReadme({
    required String miniProgramId,
    required String title,
    required String description,
    required List<String> capabilities,
    required String entryScreenId,
    required bool withMockBackend,
  }) =>
      '''
# $miniProgramId

$description

## Generated Mp starter

- title: `$title`
- entry screen: `$entryScreenId`
- screen format: `mp`
- screen schema version: `1`
- required capabilities: `${capabilities.join(', ')}`

## Edit the mini-program

- `mp/program.dart` registers screens explicitly.
- `mp/screens/` contains author-written `Mp.*` Dart source.
- `tool/build_mp.dart` writes deterministic JSON under `mp/.build/screens/`.
- `assets/` contains local static assets for preview and publish.
${withMockBackend ? '- `backend/mock/` contains a local publisher backend starter.' : ''}

## Build

```powershell
miniprogram build --mini-program-root .
```

Expected output:

```text
mp/.build/screens/$entryScreenId.json
```

## Preview

```powershell
miniprogram preview -d chrome --mini-program-root .
```

## Validate

```powershell
miniprogram validate --mini-program-root .
```

Mp screens use provider-neutral backend, auth, paging, and navigation helpers.
Keep backend endpoints relative, never place backend secrets in Mp JSON, and use
publisher-owned Firebase/AWS/custom servers for protected data.
''';

  String _buildGitignore() => '''
.dart_tool/
.packages
.pub/
build/
mp/.build/
mp/.build/
*.log
''';

  Map<String, String> _buildMockBackendFiles({
    required String miniProgramRootPath,
    required String miniProgramId,
    required String title,
  }) {
    return buildMockPublisherBackendFiles(
      miniProgramRootPath: miniProgramRootPath,
      miniProgramId: miniProgramId,
      title: title,
    ).map(
      (relativePath, contents) => MapEntry(
        p.join(miniProgramRootPath, 'backend', 'mock', relativePath),
        contents,
      ),
    );
  }

  String _toPascalCase(String value) {
    final segments = value
        .split('_')
        .where((segment) => segment.isNotEmpty)
        .toList();

    if (segments.isEmpty) {
      return value;
    }

    return segments
        .map(
          (segment) =>
              '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
        )
        .join();
  }
}
