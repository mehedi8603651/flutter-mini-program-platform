import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'generated_files/mock_templates.dart';

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
    'pubspec.yaml': MockPublisherBackendTemplates.pubspec(appId),
    'README.md': MockPublisherBackendTemplates.readme(appId, displayTitle),
    p.join('bin', 'server.dart'): MockPublisherBackendTemplates.serverSource(),
    p.join('data', 'home_bootstrap.json'): _prettyJson(<String, Object?>{
      'title': '$displayTitle Publisher API mock',
      'subtitle': 'Loaded from the publisher-owned mock API.',
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
          'description': 'Replace this JSON with your own Publisher API data.',
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

String? _readManifestIdSync(String miniProgramRootPath) {
  final manifestFile = File(p.join(miniProgramRootPath, 'manifest.json'));
  if (!manifestFile.existsSync()) {
    return null;
  }
  try {
    final decoded = jsonDecode(manifestFile.readAsStringSync());
    if (decoded is! Map) {
      return null;
    }
    final appId = decoded['id']?.toString().trim();
    return appId == null || appId.isEmpty ? null : appId;
  } catch (_) {
    return null;
  }
}

String _titleFromAppId(String appId) {
  final words = appId
      .trim()
      .split(RegExp(r'[._-]+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return appId;
  }
  return words
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _prettyJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);
