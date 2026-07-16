import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

@immutable
class CachedManifestEntry {
  const CachedManifestEntry({
    required this.miniProgramId,
    required this.manifest,
    required this.cachedAt,
  });

  factory CachedManifestEntry.fromJson(Map<String, dynamic> json) {
    return CachedManifestEntry(
      miniProgramId: json['miniProgramId'] as String,
      manifest: MiniProgramManifest.fromJson(
        Map<String, dynamic>.from(json['manifest'] as Map),
      ),
      cachedAt: DateTime.parse(json['cachedAt'] as String),
    );
  }

  final String miniProgramId;
  final MiniProgramManifest manifest;
  final DateTime cachedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'miniProgramId': miniProgramId,
      'manifest': manifest.toJson(),
      'cachedAt': cachedAt.toIso8601String(),
    };
  }
}
