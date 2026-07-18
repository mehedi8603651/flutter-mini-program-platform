import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'dependencies.dart';
import 'models.dart';

Future<String> resolveLocalBackendTemplateRootPath(
  LocalBackendInitializationDependencies dependencies,
) async {
  final templateRootPath = dependencies.templateRootPath;
  if (templateRootPath != null && templateRootPath.trim().isNotEmpty) {
    return p.normalize(p.absolute(templateRootPath));
  }

  final packageUri = await Isolate.resolvePackageUri(
    Uri.parse('package:mini_program_tooling/mini_program_tooling.dart'),
  );
  if (packageUri == null || packageUri.scheme != 'file') {
    throw const LocalBackendInitException(
      'Could not resolve the installed mini_program_tooling package root.',
    );
  }

  final packageLibPath = p.fromUri(packageUri);
  final packageRootPath = p.dirname(p.dirname(packageLibPath));
  return p.join(packageRootPath, 'templates', 'backend_workspace');
}
