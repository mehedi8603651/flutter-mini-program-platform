import 'dart:io';

import 'integration_paths.dart';
import 'main_activity_editor.dart';
import 'native_setup.dart';

class AndroidNativeIntegrationEdit {
  const AndroidNativeIntegrationEdit({
    required this.paths,
    required this.setupSource,
    required this.mainActivitySource,
    required this.writes,
  });

  final AndroidNativeIntegrationPaths paths;
  final String setupSource;
  final String mainActivitySource;
  final Map<String, String> writes;
}

Future<AndroidNativeIntegrationEdit> buildAndroidNativeIntegrationEdit({
  required File mainActivityFile,
  required String packageName,
  required String mainActivitySource,
  required String registration,
  bool requiresFragmentActivity = false,
}) async {
  final paths = AndroidNativeIntegrationPaths(mainActivityFile);
  final currentSetup = await paths.setupFile.exists()
      ? await paths.setupFile.readAsString()
      : null;
  final nextSetup = buildAndroidNativeSetupSource(
    packageName: packageName,
    mainActivitySource: mainActivitySource,
    currentSource: currentSetup,
    registration: registration,
  );
  final nextMainActivity = patchAndroidMainActivityRegistration(
    mainActivitySource,
    registration: registration,
    requiresFragmentActivity: requiresFragmentActivity,
  );
  final writes = <String, String>{
    if (currentSetup != nextSetup) paths.setupFile.path: nextSetup,
    if (!await paths.ownershipFile.exists())
      paths.ownershipFile.path: androidNativeIntegrationReadme,
    if (nextMainActivity != mainActivitySource)
      mainActivityFile.path: nextMainActivity,
  };
  return AndroidNativeIntegrationEdit(
    paths: paths,
    setupSource: nextSetup,
    mainActivitySource: nextMainActivity,
    writes: writes,
  );
}
