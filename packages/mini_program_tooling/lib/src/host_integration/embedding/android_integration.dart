import 'dart:io';

import 'package:path/path.dart' as path;

Map<String, String> buildEmbeddingPlatformIntegrationFiles({
  required String projectRootPath,
}) {
  final files = <String, String>{};
  final androidMainManifest = File(
    path.join(
      projectRootPath,
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    ),
  );
  if (androidMainManifest.existsSync()) {
    files[androidMainManifest.path] = _ensureAndroidInternetPermission(
      androidMainManifest.readAsStringSync(),
    );
  }

  final androidDebugDirectory = Directory(
    path.join(projectRootPath, 'android', 'app', 'src', 'debug'),
  );
  if (androidDebugDirectory.existsSync()) {
    files[path.join(androidDebugDirectory.path, 'AndroidManifest.xml')] =
        _buildAndroidDebugManifest();
    files[path.join(
          androidDebugDirectory.path,
          'res',
          'xml',
          'mini_program_network_security_config.xml',
        )] =
        _buildAndroidDebugNetworkSecurityConfig();
  }
  return files;
}

String _ensureAndroidInternetPermission(String source) {
  if (source.contains('android.permission.INTERNET')) {
    return source;
  }

  final normalizedSource = source.replaceAll('\r\n', '\n');
  final manifestMatch = RegExp(
    r'<manifest\b[^>]*>',
    multiLine: true,
  ).firstMatch(normalizedSource);
  if (manifestMatch == null) {
    return source;
  }

  return normalizedSource.replaceRange(
    manifestMatch.end,
    manifestMatch.end,
    '\n    <uses-permission android:name="android.permission.INTERNET"/>',
  );
}

String _buildAndroidDebugManifest() {
  return '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application
        android:usesCleartextTraffic="true"
        android:networkSecurityConfig="@xml/mini_program_network_security_config"
        tools:replace="android:usesCleartextTraffic" />
</manifest>
''';
}

String _buildAndroidDebugNetworkSecurityConfig() {
  return '''
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">10.0.2.2</domain>
        <domain includeSubdomains="true">127.0.0.1</domain>
        <domain includeSubdomains="true">localhost</domain>
    </domain-config>
</network-security-config>
''';
}
