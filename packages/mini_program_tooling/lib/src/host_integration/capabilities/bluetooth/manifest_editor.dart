import '../models.dart';

/// Adds only BLE central permissions. Hardware remains optional so the host can
/// still install on phones without Bluetooth LE.
String patchBluetoothManifest(String source) {
  var next = source;
  final declarations = source.replaceAllMapped(
    RegExp(r'<!--[\s\S]*?-->'),
    (match) => ' ' * match.group(0)!.length,
  );
  final additions = <String>[];
  for (final entry in <String, String>{
    'BLUETOOTH': ' android:maxSdkVersion="30"',
    'BLUETOOTH_ADMIN': ' android:maxSdkVersion="30"',
    'ACCESS_FINE_LOCATION': ' android:maxSdkVersion="30"',
    'BLUETOOTH_SCAN': ' android:usesPermissionFlags="neverForLocation"',
    'BLUETOOTH_CONNECT': '',
  }.entries) {
    final permission = 'android.permission.${entry.key}';
    final matches = RegExp(
      '<uses-permission\\b[^>]*android:name\\s*=\\s*["\\\']${RegExp.escape(permission)}["\\\'][^>]*>',
    ).allMatches(declarations).toList();
    if (matches.length > 1) {
      throw MiniProgramHostCapabilityException(
        'Duplicate Android permission $permission.',
      );
    }
    if (matches.isEmpty) {
      additions.add(
        '<uses-permission android:name="$permission"${entry.value} />',
      );
    } else {
      final tag = matches.single.group(0)!;
      if (RegExp(r'\btools:(?:node|remove|replace)\s*=').hasMatch(tag)) {
        throw MiniProgramHostCapabilityException(
          'Reconcile the host-owned merge rules for $permission before installing BLE.',
        );
      }
      // Existing host permissions may legitimately cover more uses. Never
      // narrow them or silently claim location-free scanning on its behalf.
      final flags = RegExp(
        r'''android:usesPermissionFlags\s*=\s*["']([^"']*)["']''',
      ).firstMatch(tag)?.group(1)?.split('|');
      if (entry.key == 'BLUETOOTH_SCAN' &&
          flags?.contains('neverForLocation') != true) {
        throw const MiniProgramHostCapabilityException(
          'Existing BLUETOOTH_SCAN must declare neverForLocation for this adapter; review the host location requirements first.',
        );
      }
      if (entry.key == 'BLUETOOTH_SCAN' || entry.key == 'BLUETOOTH_CONNECT') {
        if (tag.contains('maxSdkVersion')) {
          throw MiniProgramHostCapabilityException(
            '$permission must not be limited to older Android versions.',
          );
        }
      } else if (tag.contains('maxSdkVersion')) {
        final maximum = RegExp(
          r'''android:maxSdkVersion\s*=\s*["'](\d+)["']''',
        ).firstMatch(tag)?.group(1);
        if (maximum == null || int.parse(maximum) < 30) {
          throw MiniProgramHostCapabilityException(
            '$permission must cover Android 11 for legacy BLE scanning.',
          );
        }
      }
    }
  }
  if (!declarations.contains('android.hardware.bluetooth_le')) {
    additions.add(
      '<uses-feature android:name="android.hardware.bluetooth_le" android:required="false" />',
    );
  }
  if (additions.isEmpty) return next;
  final root = declarations.indexOf('<manifest');
  final insert = root < 0 ? -1 : declarations.indexOf('>', root);
  if (insert < 0 || !declarations.contains('</manifest>')) {
    throw const MiniProgramHostCapabilityException('Invalid Android manifest.');
  }
  final newline = next.contains('\r\n') ? '\r\n' : '\n';
  next = next.replaceRange(
    insert + 1,
    insert + 1,
    '$newline    ${additions.join('$newline    ')}',
  );
  return next;
}
