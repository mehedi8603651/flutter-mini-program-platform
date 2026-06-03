part of '../publisher_backend_starter.dart';

extension _PublisherBackendFirebaseStarterUi on PublisherBackendStarter {
  Future<PublisherBackendFirebaseStarterUiResult> _writeFirebaseStarterUi(
    PublisherBackendFirebaseStarterUiRequest request,
  ) async {
    final miniProgramRootPath = await _requireMiniProgramRoot(
      request.miniProgramRootPath,
    );
    final backendRootPath = p.join(
      miniProgramRootPath,
      'backend',
      'firebase_functions',
    );
    await _assertFirebaseBackendPaths(backendRootPath);

    final manifest = await _readFirebaseStarterManifest(miniProgramRootPath);
    final miniProgramId = manifest.id;
    final title = manifest.title;
    final entryScreen = manifest.entryScreen;
    final screenFormat = manifest.screenFormat;
    final screenSchemaVersion = manifest.screenSchemaVersion;
    final sourceRootPath = p.join(miniProgramRootPath, screenFormat);

    final writtenPaths = <String>[];
    final skippedPaths = <String>[];
    final unchangedPaths = <String>[];

    if (screenFormat == 'mp') {
      await _writeFirebaseMpStarterFiles(
        miniProgramRootPath: miniProgramRootPath,
        miniProgramId: miniProgramId,
        title: title,
        entryScreen: entryScreen,
        force: request.force,
        writtenPaths: writtenPaths,
        skippedPaths: skippedPaths,
        unchangedPaths: unchangedPaths,
      );
    } else if (screenFormat == 'stac') {
      final packageName = await _readFirebaseStarterPackageName(
        miniProgramRootPath,
        fallback: _safeDartPackageName('${miniProgramId}_mini_program'),
      );
      final screenFunctionName = _lowerCamelIdentifier(entryScreen);
      final helperFile = File(
        p.join(miniProgramRootPath, 'lib', 'host_action_helpers.dart'),
      );
      await _writeFirebaseStarterHelperFile(
        helperFile,
        writtenPaths: writtenPaths,
        unchangedPaths: unchangedPaths,
      );

      await _writeFirebaseStarterFile(
        path: p.join(
          miniProgramRootPath,
          'stac',
          'screens',
          '$entryScreen.dart',
        ),
        contents: _firebaseStarterHomeScreenSource(
          packageName: packageName,
          miniProgramId: miniProgramId,
          title: title,
          entryScreen: entryScreen,
          screenFunctionName: screenFunctionName,
        ),
        force: request.force,
        writtenPaths: writtenPaths,
        skippedPaths: skippedPaths,
        unchangedPaths: unchangedPaths,
      );
    } else {
      throw PublisherBackendException(
        'Unsupported mini-program screenFormat "$screenFormat" for Firebase starter UI.',
      );
    }
    await _writeFirebaseStarterFile(
      path: p.join(backendRootPath, 'functions', 'data', 'home_bootstrap.json'),
      contents: _firebaseStarterHomeBootstrapJson(
        miniProgramId: miniProgramId,
        title: title,
      ),
      force: request.force,
      writtenPaths: writtenPaths,
      skippedPaths: skippedPaths,
      unchangedPaths: unchangedPaths,
    );
    await _writeFirebaseStarterFile(
      path: p.join(backendRootPath, 'functions', 'data', 'coupons_list.json'),
      contents: _firebaseStarterCouponsJson(
        miniProgramId: miniProgramId,
        title: title,
      ),
      force: request.force,
      writtenPaths: writtenPaths,
      skippedPaths: skippedPaths,
      unchangedPaths: unchangedPaths,
    );
    await _writeFirebaseStarterFile(
      path: p.join(backendRootPath, 'functions', 'data', 'session.json'),
      contents: _firebaseStarterSessionJson(title),
      force: request.force,
      writtenPaths: writtenPaths,
      skippedPaths: skippedPaths,
      unchangedPaths: unchangedPaths,
    );

    writtenPaths.sort();
    skippedPaths.sort();
    unchangedPaths.sort();
    return PublisherBackendFirebaseStarterUiResult(
      miniProgramRootPath: miniProgramRootPath,
      backendRootPath: backendRootPath,
      sourceRootPath: sourceRootPath,
      miniProgramId: miniProgramId,
      title: title,
      entryScreen: entryScreen,
      screenFormat: screenFormat,
      screenSchemaVersion: screenSchemaVersion,
      writtenPaths: writtenPaths,
      skippedPaths: skippedPaths,
      unchangedPaths: unchangedPaths,
      force: request.force,
    );
  }
}

