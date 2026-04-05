import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

class LocalMiniProgramSource implements MiniProgramSource {
  const LocalMiniProgramSource();

  static const String _baseAssetPath = 'assets/mini_programs';

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    final manifestJson = await _loadJson(
      '$_baseAssetPath/$miniProgramId/manifest.json',
    );
    return MiniProgramManifest.fromJson(manifestJson);
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    return _loadJson('$_baseAssetPath/$miniProgramId/screens/$screenId.json');
  }

  Future<Map<String, dynamic>> _loadJson(String assetPath) async {
    final rawJson = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Asset "$assetPath" does not contain a JSON object.');
    }
    return decoded;
  }
}
