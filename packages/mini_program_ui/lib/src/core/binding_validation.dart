final RegExp fullBindingPattern = RegExp(r'^\{\{\s*[^}]+?\s*\}\}$');

bool isFullBinding(Object? value) {
  return value is String && fullBindingPattern.hasMatch(value);
}
