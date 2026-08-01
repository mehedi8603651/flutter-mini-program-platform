/// Maximum QR payload length exposed to mini-program live state.
const int miniProgramQrMaxValueLength = 8192;

/// JSON-safe result returned by a trusted host QR scanner.
///
/// [rawValue] is inert data. The SDK never opens URLs or executes content
/// based on [valueType].
class MiniProgramQrScanResult {
  MiniProgramQrScanResult({
    required String rawValue,
    required String valueType,
    required this.scannedAtUtc,
    this.format = qrFormat,
  }) : rawValue = _qrValue(rawValue),
       valueType = _qrValueType(valueType) {
    validate();
  }

  factory MiniProgramQrScanResult.fromJson(Map<String, dynamic> json) {
    if (json['rawValue'] is! String ||
        json['format'] is! String ||
        json['valueType'] is! String ||
        json['scannedAtUtc'] is! String) {
      throw const FormatException('Invalid mini-program QR scan result.');
    }
    final scannedAtUtc = DateTime.tryParse(json['scannedAtUtc']! as String);
    if (scannedAtUtc == null) {
      throw const FormatException(
        'QR scannedAtUtc must be an ISO-8601 timestamp.',
      );
    }
    return MiniProgramQrScanResult(
      rawValue: json['rawValue']! as String,
      format: json['format']! as String,
      valueType: json['valueType']! as String,
      scannedAtUtc: scannedAtUtc,
    );
  }

  static const String qrFormat = 'qr';
  static const Set<String> supportedValueTypes = <String>{
    'text',
    'url',
    'wifi',
    'contact',
    'email',
    'phone',
    'sms',
    'geo',
    'calendar',
    'driverLicense',
    'unknown',
  };

  final String rawValue;
  final String format;
  final String valueType;
  final DateTime scannedAtUtc;

  void validate() {
    if (format != qrFormat) {
      throw const FormatException('QR format must be "qr".');
    }
    _qrValue(rawValue);
    _qrValueType(valueType);
    if (!scannedAtUtc.isUtc) {
      throw const FormatException('QR scannedAtUtc must be UTC.');
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return <String, dynamic>{
      'rawValue': rawValue,
      'format': format,
      'valueType': valueType,
      'scannedAtUtc': scannedAtUtc.toIso8601String(),
    };
  }
}

String _qrValue(String value) {
  if (value.isEmpty || value.length > miniProgramQrMaxValueLength) {
    throw const FormatException('QR rawValue must contain 1-8192 characters.');
  }
  return value;
}

String _qrValueType(String value) {
  final normalized = value.trim();
  if (!MiniProgramQrScanResult.supportedValueTypes.contains(normalized)) {
    throw FormatException('Unsupported QR valueType "$value".');
  }
  return normalized;
}
