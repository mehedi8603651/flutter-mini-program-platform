import 'dart:convert';
import 'dart:io';

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as p;

Future<void> writePublisherBackendContract(
  String contractPath,
  MiniProgramPublisherBackendContract contract,
) async {
  await Directory(p.dirname(contractPath)).create(recursive: true);
  await File(contractPath).writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(contract.toJson())}\n',
  );
}

Future<MiniProgramPublisherBackendContract> readPublisherBackendContract({
  required String contractPath,
  required bool allowLocalHttp,
}) async {
  final normalizedPath = p.normalize(p.absolute(contractPath));
  final file = File(normalizedPath);
  if (!await file.exists()) {
    throw FormatException(
      'Publisher API contract file does not exist: $normalizedPath',
    );
  }
  final decoded = jsonDecode(await file.readAsString());
  return MiniProgramPublisherBackendContract.fromJson(
    decoded,
    allowLocalHttp: allowLocalHttp,
  );
}
