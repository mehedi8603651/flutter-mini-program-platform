import 'dart:convert';

/// Bounded foreground NDEF wire values. Native tags, IDs and bytes stay native.
abstract final class MiniProgramNfc {
  static const actions = {'nfc.getState', 'nfc.read', 'nfc.cancel'};
  static const maxReadMs = 30000;
  static const maxRecords = 16;
  static const maxMessageBytes = 8192;
  static const maxTextBytes = 4096;
  static const maxUriBytes = 2048;

  static List<String> recordTypes(Object? value) {
    if (value is! List ||
        value.isEmpty ||
        value.length > 2 ||
        value.any((type) => type != 'text' && type != 'uri')) {
      throw const FormatException('Expected NFC text and/or uri record types.');
    }
    return value.cast<String>().toSet().toList(growable: false)..sort();
  }

  static Map<String, dynamic> arguments(
    String action,
    Map<String, dynamic> raw,
  ) {
    if (!actions.contains(action) ||
        raw.keys.any((key) => action != 'nfc.read' || key != 'timeoutMs')) {
      throw const FormatException('Unknown NFC action or property.');
    }
    if (action != 'nfc.read') return {};
    final timeout = raw['timeoutMs'] ?? 15000;
    if (timeout is! int || timeout < 1000 || timeout > maxReadMs) {
      throw const FormatException('NFC timeout must be 1000–30000 ms.');
    }
    return {'timeoutMs': timeout};
  }

  static Map<String, dynamic> result(
    String action,
    Map<String, dynamic> raw, {
    List<String> allowedRecordTypes = const ['text', 'uri'],
    int recordLimit = maxRecords,
    int byteLimit = maxMessageBytes,
  }) {
    if (action == 'nfc.getState') {
      final supported = raw['supported'];
      final enabled = raw['enabled'];
      if (supported is! bool || enabled is! bool || (!supported && enabled)) {
        throw const FormatException('Invalid NFC availability result.');
      }
      return {'supported': supported, 'enabled': enabled};
    }
    if (action != 'nfc.read' ||
        recordLimit < 1 ||
        recordLimit > maxRecords ||
        byteLimit < 1 ||
        byteLimit > maxMessageBytes) {
      throw const FormatException('Invalid NFC result limits.');
    }
    final allowed = recordTypes(allowedRecordTypes);
    final records = raw['records'];
    if (records is! List || records.isEmpty || records.length > recordLimit) {
      throw const FormatException('Invalid NFC record count.');
    }
    var totalBytes = 0;
    final normalized = <Map<String, dynamic>>[];
    for (final record in records) {
      if (record is! Map || !allowed.contains(record['type'])) {
        throw const FormatException('Unsupported NFC record type.');
      }
      if (record['type'] == 'text') {
        final text = _text(record['text'], maxTextBytes);
        final language = record['language'];
        if (language is! String ||
            language.length > 63 ||
            !RegExp(r'^[a-zA-Z0-9-]*$').hasMatch(language)) {
          throw const FormatException('Invalid NFC text language.');
        }
        totalBytes += utf8.encode(text).length + language.length;
        normalized.add({'type': 'text', 'text': text, 'language': language});
      } else {
        final uri = _text(record['uri'], maxUriBytes);
        final parsed = Uri.tryParse(uri);
        if (parsed == null ||
            parsed.scheme != 'https' ||
            parsed.host.isEmpty ||
            parsed.userInfo.isNotEmpty ||
            RegExp(r'\s|[\\\x00-\x1f\x7f-\x9f]').hasMatch(uri) ||
            RegExp(
              r'%(?:0[0-9a-f]|1[0-9a-f]|7f)',
              caseSensitive: false,
            ).hasMatch(uri)) {
          throw const FormatException('Expected an absolute HTTPS NFC URI.');
        }
        totalBytes += utf8.encode(uri).length;
        normalized.add({'type': 'uri', 'uri': uri});
      }
      if (totalBytes > byteLimit) {
        throw const FormatException(
          'NFC record data exceeds accepted byte limits.',
        );
      }
    }
    return {'records': normalized};
  }

  static String _text(Object? value, int limit) {
    if (value is! String ||
        value.length > limit ||
        utf8.encode(value).length > limit ||
        value.runes.any((rune) => rune >= 0xd800 && rune <= 0xdfff) ||
        RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]').hasMatch(value)) {
      throw const FormatException('Invalid or oversized NFC text.');
    }
    return value;
  }
}
