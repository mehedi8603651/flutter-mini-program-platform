import 'dart:io';

import 'package:path/path.dart' as path;

Map<String, String> buildPreviewHostPlatformFiles(String hostRootPath) {
  final files = <String, String>{};
  final androidDebugDirectory = Directory(
    path.join(hostRootPath, 'android', 'app', 'src', 'debug'),
  );
  if (androidDebugDirectory.existsSync()) {
    files[path.join(androidDebugDirectory.path, 'AndroidManifest.xml')] =
        _buildAndroidDebugManifest();
    files[path.join(
          androidDebugDirectory.path,
          'res',
          'xml',
          'mini_program_preview_network_security_config.xml',
        )] =
        _buildAndroidDebugNetworkSecurityConfig();
  }
  return files;
}

String _buildAndroidDebugManifest() {
  return '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application
        android:usesCleartextTraffic="true"
        android:networkSecurityConfig="@xml/mini_program_preview_network_security_config" />
</manifest>
''';
}

String _buildAndroidDebugNetworkSecurityConfig() {
  return '''
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true" />
</network-security-config>
''';
}