class _FirebaseStarterManifestInfo {
  const _FirebaseStarterManifestInfo({
    required this.id,
    required this.title,
    required this.entryScreen,
    required this.screenFormat,
    this.screenSchemaVersion,
  });

  final String id;
  final String title;
  final String entryScreen;
  final String screenFormat;
  final int? screenSchemaVersion;
}

Future<_FirebaseStarterManifestInfo> _readFirebaseStarterManifest(
  String miniProgramRootPath,
) async {
  final file = File(p.join(miniProgramRootPath, 'manifest.json'));
  var appId = _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
  var title = _titleFromAppId(appId);
  var entry = '${appId}_home';
  var screenFormat = 'stac';
  int? screenSchemaVersion;
  try {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map) {
      final rawId = decoded['id']?.toString().trim();
      if (rawId != null && rawId.isNotEmpty) {
        appId = rawId;
      }
      final rawTitle = decoded['title']?.toString().trim();
      if (rawTitle != null && rawTitle.isNotEmpty) {
        title = rawTitle;
      } else {
        title = _titleFromAppId(appId);
      }
      final rawEntry = decoded['entry']?.toString().trim();
      if (rawEntry != null && rawEntry.isNotEmpty) {
        entry = rawEntry;
      } else {
        entry = '${appId}_home';
      }
      final rawScreenFormat = decoded['screenFormat']?.toString().trim();
      if (rawScreenFormat != null && rawScreenFormat.isNotEmpty) {
        screenFormat = rawScreenFormat;
      }
      final rawScreenSchemaVersion = decoded['screenSchemaVersion'];
      if (rawScreenSchemaVersion is int) {
        screenSchemaVersion = rawScreenSchemaVersion;
      } else if (rawScreenSchemaVersion is num) {
        screenSchemaVersion = rawScreenSchemaVersion.toInt();
      } else if (rawScreenSchemaVersion is String) {
        screenSchemaVersion = int.tryParse(rawScreenSchemaVersion.trim());
      }
    }
  } catch (_) {
    // The root was already validated. Fall back to safe defaults if optional
    // metadata cannot be read.
  }
  return _FirebaseStarterManifestInfo(
    id: appId,
    title: title,
    entryScreen: entry,
    screenFormat: screenFormat,
    screenSchemaVersion: screenSchemaVersion,
  );
}

