part of '../mini_program_data_resource.dart';

/// A validated artifact-local JSON resource load result.
class MiniProgramDataResourceLoadResult {
  const MiniProgramDataResourceLoadResult({
    required this.id,
    required this.asset,
    required this.fromCache,
    required this.bytes,
  });

  final String id;
  final String asset;
  final bool fromCache;
  final int bytes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'asset': asset,
    'fromCache': fromCache,
    'bytes': bytes,
  };
}

/// Stable failure raised while loading or searching local JSON data.
class MiniProgramDataException implements Exception {
  const MiniProgramDataException({
    required this.code,
    required this.message,
    this.details = const <String, dynamic>{},
  });

  final String code;
  final String message;
  final Map<String, dynamic> details;

  @override
  String toString() => message;
}
