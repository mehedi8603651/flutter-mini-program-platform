import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Host-provided loading abstraction for manifests and entry screen JSON.
abstract interface class MiniProgramSource {
  Future<MiniProgramManifest> loadManifest(String miniProgramId);

  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  });
}