Future<String> _readFirebaseStarterPackageName(
  String miniProgramRootPath, {
  required String fallback,
}) async {
  final file = File(p.join(miniProgramRootPath, 'pubspec.yaml'));
  if (!await file.exists()) {
    return fallback;
  }
  final lines = await file.readAsLines();
  for (final line in lines) {
    final match = RegExp(r'^\s*name:\s*([A-Za-z0-9_]+)\s*$').firstMatch(line);
    if (match != null) {
      final name = match.group(1)?.trim();
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
  }
  return fallback;
}

Future<void> _writeFirebaseStarterFile({
  required String path,
  required String contents,
  required bool force,
  required List<String> writtenPaths,
  required List<String> skippedPaths,
  required List<String> unchangedPaths,
}) async {
  final file = File(path);
  if (await file.exists()) {
    final existing = await file.readAsString();
    if (existing == contents) {
      unchangedPaths.add(path);
      return;
    }
    if (!force) {
      skippedPaths.add(path);
      return;
    }
  }
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
  writtenPaths.add(path);
}

Future<void> _writeFirebaseStarterHelperFile(
  File file, {
  required List<String> writtenPaths,
  required List<String> unchangedPaths,
}) async {
  if (!await file.exists()) {
    await file.parent.create(recursive: true);
    await file.writeAsString(_firebaseStarterFullHelperSource());
    writtenPaths.add(file.path);
    return;
  }

  var contents = await file.readAsString();
  final additions = <String>[];
  if (!contents.contains('miniProgramBackendQueryAction(')) {
    additions.add(_firebaseStarterBackendQueryActionSource());
  }
  if (!contents.contains('miniProgramShowEmailAuthAction(')) {
    additions.add(_firebaseStarterEmailAuthActionSource());
  }
  if (!contents.contains('miniProgramAuthAction(')) {
    additions.add(_firebaseStarterAuthActionSource());
  }
  if (!contents.contains('miniProgramBackendBuilder(')) {
    additions.add(_firebaseStarterBackendBuilderSource());
  }
  if (!contents.contains('miniProgramPagedBackendBuilder(')) {
    additions.add(_firebaseStarterPagedBackendBuilderSource());
  }
  if (!contents.contains('miniProgramLoadMore(')) {
    additions.add(_firebaseStarterLoadMoreActionSource());
  }
  if (!contents.contains('miniProgramAuthBuilder(')) {
    additions.add(_firebaseStarterAuthBuilderSource());
  }
  if (additions.isEmpty) {
    unchangedPaths.add(file.path);
    return;
  }

  if (!contents.endsWith('\n')) {
    contents = '$contents\n';
  }
  contents = '$contents\n${additions.join('\n')}';
  await file.writeAsString(contents);
  writtenPaths.add(file.path);
}

Future<void> _writeFirebaseMpStarterFiles({
  required String miniProgramRootPath,
  required String miniProgramId,
  required String title,
  required String entryScreen,
  required bool force,
  required List<String> writtenPaths,
  required List<String> skippedPaths,
  required List<String> unchangedPaths,
}) async {
  final screenFunctionName = _mpScreenBuilderName(entryScreen);
  await _ensureFirebaseMpProgramFile(
    path: p.join(miniProgramRootPath, 'mp', 'program.dart'),
    entryScreen: entryScreen,
    screenFunctionName: screenFunctionName,
    writtenPaths: writtenPaths,
    skippedPaths: skippedPaths,
    unchangedPaths: unchangedPaths,
  );
  await _writeFirebaseStarterFile(
    path: p.join(miniProgramRootPath, 'tool', 'build_mp.dart'),
    contents: _firebaseMpBuildScriptSource(),
    force: force,
    writtenPaths: writtenPaths,
    skippedPaths: skippedPaths,
    unchangedPaths: unchangedPaths,
  );
  await _writeFirebaseStarterFile(
    path: p.join(miniProgramRootPath, 'mp', 'screens', '$entryScreen.dart'),
    contents: _firebaseMpStarterHomeScreenSource(
      title: title,
      screenFunctionName: screenFunctionName,
    ),
    force: force,
    writtenPaths: writtenPaths,
    skippedPaths: skippedPaths,
    unchangedPaths: unchangedPaths,
  );
}

Future<void> _ensureFirebaseMpProgramFile({
  required String path,
  required String entryScreen,
  required String screenFunctionName,
  required List<String> writtenPaths,
  required List<String> skippedPaths,
  required List<String> unchangedPaths,
}) async {
  final file = File(path);
  final contents = _firebaseMpProgramSource(
    entryScreen: entryScreen,
    screenFunctionName: screenFunctionName,
  );
  if (!await file.exists()) {
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
    writtenPaths.add(path);
    return;
  }

  final existing = await file.readAsString();
  if (existing == contents ||
      existing.contains("'$entryScreen':") ||
      existing.contains('"$entryScreen":')) {
    unchangedPaths.add(path);
    return;
  }
  skippedPaths.add(path);
}

String _mpScreenBuilderName(String screenId) =>
    'build${_pascalIdentifier(screenId)}';

String _pascalIdentifier(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  final normalized = parts.isEmpty ? <String>['mini', 'program'] : parts;
  final identifier = normalized.map((part) {
    final lower = part.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }).join();
  if (RegExp(r'^[A-Za-z_]').hasMatch(identifier)) {
    return identifier;
  }
  return 'MiniProgram$identifier';
}

String _dartString(String value) =>
    "'${value.replaceAll('\\', '\\\\').replaceAll("'", "\\'")}'";

String _firebaseMpBuildScriptSource() => '''
import 'package:mini_program_ui/mini_program_ui.dart';

import '../mp/program.dart';

Future<void> main(List<String> arguments) async {
  await writeMpBuildOutput(miniProgram, arguments: arguments);
}
''';

String _firebaseMpProgramSource({
  required String entryScreen,
  required String screenFunctionName,
}) =>
    '''
import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/$entryScreen.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    '$entryScreen': $screenFunctionName,
  },
);
''';

String _firebaseMpStarterHomeScreenSource({
  required String title,
  required String screenFunctionName,
}) {
  final titleLiteral = _dartString(title);
  return '''
import 'package:mini_program_ui/mini_program_ui.dart';

MpNode $screenFunctionName() {
  return Mp.column(
    children: <MpNode>[
      Mp.heading($titleLiteral),
      Mp.text(
        'A Firebase-backed mini-program with publisher-owned email auth, '
        'Firestore data, remote images, protected handoff, and paged lists.',
      ),
      Mp.sizedBox(height: 12),
      Mp.card(
        child: Mp.column(
          children: <MpNode>[
            Mp.text('Starter capabilities: Firebase backend + auth'),
          ],
        ),
      ),
      Mp.heading('Publisher account'),
      Mp.authBuilder(
        loading: Mp.text('Restoring publisher account...'),
        signedOut: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.text('Sign in to unlock protected Firebase data.'),
              Mp.primaryButton(
                label: 'Sign in with email',
                action: Mp.auth.showEmailAuth(),
              ),
              Mp.secondaryButton(
                label: 'Create test account',
                action: Mp.auth.showEmailAuth(mode: 'signUp'),
              ),
            ],
          ),
        ),
        signedIn: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.text('Signed in as {{auth.user.email}}'),
              Mp.backendBuilder(
                requestId: 'authSession',
                endpoint: 'auth/session',
                forceRefresh: true,
                loading: Mp.text('Checking protected Firebase session...'),
                error: Mp.text(
                  'Protected session failed: {{backend.authSession.message}}',
                ),
                child: Mp.text(
                  'Protected backend verified for '
                  '{{backend.authSession.data.user.email}}',
                ),
              ),
              Mp.secondaryButton(
                label: 'Refresh auth session',
                action: Mp.auth.refresh(),
              ),
              Mp.secondaryButton(
                label: 'Sign out',
                action: Mp.auth.signOut(),
              ),
            ],
          ),
        ),
        error: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.text('Auth error: {{auth.message}}'),
              Mp.primaryButton(
                label: 'Try again',
                action: Mp.auth.showEmailAuth(),
              ),
            ],
          ),
        ),
      ),
      Mp.heading('Firebase backend data'),
      Mp.backendBuilder(
        requestId: 'home',
        endpoint: 'home/bootstrap',
        cacheTtlSeconds: 60,
        loading: Mp.text('Loading Firebase home data...'),
        error: Mp.text('{{backend.home.message}}'),
        child: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.image(src: '{{backend.home.data.heroImageUrl}}'),
              Mp.heading('{{backend.home.data.title}}'),
              Mp.text('{{backend.home.data.subtitle}}'),
              Mp.text(
                'Preview user: {{backend.home.data.user.name}} - '
                '{{backend.home.data.user.tier}} - '
                '{{backend.home.data.user.points}} pts',
              ),
              Mp.secondaryButton(
                label: 'Refresh Firebase data',
                action: Mp.backend.query(
                  requestId: 'home',
                  endpoint: 'home/bootstrap',
                  forceRefresh: true,
                ),
              ),
            ],
          ),
        ),
      ),
      Mp.heading('Paged Firebase coupons'),
      Mp.pagedBackendBuilder(
        requestId: 'coupons',
        endpoint: 'coupons/page',
        limit: 2,
        cacheTtlSeconds: 60,
        loading: Mp.text('Loading Firebase coupons...'),
        loadingMore: Mp.text('Loading more coupons...'),
        error: Mp.text('{{backend.coupons.message}}'),
        empty: Mp.text('No Firebase coupons yet'),
        end: Mp.text('All Firebase coupons loaded'),
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
      Mp.text(
        'Edit this Mp source, then run miniprogram build to regenerate '
        'mp/.build screen JSON.',
      ),
    ],
  );
}
''';
}

String _lowerCamelIdentifier(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  final normalized = parts.isEmpty ? <String>['mini', 'program'] : parts;
  final first = normalized.first.toLowerCase();
  final tail = normalized.skip(1).map((part) {
    final lower = part.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }).join();
  final identifier = '$first$tail';
  if (RegExp(r'^[A-Za-z_]').hasMatch(identifier)) {
    return identifier;
  }
  return 'miniProgram$identifier';
}

String _safeDartPackageName(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (normalized.isEmpty) {
    return 'mini_program';
  }
  if (RegExp(r'^[a-z_]').hasMatch(normalized)) {
    return normalized;
  }
  return 'mini_program_$normalized';
}

String _firebaseStarterHomeBootstrapJson({
  required String miniProgramId,
  required String title,
}) =>
    '${_prettyJson(<String, Object?>{
      'title': '$title rewards from Firestore',
      'subtitle': 'Loaded through the publisher-owned Firebase Functions backend.',
      'heroImageUrl': 'https://picsum.photos/seed/${miniProgramId}_hero/960/480',
      'user': <String, Object?>{'id': 'preview-user', 'name': 'Preview User', 'email': 'preview.user@example.com', 'tier': 'Gold', 'points': 1840},
    })}\n';

