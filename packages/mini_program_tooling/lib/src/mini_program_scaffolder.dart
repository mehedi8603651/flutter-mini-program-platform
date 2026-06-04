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

    final managedFiles = screenFormat == MiniProgramScreenFormats.mp
        ? await _buildMpManagedFiles(
            miniProgramRootPath: miniProgramRootPath,
            miniProgramId: miniProgramId,
            title: title,
            description: description,
            capabilities: orderedCapabilities,
            entryScreenId: entryScreenId,
            detailsScreenId: detailsScreenId,
            packageName: packageName,
            withMockBackend: withMockBackend,
          )
        : _buildStacManagedFiles(
            miniProgramRootPath: miniProgramRootPath,
            miniProgramId: miniProgramId,
            title: title,
            description: description,
            capabilities: orderedCapabilities,
            entryScreenId: entryScreenId,
            detailsScreenId: detailsScreenId,
            packageName: packageName,
            isStandalone: request.outputRootPath != null,
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
    if (screenFormat == MiniProgramScreenFormats.mp ||
        screenFormat == MiniProgramScreenFormats.stac) {
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

  Map<String, String> _buildStacManagedFiles({
    required String miniProgramRootPath,
    required String miniProgramId,
    required String title,
    required String description,
    required List<String> capabilities,
    required String entryScreenId,
    required String detailsScreenId,
    required String packageName,
    required bool isStandalone,
    required bool withMockBackend,
  }) {
    final screenFunctionName = '${_toLowerCamelCase(miniProgramId)}Home';
    return <String, String>{
      p.join(miniProgramRootPath, 'manifest.json'): _buildManifestJson(
        miniProgramId: miniProgramId,
        capabilities: capabilities,
        entryScreenId: entryScreenId,
        screenFormat: MiniProgramScreenFormats.stac,
      ),
      p.join(miniProgramRootPath, 'README.md'): _buildReadme(
        miniProgramId: miniProgramId,
        title: title,
        description: description,
        capabilities: capabilities,
        entryScreenId: entryScreenId,
        isStandalone: isStandalone,
        withMockBackend: withMockBackend,
      ),
      p.join(miniProgramRootPath, 'pubspec.yaml'): _buildPubspec(
        packageName: packageName,
        title: title,
      ),
      p.join(miniProgramRootPath, '.gitignore'): _buildGitignore(),
      p.join(miniProgramRootPath, 'lib', 'default_stac_options.dart'):
          _buildDefaultStacOptions(miniProgramId: miniProgramId, title: title),
      p.join(miniProgramRootPath, 'lib', 'host_action_helpers.dart'):
          _buildHostActionHelpers(),
      p.join(
        miniProgramRootPath,
        'stac',
        'screens',
        '$entryScreenId.dart',
      ): _buildStarterScreen(
        miniProgramId: miniProgramId,
        title: title,
        capabilities: capabilities,
        entryScreenId: entryScreenId,
        detailsScreenId: detailsScreenId,
        screenFunctionName: screenFunctionName,
        packageName: packageName,
        withMockBackend: withMockBackend,
      ),
      p.join(
        miniProgramRootPath,
        'stac',
        'screens',
        '$detailsScreenId.dart',
      ): _buildDetailsScreen(
        miniProgramId: miniProgramId,
        title: title,
        capabilities: capabilities,
        detailsScreenId: detailsScreenId,
        screenFunctionName: '${_toLowerCamelCase(miniProgramId)}Details',
        packageName: packageName,
      ),
      p.join(miniProgramRootPath, 'stac', 'components', '.gitkeep'): '',
      p.join(miniProgramRootPath, 'stac', 'theme', '.gitkeep'): '',
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
    final isMp = screenFormat == MiniProgramScreenFormats.mp;
    final manifest = <String, dynamic>{
      'id': miniProgramId,
      'version': '1.0.0',
      'entry': entryScreenId,
      'contractVersion': '1.0.0',
      'sdkVersionRange': '>=1.0.0 <2.0.0',
      'requiredCapabilities': capabilities,
      if (isMp) ...<String, dynamic>{
        'screenFormat': MiniProgramScreenFormats.mp,
        'screenSchemaVersion': 1,
      },
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
  mini_program_ui: ^0.1.0-dev.3
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

  String _buildPubspec({required String packageName, required String title}) =>
      '''
name: $packageName
description: Portable Stac-authored $title mini-program.
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.10.0

dependencies:
  stac_core: ^1.4.0

dev_dependencies:
  lints: ^6.0.0
''';

  String _buildGitignore() => '''
.dart_tool/
.packages
.pub/
build/
stac/.build/
mp/.build/
*.log
''';

  String _buildDefaultStacOptions({
    required String miniProgramId,
    required String title,
  }) =>
      '''
import 'package:stac_core/stac_core.dart';

StacOptions get defaultStacOptions => const StacOptions(
  name: '$miniProgramId',
  description: 'Portable $title mini-program',
  projectId: '${miniProgramId}_local',
  sourceDir: 'stac',
  outputDir: 'stac/.build',
);
''';

  String _buildReadme({
    required String miniProgramId,
    required String title,
    required String description,
    required List<String> capabilities,
    required String entryScreenId,
    required bool isStandalone,
    required bool withMockBackend,
  }) {
    final notes = <String>[
      '- edit `manifest.json` before publish',
      '- replace the starter copy under `stac/screens/` with your real portable flow',
      '- use `lib/host_action_helpers.dart` for readable host and mini-program action helpers instead of hand-writing raw `jsonData` maps',
      '- the scaffold starts with a realistic `home` + `details` profile/settings flow instead of a route playground',
      '- advanced portable route helpers stay in `lib/host_action_helpers.dart` and are shown as commented examples in the generated screens and below in this README',
      '- add reusable UI blocks under `stac/components/` as the flow grows',
    ];

    if (withMockBackend) {
      notes.add(
        '- mock publisher backend starter is enabled; run '
        '`miniprogram publisher-backend run --port 9090` and connect hosts '
        'with `--backend-base-url http://127.0.0.1:9090/`',
      );
    }

    if (capabilities.contains(CapabilityIds.nativeNavigation)) {
      notes.add(
        '- `native_navigation` is enabled, but the scaffold does not call any '
        'host-owned route by default; add `hostOpenNativeScreenAction(...)` '
        'only after your real host route alias and payload contract are defined',
      );
    }

    if (capabilities.contains(CapabilityIds.secureApi)) {
      notes.add(
        '- `secure_api` is enabled, but the scaffold does not call a backend '
        'endpoint by default; add `hostCallSecureApiAction(...)` only after '
        'your real allowlisted endpoint and payload contract are defined',
      );
    }

    return '''
# $miniProgramId

$description

## Generated starter

- title: `$title`
- entry screen: `$entryScreenId`
- required capabilities: `${capabilities.join(', ')}`

## Start here

${notes.join('\n')}

## Generated structure

- `assets/`
- `lib/default_stac_options.dart`
- `lib/host_action_helpers.dart`
- `manifest.json`
- `pubspec.yaml`
- `stac/screens/$entryScreenId.dart`
- `stac/screens/${miniProgramId}_details.dart`
- `stac/components/`
- `stac/theme/`
${withMockBackend ? '- `backend/mock/` local publisher backend starter' : ''}

## Portable route helpers

Keep the visible starter UI simple. When your mini-program really needs more
stack control, uncomment or adapt these helpers from
`lib/host_action_helpers.dart`:

- `openMiniProgramScreenAction(...)`
- `replaceMiniProgramScreenAction(...)`
- `resetMiniProgramStackAction(...)`
- `popMiniProgramScreenAction(...)`
- `popToMiniProgramRootAction(...)`
- `popToMiniProgramScreenAction(...)`

Example snippet:

```dart
// Example only: replace the current screen with a follow-up step.
StacOutlinedButton(
  onPressed: replaceMiniProgramScreenAction(
    requestId: '$miniProgramId-replace-follow-up',
    screenId: '${miniProgramId}_details',
  ),
  child: StacText(data: 'Replace with follow-up'),
)
```

## Publisher backend helpers

Use `miniProgramBackendBuilder(...)` when this mini-program needs to lazily load
JSON from its own publisher-owned Firebase, AWS, or custom server and bind simple
UI values without host app custom code:

```dart
miniProgramBackendBuilder(
  requestId: '$miniProgramId-home',
  endpoint: 'home/bootstrap',
  cacheTtl: const Duration(seconds: 60),
  loading: StacText(data: 'Loading...'),
  error: StacText(data: '{{backend.$miniProgramId-home.message}}'),
  child: StacColumn(
    children: [
      StacText(data: '{{backend.$miniProgramId-home.data.title}}'),
    ],
  ),
)
```

For repeated item templates:

```dart
miniProgramBackendBuilder(
  requestId: '$miniProgramId-coupons',
  endpoint: 'coupons/list',
  itemsPath: 'data.coupons',
  empty: StacText(data: 'No coupons yet'),
  itemTemplate: StacText(data: '{{item.title}}'),
)
```

For large lists, use the SDK-native paged builder with a manual Load more
button. The generated Firebase, AWS, and mock publisher backend starters expose
`GET /coupons/page` with the provider-neutral response shape
`{ "items": [], "nextCursor": null, "hasMore": false }`:

```dart
miniProgramPagedBackendBuilder(
  requestId: '$miniProgramId-coupon-pages',
  endpoint: 'coupons/page',
  limit: 20,
  itemTemplate: StacText(data: '{{item.title}}'),
  loadMore: StacOutlinedButton(
    onPressed: miniProgramLoadMore(requestId: '$miniProgramId-coupon-pages'),
    child: StacText(data: 'Load more'),
  ),
)
```

Use `miniProgramBackendQueryAction(...)` when a button should refresh the same
state:

```dart
miniProgramBackendQueryAction(
  requestId: '$miniProgramId-load-home',
  endpoint: 'home/bootstrap',
  forceRefresh: true,
)
```

Use `miniProgramBackendAction(...)` only when you need a fire-and-return backend
call without storing state for bindings:

```dart
miniProgramBackendAction(
  requestId: '$miniProgramId-track-impression',
  endpoint: 'analytics/impression',
  cacheTtl: const Duration(seconds: 60),
)
```

Keep `endpoint` relative. Do not put backend secrets in mini-program JSON,
Flutter source, APK, IPA, or web JavaScript. Secrets stay on the publisher
server; the host endpoint config only stores the publisher backend base URL.
Prefer batch endpoints like `home/bootstrap`, CDN image URLs, short timeouts,
and explicit cache TTLs only for safe `GET` responses.

## Build

Before your first local build, verify prerequisites and initialize the local
tooling state:

```powershell
miniprogram doctor
miniprogram backend init
miniprogram env init
```

Then build with the global CLI:

```powershell
miniprogram build $miniProgramId
```

Normal builds use the managed pinned Stac builder bundled inside
`mini_program_tooling`. Keep `--stac-cli-script` only when you intentionally
need to override that builder.

Expected output:

```text
stac/.build/screens/$entryScreenId.json
```

## Validate

```powershell
miniprogram validate $miniProgramId
```

## Publish local backend sample

```powershell
miniprogram publish $miniProgramId
```

## Test in a host

For a local proof:

1. start the backend:

```powershell
miniprogram backend start --port 8080
```

2. initialize a host app:

```powershell
cd <existing-flutter-app>
miniprogram embed init
```

Or, from another directory:

```powershell
miniprogram embed init --project-root <existing-flutter-app>
```
''';
  }

  String _buildStarterScreen({
    required String miniProgramId,
    required String title,
    required List<String> capabilities,
    required String entryScreenId,
    required String detailsScreenId,
    required String screenFunctionName,
    required String packageName,
    required bool withMockBackend,
  }) {
    final widgets = <String>[
      '''
            StacText(
              data: '$title profile starter',
              style: StacCustomTextStyle(
                fontSize: 28,
                fontWeight: StacFontWeight.w700,
                color: '#1A202C',
              ),
            ),
            StacSizedBox(height: 12),
            StacText(
              data:
                  'Start from a realistic portable profile/settings flow. '
                  'Replace the copy and data shape with your business case, '
                  'then add host-specific work only after the contract is real.',
            ),
            StacSizedBox(height: 16),
            StacContainer(
              padding: StacEdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: StacBoxDecoration(
                color: '#E0F2FE',
                borderRadius: StacBorderRadius.all(18),
              ),
              child: StacText(
                data: 'Starter capabilities: ${capabilities.join(', ')}',
                style: StacCustomTextStyle(
                  fontSize: 15,
                  fontWeight: StacFontWeight.w600,
                  color: '#0C4A6E',
                ),
              ),
            ),
            StacSizedBox(height: 20),
${withMockBackend ? _buildMockBackendUiSection() : ''}
${_buildStarterProfileCard(title)}
            StacSizedBox(height: 16),
${_buildStarterChecklistCard()}
            StacSizedBox(height: 24),
            StacFilledButton(
              onPressed: openMiniProgramScreenAction(
                requestId: '$miniProgramId-open-details',
                screenId: '$detailsScreenId',
              ),
              child: StacText(data: 'Open profile details'),
            ),
            StacSizedBox(height: 8),
            StacText(
              data:
                  'Keep the default starter simple: one internal route from '
                  'home to details, then grow the flow around your real use case.',
            ),
${_buildHomeRouteExamplesComment(miniProgramId: miniProgramId, detailsScreenId: detailsScreenId)}
            StacSizedBox(height: 16),
''',
    ];

    if (capabilities.contains(CapabilityIds.analytics)) {
      widgets.add(_buildTrackEventButton(miniProgramId));
    }

    return '''
import 'package:stac_core/stac_core.dart';
import 'package:$packageName/host_action_helpers.dart';

@StacScreen(screenName: '$entryScreenId')
StacWidget $screenFunctionName() {
  return StacScaffold(
    appBar: StacAppBar(title: StacText(data: '$title')),
    body: StacSingleChildScrollView(
      padding: StacEdgeInsets.symmetric(horizontal: 24),
      child: StacColumn(
        crossAxisAlignment: StacCrossAxisAlignment.start,
        children: [
${widgets.join()}
        ],
      ),
    ),
  );
}
''';
  }

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

  String _buildMockBackendUiSection() => '''
            StacText(
              data: 'Publisher backend data',
              style: StacCustomTextStyle(
                fontSize: 20,
                fontWeight: StacFontWeight.w700,
                color: '#1A202C',
              ),
            ),
            StacSizedBox(height: 8),
            miniProgramBackendBuilder(
              requestId: 'home',
              endpoint: 'home/bootstrap',
              cacheTtl: const Duration(seconds: 60),
              loading: StacText(data: 'Loading backend home data...'),
              error: StacText(data: '{{backend.home.message}}'),
              child: StacContainer(
                padding: StacEdgeInsets.all(14),
                decoration: StacBoxDecoration(
                  color: '#F8FAFC',
                  border: StacBorder.all(color: '#D7E3DD'),
                  borderRadius: StacBorderRadius.all(16),
                ),
                child: StacColumn(
                  crossAxisAlignment: StacCrossAxisAlignment.start,
                  children: [
                    StacText(
                      data: '{{backend.home.data.title}}',
                      style: StacCustomTextStyle(
                        fontSize: 18,
                        fontWeight: StacFontWeight.w700,
                        color: '#0F172A',
                      ),
                    ),
                    StacSizedBox(height: 6),
                    StacText(data: '{{backend.home.data.subtitle}}'),
                    StacSizedBox(height: 6),
                    StacText(
                      data:
                          'Signed in as {{backend.home.data.user.name}} · {{backend.home.data.user.tier}}',
                    ),
                    StacSizedBox(height: 12),
                    StacOutlinedButton(
                      onPressed: miniProgramBackendQueryAction(
                        requestId: 'home',
                        endpoint: 'home/bootstrap',
                        forceRefresh: true,
                      ),
                      child: StacText(data: 'Refresh backend data'),
                    ),
                  ],
                ),
              ),
            ),
            StacSizedBox(height: 16),
            miniProgramPagedBackendBuilder(
              requestId: 'coupons',
              endpoint: 'coupons/page',
              limit: 2,
              cacheTtl: const Duration(seconds: 60),
              loading: StacText(data: 'Loading coupons...'),
              loadingMore: StacText(data: 'Loading more coupons...'),
              error: StacText(data: '{{backend.coupons.message}}'),
              empty: StacText(data: 'No coupons yet'),
              end: StacText(data: 'All coupons loaded'),
              loadMore: StacOutlinedButton(
                onPressed: miniProgramLoadMore(requestId: 'coupons'),
                child: StacText(data: 'Load more coupons'),
              ),
              itemTemplate: StacContainer(
                margin: StacEdgeInsets.only(bottom: 10),
                padding: StacEdgeInsets.all(12),
                decoration: StacBoxDecoration(
                  color: '#FFFFFF',
                  border: StacBorder.all(color: '#E2E8F0'),
                  borderRadius: StacBorderRadius.all(14),
                ),
                child: StacRow(
                  crossAxisAlignment: StacCrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    StacImage.network(
                      '{{item.imageUrl}}',
                      width: 86,
                      height: 64,
                      fit: StacBoxFit.cover,
                    ),
                    StacExpanded(
                      child: StacColumn(
                        crossAxisAlignment: StacCrossAxisAlignment.start,
                        children: [
                          StacText(
                            data: '{{item.title}}',
                            style: StacCustomTextStyle(
                              fontSize: 16,
                              fontWeight: StacFontWeight.w700,
                              color: '#111827',
                            ),
                          ),
                          StacSizedBox(height: 4),
                          StacText(data: '{{item.description}}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            StacSizedBox(height: 20),
''';

  String _buildDetailsScreen({
    required String miniProgramId,
    required String title,
    required List<String> capabilities,
    required String detailsScreenId,
    required String screenFunctionName,
    required String packageName,
  }) {
    final widgets = <String>[
      '''
            StacText(
              data: '$title details',
              style: StacCustomTextStyle(
                fontSize: 26,
                fontWeight: StacFontWeight.w700,
                color: '#1A202C',
              ),
            ),
            StacSizedBox(height: 12),
            StacText(
              data:
                  'Use this second screen as a realistic details or settings page. '
                  'Keep the starter polished first, then layer deeper routing only '
                  'when the real flow needs it.',
            ),
            StacSizedBox(height: 20),
${_buildDetailsSectionCard(title: 'Account snapshot', backgroundColor: '#FFFFFF', borderColor: '#E2E8F0', lines: const <String>['Full name: Preview User', 'Primary email: preview.user@example.com', 'Member tier: Ready for customization'])}
            StacSizedBox(height: 16),
${_buildDetailsSectionCard(title: 'Preferences starter block', backgroundColor: '#F8FAFC', borderColor: '#D7E3DD', lines: const <String>['Marketing updates: Enabled placeholder', 'Language: English', 'Support lane: Portable mini-program preview'])}
            StacSizedBox(height: 20),
            StacOutlinedButton(
              onPressed: popMiniProgramScreenAction(
                requestId: '$miniProgramId-pop-home',
              ),
              child: StacText(data: 'Back to profile home'),
            ),
            StacSizedBox(height: 8),
            StacText(
              data:
                  'This keeps the default starter easy to understand. Add more '
                  'portable route helpers only when the flow truly needs them.',
            ),
${_buildDetailsRouteExamplesComment(miniProgramId: miniProgramId, detailsScreenId: detailsScreenId)}
''',
    ];

    if (capabilities.contains(CapabilityIds.nativeNavigation)) {
      widgets.add(_buildNativeNavigationCapabilityNote());
    }

    if (capabilities.contains(CapabilityIds.secureApi)) {
      widgets.add(_buildSecureApiCapabilityNote());
    }

    return '''
import 'package:stac_core/stac_core.dart';
import 'package:$packageName/host_action_helpers.dart';

@StacScreen(screenName: '${miniProgramId}_details')
StacWidget $screenFunctionName() {
  return StacScaffold(
    appBar: StacAppBar(title: StacText(data: '$title details')),
    body: StacSingleChildScrollView(
      padding: StacEdgeInsets.symmetric(horizontal: 24),
      child: StacColumn(
        crossAxisAlignment: StacCrossAxisAlignment.start,
        children: [
${widgets.join()}
        ],
      ),
    ),
  );
}
''';
  }

  String _buildHostActionHelpers() => '''
import 'package:stac_core/stac_core.dart';

/// Author-friendly wrappers around serializable host and mini-program actions.
StacAction openMiniProgramScreenAction({
  required String requestId,
  required String screenId,
}) {
  return StacAction(
    jsonData: <String, dynamic>{
      'actionType': 'miniProgramNavigation',
      'requestId': requestId,
      'action': 'openMiniProgramScreen',
      'payload': <String, dynamic>{'screenId': screenId},
    },
  );
}

StacAction resetMiniProgramStackAction({
  required String requestId,
  required String screenId,
}) {
  return StacAction(
    jsonData: <String, dynamic>{
      'actionType': 'miniProgramNavigation',
      'requestId': requestId,
      'action': 'resetMiniProgramStack',
      'payload': <String, dynamic>{'screenId': screenId},
    },
  );
}

StacAction replaceMiniProgramScreenAction({
  required String requestId,
  required String screenId,
}) {
  return StacAction(
    jsonData: <String, dynamic>{
      'actionType': 'miniProgramNavigation',
      'requestId': requestId,
      'action': 'replaceMiniProgramScreen',
      'payload': <String, dynamic>{'screenId': screenId},
    },
  );
}

StacAction popMiniProgramScreenAction({
  required String requestId,
}) {
  return StacAction(
    jsonData: <String, dynamic>{
      'actionType': 'miniProgramNavigation',
      'requestId': requestId,
      'action': 'popMiniProgramScreen',
      'payload': const <String, dynamic>{},
    },
  );
}

StacAction popToMiniProgramRootAction({
  required String requestId,
}) {
  return StacAction(
    jsonData: <String, dynamic>{
      'actionType': 'miniProgramNavigation',
      'requestId': requestId,
      'action': 'popToMiniProgramRoot',
      'payload': const <String, dynamic>{},
    },
  );
}

StacAction popToMiniProgramScreenAction({
  required String requestId,
  required String screenId,
}) {
  return StacAction(
    jsonData: <String, dynamic>{
      'actionType': 'miniProgramNavigation',
      'requestId': requestId,
      'action': 'popToMiniProgramScreen',
      'payload': <String, dynamic>{'screenId': screenId},
    },
  );
}

StacAction hostTrackEventAction({
  required String requestId,
  required String name,
  Map<String, dynamic> properties = const <String, dynamic>{},
}) {
  return StacAction(
    jsonData: <String, dynamic>{
      'actionType': 'hostAction',
      'requestId': requestId,
      'action': 'trackEvent',
      'payload': <String, dynamic>{
        'name': name,
        'properties': properties,
      },
    },
  );
}

StacAction hostOpenNativeScreenAction({
  required String requestId,
  required String route,
  Map<String, dynamic> args = const <String, dynamic>{},
  bool expectResult = false,
}) {
  return StacAction(
    jsonData: <String, dynamic>{
      'actionType': 'hostAction',
      'requestId': requestId,
      'action': 'openNativeScreen',
      'payload': <String, dynamic>{
        'route': route,
        'args': args,
        'expectResult': expectResult,
      },
    },
  );
}

StacAction hostCallSecureApiAction({
  required String requestId,
  required String endpoint,
  String method = 'POST',
  Map<String, dynamic> body = const <String, dynamic>{},
}) {
  return StacAction(
    jsonData: <String, dynamic>{
      'actionType': 'hostAction',
      'requestId': requestId,
      'action': 'callSecureApi',
      'payload': <String, dynamic>{
        'endpoint': endpoint,
        'method': method,
        'body': body,
      },
    },
  );
}

StacAction miniProgramBackendAction({
  required String requestId,
  required String endpoint,
  String method = 'GET',
  Map<String, dynamic> body = const <String, dynamic>{},
  Duration? cacheTtl,
}) {
  return StacAction(
    jsonData: <String, dynamic>{
      'actionType': 'miniProgramBackend',
      'requestId': requestId,
      'endpoint': endpoint,
      'method': method,
      if (body.isNotEmpty) 'body': body,
      if (cacheTtl != null) 'cacheTtlSeconds': cacheTtl.inSeconds,
    },
  );
}

StacAction miniProgramBackendQueryAction({
  required String requestId,
  required String endpoint,
  String method = 'GET',
  Map<String, dynamic> body = const <String, dynamic>{},
  Duration? cacheTtl,
  bool forceRefresh = false,
}) {
  return StacAction(
    jsonData: <String, dynamic>{
      'actionType': 'miniProgramBackendQuery',
      'requestId': requestId,
      'endpoint': endpoint,
      'method': method,
      if (body.isNotEmpty) 'body': body,
      if (cacheTtl != null) 'cacheTtlSeconds': cacheTtl.inSeconds,
      if (forceRefresh) 'forceRefresh': true,
    },
  );
}

StacWidget miniProgramBackendBuilder({
  required String requestId,
  required String endpoint,
  String method = 'GET',
  Map<String, dynamic> body = const <String, dynamic>{},
  Duration? cacheTtl,
  bool forceRefresh = false,
  StacWidget? loading,
  StacWidget? error,
  StacWidget? child,
  StacWidget? empty,
  StacWidget? itemTemplate,
  String? itemsPath,
}) {
  return StacWidget.fromJson(<String, dynamic>{
    'type': 'miniProgramBackendBuilder',
    'requestId': requestId,
    'endpoint': endpoint,
    'method': method,
    if (body.isNotEmpty) 'body': body,
    if (cacheTtl != null) 'cacheTtlSeconds': cacheTtl.inSeconds,
    if (forceRefresh) 'forceRefresh': true,
    if (loading != null) 'loading': loading.toJson(),
    if (error != null) 'error': error.toJson(),
    if (child != null) 'child': child.toJson(),
    if (empty != null) 'empty': empty.toJson(),
    if (itemTemplate != null) 'itemTemplate': itemTemplate.toJson(),
    if (itemsPath != null && itemsPath.trim().isNotEmpty)
      'itemsPath': itemsPath.trim(),
  });
}

StacWidget miniProgramPagedBackendBuilder({
  required String requestId,
  required String endpoint,
  required StacWidget itemTemplate,
  int limit = 20,
  String? initialCursor,
  String cursorParam = 'cursor',
  String limitParam = 'limit',
  String itemsPath = 'items',
  String nextCursorPath = 'nextCursor',
  String hasMorePath = 'hasMore',
  Duration? cacheTtl,
  bool forceRefresh = false,
  StacWidget? loading,
  StacWidget? loadingMore,
  StacWidget? error,
  StacWidget? empty,
  StacWidget? end,
  StacWidget? loadMore,
}) {
  return StacWidget.fromJson(<String, dynamic>{
    'type': 'miniProgramPagedBackendBuilder',
    'requestId': requestId,
    'endpoint': endpoint,
    'itemTemplate': itemTemplate.toJson(),
    'limit': limit,
    if (initialCursor != null && initialCursor.trim().isNotEmpty)
      'initialCursor': initialCursor.trim(),
    'cursorParam': cursorParam,
    'limitParam': limitParam,
    'itemsPath': itemsPath,
    'nextCursorPath': nextCursorPath,
    'hasMorePath': hasMorePath,
    if (cacheTtl != null) 'cacheTtlSeconds': cacheTtl.inSeconds,
    if (forceRefresh) 'forceRefresh': true,
    if (loading != null) 'loading': loading.toJson(),
    if (loadingMore != null) 'loadingMore': loadingMore.toJson(),
    if (error != null) 'error': error.toJson(),
    if (empty != null) 'empty': empty.toJson(),
    if (end != null) 'end': end.toJson(),
    if (loadMore != null) 'loadMore': loadMore.toJson(),
  });
}

StacAction miniProgramLoadMore({required String requestId}) {
  return StacAction(
    jsonData: <String, dynamic>{
      'actionType': 'miniProgramLoadMore',
      'requestId': requestId,
    },
  );
}
''';

  String _buildTrackEventButton(String miniProgramId) =>
      '''
            StacOutlinedButton(
              onPressed: hostTrackEventAction(
                requestId: '$miniProgramId-track-open',
                name: '${miniProgramId}_opened',
                properties: const <String, dynamic>{
                  'source': '$miniProgramId',
                  'surface': '$miniProgramId',
                },
              ),
              child: StacText(data: 'Track profile opened event (logs only)'),
            ),
            StacSizedBox(height: 8),
            StacText(
              data:
                  'This starter analytics action only writes to the host log. '
                  'It does not change the UI.',
            ),
''';

  String _buildStarterProfileCard(String title) =>
      '''
            StacContainer(
              padding: StacEdgeInsets.all(18),
              decoration: StacBoxDecoration(
                color: '#FFFFFF',
                borderRadius: StacBorderRadius.all(20),
                border: StacBorder.all(color: '#E2E8F0'),
              ),
              child: StacColumn(
                crossAxisAlignment: StacCrossAxisAlignment.start,
                children: [
                  StacText(
                    data: 'Preview User',
                    style: StacCustomTextStyle(
                      fontSize: 20,
                      fontWeight: StacFontWeight.w600,
                      color: '#0F172A',
                    ),
                  ),
                  StacSizedBox(height: 8),
                  StacText(data: 'Email: preview.user@example.com'),
                  StacText(data: 'Tier: $title starter'),
                  StacText(data: 'Status: Ready for your real profile fields'),
                ],
              ),
            ),
''';

  String _buildStarterChecklistCard() => '''
            StacContainer(
              padding: StacEdgeInsets.all(18),
              decoration: StacBoxDecoration(
                color: '#F8FAFC',
                borderRadius: StacBorderRadius.all(20),
              ),
              child: StacColumn(
                crossAxisAlignment: StacCrossAxisAlignment.start,
                children: [
                  StacText(
                    data: 'What to customize next',
                    style: StacCustomTextStyle(
                      fontSize: 16,
                      fontWeight: StacFontWeight.w600,
                      color: '#0F172A',
                    ),
                  ),
                  StacSizedBox(height: 8),
                  StacText(
                    data: 'Replace the preview copy with your business content.',
                  ),
                  StacText(
                    data: 'Wire real profile values from your host-approved model.',
                  ),
                  StacText(
                    data:
                        'Add native or secure actions only after the host contract exists.',
                  ),
                ],
              ),
            ),
''';

  String _buildDetailsSectionCard({
    required String title,
    required String backgroundColor,
    required String borderColor,
    required List<String> lines,
  }) {
    final lineWidgets = lines
        .map((line) => "                  StacText(data: '$line'),")
        .join('\n');

    return '''
            StacContainer(
              padding: StacEdgeInsets.all(18),
              decoration: StacBoxDecoration(
                color: '$backgroundColor',
                borderRadius: StacBorderRadius.all(20),
                border: StacBorder.all(color: '$borderColor'),
              ),
              child: StacColumn(
                crossAxisAlignment: StacCrossAxisAlignment.start,
                children: [
                  StacText(
                    data: '$title',
                    style: StacCustomTextStyle(
                      fontSize: 16,
                      fontWeight: StacFontWeight.w600,
                      color: '#0F172A',
                    ),
                  ),
                  StacSizedBox(height: 8),
$lineWidgets
                ],
              ),
            ),
''';
  }

  String _buildHomeRouteExamplesComment({
    required String miniProgramId,
    required String detailsScreenId,
  }) =>
      '''
            // Advanced portable route examples stay commented by default:
            // StacOutlinedButton(
            //   onPressed: replaceMiniProgramScreenAction(
            //     requestId: '$miniProgramId-replace-details',
            //     screenId: '$detailsScreenId',
            //   ),
            //   child: StacText(data: 'Replace with details'),
            // ),
            //
            // StacOutlinedButton(
            //   onPressed: resetMiniProgramStackAction(
            //     requestId: '$miniProgramId-reset-details',
            //     screenId: '$detailsScreenId',
            //   ),
            //   child: StacText(data: 'Reset stack to details'),
            // ),
''';

  String _buildDetailsRouteExamplesComment({
    required String miniProgramId,
    required String detailsScreenId,
  }) =>
      '''
            // More stack-aware helpers live in host_action_helpers.dart:
            // popToMiniProgramRootAction(
            //   requestId: '$miniProgramId-pop-root',
            // )
            //
            // popToMiniProgramScreenAction(
            //   requestId: '$miniProgramId-pop-to-details',
            //   screenId: '$detailsScreenId',
            // )
''';

  String _buildNativeNavigationCapabilityNote() => '''
            StacSizedBox(height: 12),
            StacContainer(
              padding: StacEdgeInsets.all(16),
              decoration: StacBoxDecoration(
                color: '#F8FAFC',
                borderRadius: StacBorderRadius.all(18),
                border: StacBorder.all(color: '#D7E3DD'),
              ),
              child: StacColumn(
                crossAxisAlignment: StacCrossAxisAlignment.start,
                children: [
                  StacText(
                    data: 'Capability enabled: native_navigation',
                    style: StacCustomTextStyle(
                      fontSize: 16,
                      fontWeight: StacFontWeight.w600,
                      color: '#0F172A',
                    ),
                  ),
                  StacSizedBox(height: 8),
                  StacText(
                    data:
                        'This scaffold does not call a host route by default. '
                        'Add hostOpenNativeScreenAction(...) only after your '
                        'real host route alias and payload contract are defined.',
                  ),
                ],
              ),
            ),
''';

  String _buildSecureApiCapabilityNote() => '''
            StacSizedBox(height: 12),
            StacContainer(
              padding: StacEdgeInsets.all(16),
              decoration: StacBoxDecoration(
                color: '#FFF7ED',
                borderRadius: StacBorderRadius.all(18),
                border: StacBorder.all(color: '#FED7AA'),
              ),
              child: StacColumn(
                crossAxisAlignment: StacCrossAxisAlignment.start,
                children: [
                  StacText(
                    data: 'Capability enabled: secure_api',
                    style: StacCustomTextStyle(
                      fontSize: 16,
                      fontWeight: StacFontWeight.w600,
                      color: '#9A3412',
                    ),
                  ),
                  StacSizedBox(height: 8),
                  StacText(
                    data:
                        'This scaffold does not call a secure endpoint by default. '
                        'Add hostCallSecureApiAction(...) only after your real '
                        'allowlisted endpoint and payload contract are defined.',
                  ),
                ],
              ),
            ),
''';

  String _toLowerCamelCase(String value) {
    final segments = value
        .split('_')
        .where((segment) => segment.isNotEmpty)
        .toList();

    if (segments.isEmpty) {
      return value;
    }

    final first = segments.first.toLowerCase();
    final rest = segments
        .skip(1)
        .map(
          (segment) =>
              '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
        );

    return '$first${rest.join()}';
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
