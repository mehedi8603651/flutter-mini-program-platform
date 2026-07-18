import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

Future<Map<String, dynamic>?> readWorkflowJsonObject(File file) async {
  if (!await file.exists()) {
    return null;
  }
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.cast<String, dynamic>();
  }
  return null;
}

Future<List<Map<String, Object?>>> findWorkflowPartnerPackages(
  String workspacePath,
) async {
  final directory = Directory(workspacePath);
  if (!await directory.exists()) {
    return <Map<String, Object?>>[];
  }
  final files = await directory
      .list()
      .where(
        (entity) =>
            entity is File && p.basename(entity.path).endsWith('.partner.json'),
      )
      .cast<File>()
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  final packages = <Map<String, Object?>>[];
  for (final file in files) {
    try {
      final json = await readWorkflowJsonObject(file);
      packages.add(<String, Object?>{
        'filePath': file.path,
        'appId': json?['appId']?.toString(),
        'title': json?['title']?.toString(),
        'artifactBaseUrl':
            json?['artifactBaseUrl']?.toString() ??
            json?['apiBaseUrl']?.toString(),
      });
    } catch (error) {
      packages.add(<String, Object?>{
        'filePath': file.path,
        'error': error.toString(),
      });
    }
  }
  return packages;
}

Future<Map<String, Map<String, Object?>>> readWorkflowEndpointMetadata(
  File file,
) async {
  if (!await file.exists()) {
    return <String, Map<String, Object?>>{};
  }
  final source = await file.readAsString();
  final match = RegExp(
    r'// BEGIN MINI_PROGRAM_ENDPOINTS_JSON\s*// ([\s\S]*?)\s*// END MINI_PROGRAM_ENDPOINTS_JSON',
  ).firstMatch(source);
  if (match == null) {
    return <String, Map<String, Object?>>{};
  }
  final decoded = jsonDecode(match.group(1)!.trim());
  if (decoded is! Map) {
    return <String, Map<String, Object?>>{};
  }
  return decoded.map((key, value) {
    final record = value is Map ? value : <String, Object?>{};
    return MapEntry(key.toString(), <String, Object?>{
      'apiBaseUri': record['apiBaseUri']?.toString(),
    });
  });
}

Future<Map<String, String>> readWorkflowRegistryMetadata(File file) async {
  if (!await file.exists()) {
    return <String, String>{};
  }
  final source = await file.readAsString();
  if (!source.contains('class MiniPrograms') ||
      !source.contains('MiniProgramInfo')) {
    return <String, String>{};
  }
  final entries = <String, String>{};
  final pattern = RegExp(
    r'''static\s+const\s+[A-Za-z_$][A-Za-z0-9_$]*\s*=\s*MiniProgramInfo\s*\(\s*appId:\s*(['"])(.*?)\1\s*,\s*title:\s*(['"])(.*?)\3\s*,?\s*\)''',
    dotAll: true,
  );
  for (final match in pattern.allMatches(source)) {
    final appId = match.group(2)?.trim() ?? '';
    final title = match.group(4)?.trim() ?? '';
    if (appId.isNotEmpty && title.isNotEmpty) {
      entries[appId] = title;
    }
  }
  return entries;
}