String _firebaseStarterCouponsJson({
  required String miniProgramId,
  required String title,
}) =>
    '${_prettyJson(<String, Object?>{
      'coupons': <Object?>[
        <String, Object?>{'id': 'coupon-10', 'title': '10% $title welcome coupon', 'description': 'Seeded starter data from local tooling into Firestore.', 'imageUrl': 'https://picsum.photos/seed/${miniProgramId}_coupon_10/320/200'},
        <String, Object?>{'id': 'coupon-20', 'title': '20% weekend reward', 'description': 'Use this record to test reads, writes, and protected handoff.', 'imageUrl': 'https://picsum.photos/seed/${miniProgramId}_coupon_20/320/200'},
        <String, Object?>{'id': 'coupon-30', 'title': '30% image-backed flash deal', 'description': 'Remote image data verifies host rendering across devices.', 'imageUrl': 'https://picsum.photos/seed/${miniProgramId}_coupon_30/320/200'},
      ],
    })}\n';

String _firebaseStarterSessionJson(String title) =>
    '${_prettyJson(<String, Object?>{
      'authenticated': true,
      'user': <String, Object?>{'id': 'preview-user', 'name': 'Preview User', 'email': 'preview.user@example.com', 'tier': '$title starter'},
      'message': 'Preview session data. Real login uses publisher-owned auth.',
    })}\n';

