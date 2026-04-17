import 'dart:convert';
import 'dart:io';

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as p;

class MiniProgramScaffoldRequest {
  const MiniProgramScaffoldRequest({
    required this.miniProgramId,
    this.repoRootPath,
    this.outputRootPath,
    this.title,
    this.description,
    this.capabilities = const <String>{'analytics', 'native_navigation'},
    this.force = false,
  });

  final String miniProgramId;
  final String? repoRootPath;
  final String? outputRootPath;
  final String? title;
  final String? description;
  final Set<String> capabilities;
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
    required this.createdPaths,
  });

  final String? repoRootPath;
  final String miniProgramRootPath;
  final String miniProgramId;
  final String title;
  final String description;
  final List<String> capabilities;
  final List<String> createdPaths;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'repoRootPath': repoRootPath,
    'miniProgramRootPath': miniProgramRootPath,
    'miniProgramId': miniProgramId,
    'title': title,
    'description': description,
    'capabilities': capabilities,
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

  static final Map<String, Capability> _knownCapabilities =
      Map<String, Capability>.fromEntries(
        Capability.values.map(
          (capability) => MapEntry(capability.wireValue, capability),
        ),
      );

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
    final routeDemoScreenId = '${miniProgramId}_route_demo';
    final screenFunctionName = '${_toLowerCamelCase(miniProgramId)}Home';
    final packageName = '${miniProgramId}_mini_program';

    final managedFiles = <String, String>{
      p.join(miniProgramRootPath, 'manifest.json'): _buildManifestJson(
        miniProgramId: miniProgramId,
        title: title,
        capabilities: orderedCapabilities,
        entryScreenId: entryScreenId,
      ),
      p.join(miniProgramRootPath, 'README.md'): _buildReadme(
        miniProgramId: miniProgramId,
        title: title,
        description: description,
        capabilities: orderedCapabilities,
        entryScreenId: entryScreenId,
        isStandalone: request.outputRootPath != null,
      ),
      p.join(miniProgramRootPath, 'pubspec.yaml'): _buildPubspec(
        packageName: packageName,
        title: title,
      ),
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
        capabilities: orderedCapabilities,
        entryScreenId: entryScreenId,
        detailsScreenId: detailsScreenId,
        routeDemoScreenId: routeDemoScreenId,
        screenFunctionName: screenFunctionName,
        packageName: packageName,
      ),
      p.join(
        miniProgramRootPath,
        'stac',
        'screens',
        '$detailsScreenId.dart',
      ): _buildDetailsScreen(
        miniProgramId: miniProgramId,
        title: title,
        capabilities: orderedCapabilities,
        routeDemoScreenId: routeDemoScreenId,
        screenFunctionName: '${_toLowerCamelCase(miniProgramId)}Details',
        packageName: packageName,
      ),
      p.join(
        miniProgramRootPath,
        'stac',
        'screens',
        '$routeDemoScreenId.dart',
      ): _buildRouteDemoScreen(
        miniProgramId: miniProgramId,
        title: title,
        detailsScreenId: detailsScreenId,
        routeDemoScreenId: routeDemoScreenId,
        screenFunctionName: '${_toLowerCamelCase(miniProgramId)}RouteDemo',
        packageName: packageName,
      ),
      p.join(miniProgramRootPath, 'stac', 'components', '.gitkeep'): '',
      p.join(miniProgramRootPath, 'stac', 'theme', '.gitkeep'): '',
      p.join(miniProgramRootPath, 'assets', '.gitkeep'): '',
    };

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
            .where((capability) => !_knownCapabilities.containsKey(capability))
            .toList()
          ..sort();

    if (unknownCapabilities.isNotEmpty) {
      throw MiniProgramScaffoldException(
        'Unknown capability values: ${unknownCapabilities.join(', ')}',
      );
    }

    final ordered = Capability.values
        .map((capability) => capability.wireValue)
        .where(normalized.contains)
        .toList();

    return ordered;
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

  String _buildManifestJson({
    required String miniProgramId,
    required String title,
    required List<String> capabilities,
    required String entryScreenId,
  }) {
    final usesSecureApi = capabilities.contains(Capability.secureApi.wireValue);
    final manifest = <String, dynamic>{
      'id': miniProgramId,
      'version': '1.0.0',
      'entry': entryScreenId,
      'contractVersion': '1.0.0',
      'sdkVersionRange': '>=1.0.0 <2.0.0',
      'requiredCapabilities': capabilities,
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
        'message': '$title is temporarily unavailable in this host app.',
      },
    };

    return const JsonEncoder.withIndent('  ').convert(manifest);
  }

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
  }) {
    final notes = <String>[
      '- edit `manifest.json` before publish',
      '- replace the starter copy under `stac/screens/` with your real portable flow',
      '- use `lib/host_action_helpers.dart` for readable host and mini-program action helpers instead of hand-writing raw `jsonData` maps',
      '- the scaffold now includes second and third screens so you can edit multi-step portable routing and stack-aware navigation by `screenId`',
      '- add reusable UI blocks under `stac/components/` as the flow grows',
    ];

    if (capabilities.contains(Capability.nativeNavigation.wireValue)) {
      notes.add(
        '- `native_navigation` is enabled, but the scaffold does not call any '
        'host-owned route by default; add `hostOpenNativeScreenAction(...)` '
        'only after your real host route alias and payload contract are defined',
      );
    }

    if (capabilities.contains(Capability.secureApi.wireValue)) {
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
- `stac/screens/${miniProgramId}_route_demo.dart`
- `stac/components/`
- `stac/theme/`

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
    required String routeDemoScreenId,
    required String screenFunctionName,
    required String packageName,
  }) {
    final widgets = <String>[
      '''
            StacText(
              data: '$title starter flow',
              style: StacCustomTextStyle(
                fontSize: 28,
                fontWeight: StacFontWeight.w700,
                color: '#1A202C',
              ),
            ),
            StacSizedBox(height: 12),
            StacText(
              data:
                  'Replace this generated starter screen with your portable '
                  'Stac DSL flow. Keep host-specific work behind approved '
                  'host actions and declared capabilities.',
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
            StacSizedBox(height: 24),
            StacFilledButton(
              onPressed: openMiniProgramScreenAction(
                requestId: '$miniProgramId-open-details',
                screenId: '$detailsScreenId',
              ),
              child: StacText(data: 'Continue to second screen'),
            ),
            StacSizedBox(height: 8),
            StacText(
              data:
                  'This starter button uses internal mini-program routing by screenId, '
                  'so you can build page-to-page portable flows without leaving the mini-program.',
            ),
            StacSizedBox(height: 16),
            StacOutlinedButton(
              onPressed: replaceMiniProgramScreenAction(
                requestId: '$miniProgramId-replace-route-demo',
                screenId: '$routeDemoScreenId',
              ),
              child: StacText(data: 'Replace with route demo screen'),
            ),
            StacSizedBox(height: 8),
            StacText(
              data:
                  'Use replace when the next step should take over the current '
                  'screen instead of adding another entry to the mini-program stack.',
            ),
            StacSizedBox(height: 16),
            StacOutlinedButton(
              onPressed: resetMiniProgramStackAction(
                requestId: '$miniProgramId-reset-route-demo',
                screenId: '$routeDemoScreenId',
              ),
              child: StacText(data: 'Reset stack to route demo'),
            ),
            StacSizedBox(height: 8),
            StacText(
              data:
                  'Use reset when a new step should become the fresh root of the '
                  'portable flow, such as after onboarding or a completed task.',
            ),
            StacSizedBox(height: 16),
''',
    ];

    if (capabilities.contains(Capability.analytics.wireValue)) {
      widgets.add(_buildTrackEventButton(miniProgramId));
    }

    if (widgets.length == 1) {
      widgets.add('''
            StacContainer(
              padding: StacEdgeInsets.all(16),
              decoration: StacBoxDecoration(
                color: '#F8FAFC',
                borderRadius: StacBorderRadius.all(18),
              ),
              child: StacText(
                data:
                    'No extra starter actions were generated on the first screen. '
                    'Use the generated route screens as a portable navigation '
                    'starting point, or replace them with your own business flow.',
              ),
            ),
''');
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

  String _buildDetailsScreen({
    required String miniProgramId,
    required String title,
    required List<String> capabilities,
    required String routeDemoScreenId,
    required String screenFunctionName,
    required String packageName,
  }) {
    final widgets = <String>[
      '''
            StacText(
              data: '$title second screen',
              style: StacCustomTextStyle(
                fontSize: 26,
                fontWeight: StacFontWeight.w700,
                color: '#1A202C',
              ),
            ),
            StacSizedBox(height: 12),
            StacText(
              data:
                  'This page was opened through internal mini-program routing. '
                  'Use it as the place to continue your portable multi-step flow.',
            ),
            StacSizedBox(height: 20),
            StacOutlinedButton(
              onPressed: popMiniProgramScreenAction(
                requestId: '$miniProgramId-pop-root',
              ),
              child: StacText(data: 'Back to first screen'),
            ),
            StacSizedBox(height: 12),
            StacOutlinedButton(
              onPressed: openMiniProgramScreenAction(
                requestId: '$miniProgramId-open-route-demo',
                screenId: '$routeDemoScreenId',
              ),
              child: StacText(data: 'Open route demo screen'),
            ),
            StacSizedBox(height: 12),
            StacOutlinedButton(
              onPressed: replaceMiniProgramScreenAction(
                requestId: '$miniProgramId-replace-route-demo-from-details',
                screenId: '$routeDemoScreenId',
              ),
              child: StacText(data: 'Replace with route demo screen'),
            ),
''',
    ];

    if (capabilities.contains(Capability.nativeNavigation.wireValue)) {
      widgets.add(_buildNativeNavigationCapabilityNote());
    }

    if (capabilities.contains(Capability.secureApi.wireValue)) {
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

  String _buildRouteDemoScreen({
    required String miniProgramId,
    required String title,
    required String detailsScreenId,
    required String routeDemoScreenId,
    required String screenFunctionName,
    required String packageName,
  }) {
    return '''
import 'package:stac_core/stac_core.dart';
import 'package:$packageName/host_action_helpers.dart';

@StacScreen(screenName: '$routeDemoScreenId')
StacWidget $screenFunctionName() {
  return StacScaffold(
    appBar: StacAppBar(title: StacText(data: '$title route demo')),
    body: StacSingleChildScrollView(
      padding: StacEdgeInsets.symmetric(horizontal: 24),
      child: StacColumn(
        crossAxisAlignment: StacCrossAxisAlignment.start,
        children: [
          StacText(
            data: '$title route actions',
            style: StacCustomTextStyle(
              fontSize: 26,
              fontWeight: StacFontWeight.w700,
              color: '#1A202C',
            ),
          ),
          StacSizedBox(height: 12),
          StacText(
            data:
                'This screen demonstrates stack-aware portable navigation helpers. '
                'Use these patterns when your mini-program needs to move backward '
                'or jump to a known earlier step.',
          ),
          StacSizedBox(height: 20),
          StacFilledButton(
            onPressed: popToMiniProgramRootAction(
              requestId: '$miniProgramId-pop-to-root',
            ),
            child: StacText(data: 'Pop to first screen'),
          ),
          StacSizedBox(height: 8),
          StacText(
            data:
                'Pop to root returns to the first screen in the current mini-program stack.',
          ),
          StacSizedBox(height: 16),
          StacOutlinedButton(
            onPressed: popToMiniProgramScreenAction(
              requestId: '$miniProgramId-pop-to-details',
              screenId: '$detailsScreenId',
            ),
            child: StacText(data: 'Pop to second screen'),
          ),
          StacSizedBox(height: 8),
          StacText(
            data:
                'Pop to screen targets a known earlier screenId when the stack already contains it.',
          ),
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
''';

  String _buildTrackEventButton(String miniProgramId) =>
      '''
            StacFilledButton(
              onPressed: hostTrackEventAction(
                requestId: '$miniProgramId-track-open',
                name: '${miniProgramId}_opened',
                properties: const <String, dynamic>{
                  'source': '$miniProgramId',
                  'surface': '$miniProgramId',
                },
              ),
              child: StacText(data: 'Track starter event (logs only)'),
            ),
            StacSizedBox(height: 8),
            StacText(
              data:
                  'This starter analytics action only writes to the host log. '
              'It does not change the UI.',
            ),
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
}
