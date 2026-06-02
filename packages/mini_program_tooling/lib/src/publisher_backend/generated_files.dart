part of '../publisher_backend_starter.dart';

Map<String, String> buildAwsLambdaPublisherBackendFiles({
  required String miniProgramRootPath,
  String? miniProgramId,
  String? title,
  String storageMode = 'bundled',
}) {
  if (!const <String>[
    _publisherBackendStorageBundled,
    _publisherBackendStorageDynamoDb,
  ].contains(storageMode)) {
    throw PublisherBackendException(
      'Unsupported AWS Lambda publisher backend storage mode: $storageMode',
    );
  }
  final appId = miniProgramId?.trim().isNotEmpty == true
      ? miniProgramId!.trim()
      : _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
  final displayTitle = title?.trim().isNotEmpty == true
      ? title!.trim()
      : _titleFromAppId(appId);
  final sampleFiles = buildMockPublisherBackendFiles(
    miniProgramRootPath: miniProgramRootPath,
    miniProgramId: appId,
    title: displayTitle,
  );
  return <String, String>{
    'template.yaml': _awsLambdaTemplateYaml(
      displayTitle,
      appId: appId,
      storageMode: storageMode,
    ),
    'README.md': _awsLambdaReadme(appId, displayTitle, storageMode),
    p.join('src', 'package.json'): _awsLambdaPackageJson(appId, storageMode),
    p.join('src', 'handler.mjs'): _awsLambdaHandlerSource(),
    p.join('src', 'data', 'home_bootstrap.json'):
        sampleFiles[p.join('data', 'home_bootstrap.json')]!,
    p.join('src', 'data', 'coupons_list.json'):
        sampleFiles[p.join('data', 'coupons_list.json')]!,
    p.join('src', 'data', 'session.json'):
        sampleFiles[p.join('data', 'session.json')]!,
  };
}

Map<String, String> buildFirebaseFunctionsPublisherBackendFiles({
  required String miniProgramRootPath,
  String? miniProgramId,
  String? title,
}) {
  final appId = miniProgramId?.trim().isNotEmpty == true
      ? miniProgramId!.trim()
      : _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
  final displayTitle = title?.trim().isNotEmpty == true
      ? title!.trim()
      : _titleFromAppId(appId);
  final sampleFiles = buildMockPublisherBackendFiles(
    miniProgramRootPath: miniProgramRootPath,
    miniProgramId: appId,
    title: displayTitle,
  );
  return <String, String>{
    'firebase.json': _firebaseJson(),
    '.firebaserc.example': _firebaseRcExample(),
    'README.md': _firebaseFunctionsReadme(appId, displayTitle),
    p.join('functions', 'package.json'): _firebaseFunctionsPackageJson(appId),
    p.join('functions', 'index.js'): _firebaseFunctionsIndexSource(appId),
    p.join('functions', 'router.js'): _firebaseFunctionsRouterSource(),
    p.join('functions', 'auth_service.js'):
        _firebaseFunctionsAuthServiceSource(),
    p.join('functions', 'firestore_store.js'):
        _firebaseFunctionsFirestoreStoreSource(),
    p.join('functions', 'data', 'home_bootstrap.json'):
        sampleFiles[p.join('data', 'home_bootstrap.json')]!,
    p.join('functions', 'data', 'coupons_list.json'):
        sampleFiles[p.join('data', 'coupons_list.json')]!,
    p.join('functions', 'data', 'session.json'):
        sampleFiles[p.join('data', 'session.json')]!,
  };
}

Map<String, String> buildMockPublisherBackendFiles({
  required String miniProgramRootPath,
  String? miniProgramId,
  String? title,
}) {
  final appId = miniProgramId?.trim().isNotEmpty == true
      ? miniProgramId!.trim()
      : _readManifestIdSync(miniProgramRootPath) ?? 'mini_program';
  final displayTitle = title?.trim().isNotEmpty == true
      ? title!.trim()
      : _titleFromAppId(appId);
  return <String, String>{
    'pubspec.yaml': _mockBackendPubspec(appId),
    'README.md': _mockBackendReadme(appId, displayTitle),
    p.join('bin', 'server.dart'): _mockBackendServerSource(),
    p.join('data', 'home_bootstrap.json'): _prettyJson(<String, Object?>{
      'title': '$displayTitle backend starter',
      'subtitle': 'Loaded from the publisher-owned mock backend.',
      'user': <String, Object?>{
        'id': 'preview-user',
        'name': 'Preview User',
        'tier': 'Gold',
      },
      'heroImageUrl': 'https://picsum.photos/seed/${appId}_hero/960/480',
    }),
    p.join('data', 'coupons_list.json'): _prettyJson(<String, Object?>{
      'coupons': <Object?>[
        <String, Object?>{
          'id': 'coupon-10',
          'title': '10% starter coupon',
          'description': 'Backend-driven coupon item from mock data.',
          'imageUrl': 'https://picsum.photos/seed/${appId}_coupon_10/320/200',
        },
        <String, Object?>{
          'id': 'coupon-20',
          'title': '20% weekend reward',
          'description':
              'Replace this JSON with Firebase, AWS, or custom API data.',
          'imageUrl': 'https://picsum.photos/seed/${appId}_coupon_20/320/200',
        },
      ],
    }),
    p.join('data', 'session.json'): _prettyJson(<String, Object?>{
      'authenticated': true,
      'user': <String, Object?>{
        'id': 'preview-user',
        'name': 'Preview User',
        'email': 'preview@example.com',
      },
      'note': 'Mock auth only. Real auth belongs on publisher servers.',
    }),
  };
}
