import 'package:path/path.dart' as path;

import '../delivery_validation.dart';

class DeliveryValidationContext {
  const DeliveryValidationContext({
    required this.repoRootPath,
    required this.backendApiRootPath,
    required this.miniProgramId,
    required this.messages,
  });

  final String repoRootPath;
  final String backendApiRootPath;
  final String? miniProgramId;
  final List<DeliveryValidationMessage> messages;

  String relativePath(String targetPath) =>
      path.relative(targetPath, from: repoRootPath).replaceAll('\\', '/');
}
