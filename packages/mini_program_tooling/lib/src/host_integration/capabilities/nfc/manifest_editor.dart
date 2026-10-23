import '../models.dart';

/// NFC hardware stays optional. Existing host declarations are never narrowed.
String patchNfcManifest(String source) {
  final declarations = source.replaceAllMapped(
    RegExp(r'<!--[\s\S]*?-->'),
    (match) => ' ' * match.group(0)!.length,
  );
  final additions = <String>[];
  final permission = RegExp(
    r'''<uses-permission\b[^>]*android:name\s*=\s*["']android\.permission\.NFC["'][^>]*>''',
  ).allMatches(declarations).toList();
  final feature = RegExp(
    r'''<uses-feature\b[^>]*android:name\s*=\s*["']android\.hardware\.nfc["'][^>]*>''',
  ).allMatches(declarations).toList();
  if (permission.length > 1 || feature.length > 1) {
    throw const MiniProgramHostCapabilityException(
      'Duplicate NFC manifest declarations.',
    );
  }
  for (final match in [...permission, ...feature]) {
    final tag = match.group(0)!;
    if (RegExp(r'\btools:(?:node|remove|replace)\s*=').hasMatch(tag) ||
        (permission.contains(match) && tag.contains('maxSdkVersion'))) {
      throw const MiniProgramHostCapabilityException(
        'Reconcile host-owned NFC manifest restrictions before installation.',
      );
    }
  }
  if (permission.isEmpty) {
    additions.add('<uses-permission android:name="android.permission.NFC" />');
  }
  if (feature.isEmpty) {
    additions.add(
      '<uses-feature android:name="android.hardware.nfc" android:required="false" />',
    );
  }
  final root = declarations.indexOf('<manifest');
  final insert = root < 0 ? -1 : declarations.indexOf('>', root);
  if (insert < 0 || !declarations.contains('</manifest>')) {
    throw const MiniProgramHostCapabilityException('Invalid Android manifest.');
  }
  if (additions.isEmpty) return source;
  final newline = source.contains('\r\n') ? '\r\n' : '\n';
  return source.replaceRange(
    insert + 1,
    insert + 1,
    '$newline    ${additions.join('$newline    ')}',
  );
}
