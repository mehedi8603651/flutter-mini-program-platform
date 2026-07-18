import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'errors.dart';
import 'handoff.dart';

String resolvePartnerHandoffOutputPath({
  required String? outputPath,
  required String appId,
}) => p.normalize(
  p.absolute(
    outputPath?.trim().isNotEmpty == true
        ? outputPath!.trim()
        : '$appId.partner.json',
  ),
);

Future<void> writePartnerHandoffFile({
  required String outputPath,
  required MiniProgramPartnerHandoff handoff,
}) async {
  await Directory(p.dirname(outputPath)).create(recursive: true);
  await File(outputPath).writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(handoff.toJson())}\n',
  );
}

Future<MiniProgramPartnerHandoff> readPartnerHandoffFile(
  String filePath,
) async {
  final normalizedPath = p.normalize(p.absolute(filePath));
  final file = File(normalizedPath);
  if (!await file.exists()) {
    throw MiniProgramPartnerHandoffException(
      'MiniProgram partner handoff file does not exist: $normalizedPath',
    );
  }
  final decoded = jsonDecode(await file.readAsString());
  return MiniProgramPartnerHandoff.fromJson(decoded);
}
