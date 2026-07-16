import 'authoring_validation.dart';

int positiveInt(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'Value must be positive.');
  }
  return value;
}

int positiveDurationMs(Duration value, String name) {
  final milliseconds = value.inMilliseconds;
  if (milliseconds <= 0) {
    throw ArgumentError.value(value, name, 'Duration must be positive.');
  }
  return milliseconds;
}

int nonNegativeInt(int value, String name) {
  if (value < 0) {
    throw ArgumentError.value(value, name, 'Value cannot be negative.');
  }
  return value;
}

int boundedInt(
  int value,
  String name, {
  required int minimum,
  required int maximum,
}) {
  if (value < minimum || value > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'Value must be between $minimum and $maximum.',
    );
  }
  return value;
}

num finiteNumber(num value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'Value must be finite.');
  }
  return value;
}

double finiteNonNegative(double value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(
      value,
      name,
      'Value must be finite and non-negative.',
    );
  }
  return value;
}

String allowedValue(String value, String name, Set<String> allowed) {
  final normalized = requiredAuthoringString(value, name);
  if (!allowed.contains(normalized)) {
    throw ArgumentError.value(
      value,
      name,
      'Value must be one of: ${allowed.join(', ')}.',
    );
  }
  return normalized;
}
