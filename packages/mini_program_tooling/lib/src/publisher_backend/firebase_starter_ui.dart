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

    if (screenFormat != 'mp') {
      throw PublisherBackendException(
        'Unsupported mini-program screenFormat "$screenFormat" for Firebase starter UI.',
      );
    }
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
  var screenFormat = 'mp';
  int? screenSchemaVersion = 1;
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