String _firebaseStarterHomeScreenSource({
  required String packageName,
  required String miniProgramId,
  required String title,
  required String entryScreen,
  required String screenFunctionName,
}) =>
    '''
import 'package:stac_core/stac_core.dart';
import 'package:$packageName/host_action_helpers.dart';

@StacScreen(screenName: '$entryScreen')
StacWidget $screenFunctionName() {
  return StacScaffold(
    appBar: StacAppBar(title: StacText(data: '$title')),
    body: StacSingleChildScrollView(
      padding: StacEdgeInsets.symmetric(horizontal: 24),
      child: StacColumn(
        crossAxisAlignment: StacCrossAxisAlignment.start,
        children: [
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
                'A Firebase-backed mini-program with publisher-owned email auth, '
                'Firestore data, remote images, and protected host handoff.',
          ),
          StacSizedBox(height: 16),
          StacContainer(
            padding: StacEdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: StacBoxDecoration(
              color: '#E0F2FE',
              borderRadius: StacBorderRadius.all(18),
            ),
            child: StacText(
              data: 'Starter capabilities: Firebase backend + auth',
              style: StacCustomTextStyle(
                fontSize: 15,
                fontWeight: StacFontWeight.w600,
                color: '#0C4A6E',
              ),
            ),
          ),
          StacSizedBox(height: 20),
          StacText(
            data: 'Publisher account',
            style: StacCustomTextStyle(
              fontSize: 20,
              fontWeight: StacFontWeight.w700,
              color: '#1A202C',
            ),
          ),
          StacSizedBox(height: 8),
          miniProgramAuthBuilder(
            loading: StacText(data: 'Restoring publisher account...'),
            signedOut: StacContainer(
              padding: StacEdgeInsets.all(14),
              decoration: StacBoxDecoration(
                color: '#FFF7ED',
                border: StacBorder.all(color: '#FDBA74'),
                borderRadius: StacBorderRadius.all(16),
              ),
              child: StacColumn(
                crossAxisAlignment: StacCrossAxisAlignment.start,
                children: [
                  StacText(
                    data: 'Sign in to unlock protected Firebase data.',
                    style: StacCustomTextStyle(
                      fontSize: 16,
                      fontWeight: StacFontWeight.w700,
                      color: '#7C2D12',
                    ),
                  ),
                  StacSizedBox(height: 8),
                  StacFilledButton(
                    onPressed: miniProgramShowEmailAuthAction(),
                    child: StacText(data: 'Sign in with email'),
                  ),
                  StacSizedBox(height: 8),
                  StacOutlinedButton(
                    onPressed: miniProgramShowEmailAuthAction(mode: 'signUp'),
                    child: StacText(data: 'Create test account'),
                  ),
                ],
              ),
            ),
            signedIn: StacContainer(
              padding: StacEdgeInsets.all(14),
              decoration: StacBoxDecoration(
                color: '#ECFDF5',
                border: StacBorder.all(color: '#6EE7B7'),
                borderRadius: StacBorderRadius.all(16),
              ),
              child: StacColumn(
                crossAxisAlignment: StacCrossAxisAlignment.start,
                children: [
                  StacText(
                    data: 'Signed in as {{auth.user.email}}',
                    style: StacCustomTextStyle(
                      fontSize: 16,
                      fontWeight: StacFontWeight.w700,
                      color: '#064E3B',
                    ),
                  ),
                  StacSizedBox(height: 8),
                  miniProgramBackendBuilder(
                    requestId: 'authSession',
                    endpoint: 'auth/session',
                    forceRefresh: true,
                    loading: StacText(
                      data: 'Checking protected Firebase session...',
                    ),
                    error: StacText(
                      data:
                          'Protected session failed: {{backend.authSession.message}}',
                    ),
                    child: StacText(
                      data:
                          'Protected backend verified for {{backend.authSession.data.user.email}}',
                    ),
                  ),
                  StacSizedBox(height: 10),
                  StacOutlinedButton(
                    onPressed: miniProgramAuthAction('refresh'),
                    child: StacText(data: 'Refresh auth session'),
                  ),
                  StacSizedBox(height: 8),
                  StacOutlinedButton(
                    onPressed: miniProgramAuthAction('signOut'),
                    child: StacText(data: 'Sign out'),
                  ),
                ],
              ),
            ),
            error: StacContainer(
              padding: StacEdgeInsets.all(14),
              decoration: StacBoxDecoration(
                color: '#FEF2F2',
                border: StacBorder.all(color: '#FCA5A5'),
                borderRadius: StacBorderRadius.all(16),
              ),
              child: StacColumn(
                crossAxisAlignment: StacCrossAxisAlignment.start,
                children: [
                  StacText(data: 'Auth error: {{auth.message}}'),
                  StacSizedBox(height: 8),
                  StacFilledButton(
                    onPressed: miniProgramShowEmailAuthAction(),
                    child: StacText(data: 'Try again'),
                  ),
                ],
              ),
            ),
          ),
          StacSizedBox(height: 20),
          StacText(
            data: 'Firebase backend data',
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
            loading: StacText(data: 'Loading Firebase home data...'),
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
                  StacImage.network(
                    '{{backend.home.data.heroImageUrl}}',
                    width: 320,
                    height: 150,
                    fit: StacBoxFit.cover,
                  ),
                  StacSizedBox(height: 12),
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
                        'Preview user: {{backend.home.data.user.name}} - {{backend.home.data.user.tier}} - {{backend.home.data.user.points}} pts',
                  ),
                  StacSizedBox(height: 12),
                  StacOutlinedButton(
                    onPressed: miniProgramBackendQueryAction(
                      requestId: 'home',
                      endpoint: 'home/bootstrap',
                      forceRefresh: true,
                    ),
                    child: StacText(data: 'Refresh Firebase data'),
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
            loading: StacText(data: 'Loading Firebase coupons...'),
            loadingMore: StacText(data: 'Loading more coupons...'),
            error: StacText(data: '{{backend.coupons.message}}'),
            empty: StacText(data: 'No Firebase coupons yet'),
            end: StacText(data: 'All Firebase coupons loaded'),
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
          StacSizedBox(height: 16),
        ],
      ),
    ),
  );
}
''';

