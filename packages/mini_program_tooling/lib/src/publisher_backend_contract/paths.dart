import 'package:path/path.dart' as p;

String resolvePublisherBackendContractPath(
  String miniProgramRootPath, {
  String? explicitPath,
}) {
  final explicit = explicitPath?.trim();
  return p.normalize(
    p.absolute(
      explicit != null && explicit.isNotEmpty
          ? explicit
          : p.join(miniProgramRootPath, 'publisher_backend.json'),
    ),
  );
}
