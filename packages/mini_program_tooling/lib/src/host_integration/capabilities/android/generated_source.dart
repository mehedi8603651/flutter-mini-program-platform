import 'dart:io';

import '../models.dart';

class AndroidGeneratedSourceMigration {
  const AndroidGeneratedSourceMigration({
    required this.source,
    required this.writes,
    required this.deletes,
  });

  final String source;
  final Map<String, String> writes;
  final Set<String> deletes;
}

Future<AndroidGeneratedSourceMigration> resolveAndroidGeneratedSource({
  required File generatedFile,
  required File legacyFile,
  required String requiredMarker,
  required String Function() buildSource,
}) async {
  final generatedSource = await _readIfExists(generatedFile);
  final legacySource = generatedFile.path == legacyFile.path
      ? null
      : await _readIfExists(legacyFile);
  _validateRecognizedFile(generatedFile, generatedSource, requiredMarker);
  _validateRecognizedFile(legacyFile, legacySource, requiredMarker);

  if (generatedSource != null) {
    if (legacySource != null &&
        _normalized(legacySource) != _normalized(generatedSource)) {
      throw MiniProgramHostCapabilityException(
        'Both legacy and generated Android capability files exist with '
        'different content: ${legacyFile.path} and ${generatedFile.path}. '
        'Reconcile them before retrying.',
      );
    }
    return AndroidGeneratedSourceMigration(
      source: generatedSource,
      writes: const <String, String>{},
      deletes: legacySource == null
          ? const <String>{}
          : <String>{legacyFile.path},
    );
  }

  final source = legacySource ?? buildSource();
  return AndroidGeneratedSourceMigration(
    source: source,
    writes: <String, String>{generatedFile.path: source},
    deletes: legacySource == null
        ? const <String>{}
        : <String>{legacyFile.path},
  );
}

Future<String?> _readIfExists(File file) async =>
    await file.exists() ? file.readAsString() : null;

void _validateRecognizedFile(File file, String? source, String requiredMarker) {
  if (source != null && !source.contains(requiredMarker)) {
    throw MiniProgramHostCapabilityException(
      'Refusing to migrate or overwrite the unrecognized Android integration '
      'file ${file.path}. '
      'Move or reconcile it before retrying.',
    );
  }
}

String _normalized(String source) => source.replaceAll('\r\n', '\n').trim();