String _firebaseStarterFullHelperSource() =>
    '''
import 'package:stac_core/stac_core.dart';

/// Author-friendly wrappers around serializable mini-program backend/auth APIs.
${_firebaseStarterBackendQueryActionSource()}
${_firebaseStarterEmailAuthActionSource()}
${_firebaseStarterAuthActionSource()}
${_firebaseStarterBackendBuilderSource()}
${_firebaseStarterPagedBackendBuilderSource()}
${_firebaseStarterLoadMoreActionSource()}
${_firebaseStarterAuthBuilderSource()}
''';

String _firebaseStarterBackendQueryActionSource() => '''
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
''';

String _firebaseStarterEmailAuthActionSource() => '''
StacAction miniProgramShowEmailAuthAction({String mode = 'signIn'}) {
  return StacAction(
    jsonData: <String, dynamic>{
      'actionType': 'miniProgramAuth',
      'action': 'showEmailAuth',
      'mode': mode,
    },
  );
}
''';

String _firebaseStarterAuthActionSource() => '''
StacAction miniProgramAuthAction(String action) {
  return StacAction(
    jsonData: <String, dynamic>{
      'actionType': 'miniProgramAuth',
      'action': action,
    },
  );
}
''';

String _firebaseStarterBackendBuilderSource() => '''
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
''';

String _firebaseStarterPagedBackendBuilderSource() => '''
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
''';

String _firebaseStarterLoadMoreActionSource() => '''
StacAction miniProgramLoadMore({required String requestId}) {
  return StacAction(
    jsonData: <String, dynamic>{
      'actionType': 'miniProgramLoadMore',
      'requestId': requestId,
    },
  );
}
''';

String _firebaseStarterAuthBuilderSource() => '''
StacWidget miniProgramAuthBuilder({
  StacWidget? loading,
  StacWidget? signedOut,
  StacWidget? signedIn,
  StacWidget? error,
}) {
  return StacWidget.fromJson(<String, dynamic>{
    'type': 'miniProgramAuthBuilder',
    if (loading != null) 'loading': loading.toJson(),
    if (signedOut != null) 'signedOut': signedOut.toJson(),
    if (signedIn != null) 'signedIn': signedIn.toJson(),
    if (error != null) 'error': error.toJson(),
  });
}
''';
