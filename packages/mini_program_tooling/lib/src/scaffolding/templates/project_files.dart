String buildScaffoldPubspec({
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

String buildScaffoldReadme({
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
${withMockBackend ? '- `backend/mock/` contains a local mock Publisher API starter.' : ''}

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
Keep backend endpoints relative, never place backend secrets in Mp JSON, and put
business data behind a publisher-owned middle-server API.
''';

String buildScaffoldGitignore() => '''
.dart_tool/
.packages
.pub/
build/
mp/.build/
mp/.build/
*.log
''';
