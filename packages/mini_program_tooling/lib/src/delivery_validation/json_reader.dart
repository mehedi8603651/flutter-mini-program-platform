import 'dart:convert';
import 'dart:io';

import '../delivery_validation.dart';
import 'validation_context.dart';

Future<Map<String, dynamic>?> readDeliveryJsonMap(
  File file, {
  required DeliveryValidationContext context,
}) async {
  try {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      context.messages.add(
        DeliveryValidationMessage(
          severity: ValidationSeverity.error,
          code: 'json_object_required',
          path: context.relativePath(file.path),
          message: 'Expected a top-level JSON object.',
        ),
      );
      return null;
    }

    return decoded.map((key, value) => MapEntry(key.toString(), value));
  } on FileSystemException catch (error) {
    context.messages.add(
      DeliveryValidationMessage(
        severity: ValidationSeverity.error,
        code: 'file_read_failed',
        path: context.relativePath(file.path),
        message: 'Could not read file: $error',
      ),
    );
  } on FormatException catch (error) {
    context.messages.add(
      DeliveryValidationMessage(
        severity: ValidationSeverity.error,
        code: 'json_decode_failed',
        path: context.relativePath(file.path),
        message: 'Invalid JSON: ${error.message}',
      ),
    );
  }

  return null;
}
