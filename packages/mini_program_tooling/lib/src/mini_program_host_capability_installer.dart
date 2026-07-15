import 'dart:io';

import 'package:path/path.dart' as p;

class MiniProgramHostCapabilityInitRequest {
  const MiniProgramHostCapabilityInitRequest({
    required this.projectRootPath,
    required this.capability,
    required this.platform,
  });

  final String projectRootPath;
  final String capability;
  final String platform;
}

class MiniProgramHostCapabilityInitResult {
  const MiniProgramHostCapabilityInitResult({
    required this.projectRootPath,
    required this.capability,
    required this.platform,
    required this.createdPaths,
    required this.updatedPaths,
  });

  final String projectRootPath;
  final String capability;
  final String platform;
  final List<String> createdPaths;
  final List<String> updatedPaths;

  bool get alreadyInstalled => createdPaths.isEmpty && updatedPaths.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'projectRootPath': projectRootPath,
    'capability': capability,
    'platform': platform,
    'alreadyInstalled': alreadyInstalled,
    'createdPaths': createdPaths,
    'updatedPaths': updatedPaths,
  };
}

class MiniProgramHostCapabilityException implements Exception {
  const MiniProgramHostCapabilityException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Installs optional, host-owned native capability adapters.
///
/// Capability installation only makes a provider available to the SDK. It
/// never accepts a mini-program permission policy.
class MiniProgramHostCapabilityInstaller {
  const MiniProgramHostCapabilityInstaller();

  static const String locationCapability = 'location';
  static const String androidPlatform = 'android';

  Future<MiniProgramHostCapabilityInitResult> initialize(
    MiniProgramHostCapabilityInitRequest request,
  ) async {
    final capability = request.capability.trim().toLowerCase();
    final platform = request.platform.trim().toLowerCase();
    if (capability != locationCapability) {
      throw MiniProgramHostCapabilityException(
        'Unsupported host capability "$capability". Supported capabilities: '
        '$locationCapability.',
      );
    }
    if (platform != androidPlatform) {
      throw MiniProgramHostCapabilityException(
        'Host capability "$capability" currently supports only '
        '--platform android.',
      );
    }

    final projectRootPath = p.normalize(p.absolute(request.projectRootPath));
    final projectRoot = Directory(projectRootPath);
    if (!await projectRoot.exists()) {
      throw MiniProgramHostCapabilityException(
        'Flutter host project does not exist: $projectRootPath',
      );
    }

    final pubspecFile = File(p.join(projectRootPath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      throw MiniProgramHostCapabilityException(
        'Flutter host is missing pubspec.yaml: $projectRootPath',
      );
    }
    final pubspecSource = await pubspecFile.readAsString();
    if (!RegExp(
      r'^\s*flutter\s*:\s*$',
      multiLine: true,
    ).hasMatch(pubspecSource)) {
      throw MiniProgramHostCapabilityException(
        'Host capability installation requires a Flutter application: '
        '$projectRootPath',
      );
    }

    final integrationRootPath = p.join(projectRootPath, 'lib', 'mini_program');
    final hostSetupFile = File(
      p.join(integrationRootPath, 'mini_program_host_setup.dart'),
    );
    final runtimeSetupFile = File(
      p.join(integrationRootPath, 'mini_program_runtime_setup.dart'),
    );
    if (!await hostSetupFile.exists() || !await runtimeSetupFile.exists()) {
      throw MiniProgramHostCapabilityException(
        'Mini-program host integration is missing. Run '
        '`miniprogram embed init --project-root "$projectRootPath"` first.',
      );
    }

    final manifestFile = File(
      p.join(
        projectRootPath,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    );
    final kotlinRoot = Directory(
      p.join(projectRootPath, 'android', 'app', 'src', 'main', 'kotlin'),
    );
    if (!await manifestFile.exists() || !await kotlinRoot.exists()) {
      throw MiniProgramHostCapabilityException(
        'Android host files are missing. Add the Android platform to the '
        'Flutter host before installing location support.',
      );
    }

    final mainActivityFiles = await kotlinRoot
        .list(recursive: true, followLinks: false)
        .where(
          (entity) =>
              entity is File && p.basename(entity.path) == 'MainActivity.kt',
        )
        .cast<File>()
        .toList();
    if (mainActivityFiles.length != 1) {
      throw MiniProgramHostCapabilityException(
        'Expected exactly one Kotlin MainActivity.kt under '
        '${kotlinRoot.path}, found ${mainActivityFiles.length}.',
      );
    }

    final mainActivityFile = mainActivityFiles.single;
    final packageName = await _readKotlinPackage(mainActivityFile);
    final nativeChannelFile = File(
      p.join(mainActivityFile.parent.path, 'MiniProgramLocationChannel.kt'),
    );
    final dartProviderFile = File(
      p.join(integrationRootPath, 'app_android_location_provider.dart'),
    );

    final hostSetupSource = await hostSetupFile.readAsString();
    final manifestSource = await manifestFile.readAsString();
    final mainActivitySource = await mainActivityFile.readAsString();
    final dartProviderSource = await _readIfExists(dartProviderFile);
    final nativeChannelSource = await _readIfExists(nativeChannelFile);

    _validateOwnedFile(
      file: dartProviderFile,
      source: dartProviderSource,
      requiredMarker: 'class AppAndroidLocationProvider',
    );
    _validateOwnedFile(
      file: nativeChannelFile,
      source: nativeChannelSource,
      requiredMarker: 'class MiniProgramLocationChannel',
    );

    if (_isLocationInstalled(
      hostSetupSource: hostSetupSource,
      manifestSource: manifestSource,
      mainActivitySource: mainActivitySource,
      dartProviderSource: dartProviderSource,
      nativeChannelSource: nativeChannelSource,
    )) {
      return MiniProgramHostCapabilityInitResult(
        projectRootPath: projectRootPath,
        capability: capability,
        platform: platform,
        createdPaths: const <String>[],
        updatedPaths: const <String>[],
      );
    }

    final writes = <String, String>{};
    if (dartProviderSource == null) {
      writes[dartProviderFile.path] = _dartLocationProviderSource;
    }

    final patchedHostSetup = _patchHostSetup(hostSetupSource);
    if (patchedHostSetup != hostSetupSource) {
      writes[hostSetupFile.path] = patchedHostSetup;
    }

    final patchedManifest = _patchAndroidManifest(manifestSource);
    if (patchedManifest != manifestSource) {
      writes[manifestFile.path] = patchedManifest;
    }

    final hasDirectNativeChannel = mainActivitySource.contains(
      'mini_program/location',
    );
    if (!hasDirectNativeChannel) {
      if (nativeChannelSource == null) {
        writes[nativeChannelFile.path] = _androidLocationChannelSource(
          packageName,
        );
      }
      final patchedMainActivity = _patchMainActivity(mainActivitySource);
      if (patchedMainActivity != mainActivitySource) {
        writes[mainActivityFile.path] = patchedMainActivity;
      }
    }

    if (writes.isEmpty) {
      throw const MiniProgramHostCapabilityException(
        'Android location capability is only partially configured, and the '
        'installer could not determine a safe update. Review the host setup, '
        'manifest, provider adapter, and MainActivity integration.',
      );
    }

    final createdPaths = <String>[];
    final updatedPaths = <String>[];
    for (final entry in writes.entries) {
      final file = File(entry.key);
      final existed = await file.exists();
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
      (existed ? updatedPaths : createdPaths).add(file.path);
    }
    createdPaths.sort();
    updatedPaths.sort();

    return MiniProgramHostCapabilityInitResult(
      projectRootPath: projectRootPath,
      capability: capability,
      platform: platform,
      createdPaths: List<String>.unmodifiable(createdPaths),
      updatedPaths: List<String>.unmodifiable(updatedPaths),
    );
  }

  Future<String> _readKotlinPackage(File mainActivityFile) async {
    final source = await mainActivityFile.readAsString();
    final match = RegExp(
      r'^\s*package\s+([A-Za-z_][A-Za-z0-9_.]*)\s*$',
      multiLine: true,
    ).firstMatch(source);
    final packageName = match?.group(1)?.trim() ?? '';
    if (packageName.isEmpty) {
      throw MiniProgramHostCapabilityException(
        'Could not read the Kotlin package from ${mainActivityFile.path}.',
      );
    }
    return packageName;
  }

  Future<String?> _readIfExists(File file) async {
    return await file.exists() ? file.readAsString() : null;
  }

  void _validateOwnedFile({
    required File file,
    required String? source,
    required String requiredMarker,
  }) {
    if (source != null && !source.contains(requiredMarker)) {
      throw MiniProgramHostCapabilityException(
        'Refusing to overwrite the existing host-owned file ${file.path}. '
        'Move or reconcile that file, then run the capability installer again.',
      );
    }
  }

  bool _isLocationInstalled({
    required String hostSetupSource,
    required String manifestSource,
    required String mainActivitySource,
    required String? dartProviderSource,
    required String? nativeChannelSource,
  }) {
    final hasProvider =
        dartProviderSource?.contains('class AppAndroidLocationProvider') ??
        false;
    final hasHostProvider =
        hostSetupSource.contains('AppAndroidLocationProvider') &&
        hostSetupSource.contains('locationProvider:');
    final hasPermission = manifestSource.contains(
      'android.permission.ACCESS_COARSE_LOCATION',
    );
    final hasNativeChannel =
        mainActivitySource.contains('mini_program/location') ||
        (mainActivitySource.contains('MiniProgramLocationChannel.register') &&
            (nativeChannelSource?.contains(
                  'class MiniProgramLocationChannel',
                ) ??
                false));
    return hasProvider && hasHostProvider && hasPermission && hasNativeChannel;
  }

  String _patchHostSetup(String source) {
    if (!source.contains(
      'Future<MiniProgramConfig> buildHostMiniProgramConfig(',
    )) {
      throw const MiniProgramHostCapabilityException(
        'mini_program_host_setup.dart does not contain the generated '
        'buildHostMiniProgramConfig function. Reconcile the host-owned setup '
        'before installing location support.',
      );
    }

    final newline = _newlineFor(source);
    var updated = _ensureImport(
      source,
      "import 'package:flutter/foundation.dart';",
      before: "import 'package:mini_program_sdk/mini_program_sdk.dart';",
    );
    updated = _ensureImport(
      updated,
      "import 'app_android_location_provider.dart';",
      before: "import 'app_host_bridge.dart';",
    );

    final signatureStart = updated.indexOf(
      'Future<MiniProgramConfig> buildHostMiniProgramConfig(',
    );
    final signatureEnd = updated.indexOf('}) async {', signatureStart);
    if (signatureEnd == -1) {
      throw const MiniProgramHostCapabilityException(
        'Could not safely update buildHostMiniProgramConfig parameters.',
      );
    }
    final signature = updated.substring(signatureStart, signatureEnd);
    if (!signature.contains('MiniProgramLocationProvider? locationProvider')) {
      updated = updated.replaceRange(
        signatureEnd,
        signatureEnd,
        '  MiniProgramLocationProvider? locationProvider,$newline',
      );
    }

    if (!updated.contains('final resolvedLocationProvider =')) {
      final returnIndex = updated.indexOf(
        '  return buildMiniProgramConfig(',
        signatureStart,
      );
      if (returnIndex == -1) {
        throw const MiniProgramHostCapabilityException(
          'Could not safely locate buildMiniProgramConfig in the host setup.',
        );
      }
      final resolution =
          '  final resolvedLocationProvider =$newline'
          '      locationProvider ??$newline'
          '      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android$newline'
          '          ? const AppAndroidLocationProvider()$newline'
          '          : null);$newline';
      updated = updated.replaceRange(
        returnIndex,
        returnIndex,
        '$resolution$newline',
      );
    }

    final directProviderPattern = RegExp(
      r'locationProvider:\s*locationProvider,',
    );
    if (directProviderPattern.hasMatch(updated)) {
      updated = updated.replaceFirst(
        directProviderPattern,
        'locationProvider: resolvedLocationProvider,',
      );
    } else if (!updated.contains(
      'locationProvider: resolvedLocationProvider,',
    )) {
      final callStart = updated.indexOf(
        '  return buildMiniProgramConfig(',
        signatureStart,
      );
      final callEnd = updated.indexOf('  );', callStart);
      if (callStart == -1 || callEnd == -1) {
        throw const MiniProgramHostCapabilityException(
          'Could not safely wire the location provider into '
          'buildMiniProgramConfig.',
        );
      }
      updated = updated.replaceRange(
        callEnd,
        callEnd,
        '    locationProvider: resolvedLocationProvider,$newline',
      );
    }
    return updated;
  }

  String _patchAndroidManifest(String source) {
    const permission = 'android.permission.ACCESS_COARSE_LOCATION';
    if (source.contains(permission)) {
      return source;
    }
    final newline = _newlineFor(source);
    const declaration =
        '    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>';
    final internetPattern = RegExp(
      r'^[ \t]*<uses-permission\s+android:name="android\.permission\.INTERNET"\s*/>[ \t]*$',
      multiLine: true,
    );
    final internetMatch = internetPattern.firstMatch(source);
    if (internetMatch != null) {
      return source.replaceRange(
        internetMatch.end,
        internetMatch.end,
        '$newline$declaration',
      );
    }
    final manifestEnd = source.indexOf('>');
    if (manifestEnd == -1 ||
        !source.substring(0, manifestEnd).contains('<manifest')) {
      throw const MiniProgramHostCapabilityException(
        'AndroidManifest.xml does not contain a valid <manifest> root.',
      );
    }
    return source.replaceRange(
      manifestEnd + 1,
      manifestEnd + 1,
      '$newline$declaration',
    );
  }

  String _patchMainActivity(String source) {
    if (source.contains('MiniProgramLocationChannel.register')) {
      return source;
    }
    final newline = _newlineFor(source);
    var updated = _ensureImport(
      source,
      'import io.flutter.embedding.engine.FlutterEngine',
      before: 'import io.flutter.plugin',
      fallbackAfter: 'import io.flutter.embedding.android.FlutterActivity',
    );

    final classMatch = RegExp(
      r'class\s+MainActivity\s*:\s*FlutterActivity\(\)',
    ).firstMatch(updated);
    if (classMatch == null) {
      throw const MiniProgramHostCapabilityException(
        'MainActivity.kt must define `class MainActivity : FlutterActivity()` '
        'for automatic location capability installation.',
      );
    }
    final classTail = updated.substring(classMatch.end);
    final firstContentIndex = classTail.indexOf(RegExp(r'\S'));
    if (firstContentIndex == -1) {
      final replacement =
          'class MainActivity : FlutterActivity() {$newline'
          '    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {$newline'
          '        super.configureFlutterEngine(flutterEngine)$newline'
          '        MiniProgramLocationChannel.register(flutterEngine)$newline'
          '    }$newline'
          '}';
      return updated.replaceRange(
        classMatch.start,
        updated.length,
        replacement,
      );
    }
    if (classTail[firstContentIndex] != '{') {
      throw const MiniProgramHostCapabilityException(
        'MainActivity.kt uses an unsupported custom class declaration. Add '
        '`MiniProgramLocationChannel.register(flutterEngine)` manually.',
      );
    }

    if (updated.contains('override fun configureFlutterEngine(')) {
      const superCall = 'super.configureFlutterEngine(flutterEngine)';
      final superIndex = updated.indexOf(superCall, classMatch.end);
      if (superIndex == -1) {
        throw const MiniProgramHostCapabilityException(
          'MainActivity.configureFlutterEngine must call '
          'super.configureFlutterEngine(flutterEngine) before the location '
          'channel can be installed automatically.',
        );
      }
      final insertAt = superIndex + superCall.length;
      return updated.replaceRange(
        insertAt,
        insertAt,
        '$newline        MiniProgramLocationChannel.register(flutterEngine)',
      );
    }

    final classEnd = updated.lastIndexOf('}');
    if (classEnd == -1 || classEnd < classMatch.end) {
      throw const MiniProgramHostCapabilityException(
        'Could not safely locate the end of MainActivity.kt.',
      );
    }
    final method =
        '    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {$newline'
        '        super.configureFlutterEngine(flutterEngine)$newline'
        '        MiniProgramLocationChannel.register(flutterEngine)$newline'
        '    }$newline';
    return updated.replaceRange(classEnd, classEnd, '$method$newline');
  }

  String _ensureImport(
    String source,
    String statement, {
    String? before,
    String? fallbackAfter,
  }) {
    if (source.contains(statement)) {
      return source;
    }
    final newline = _newlineFor(source);
    if (before != null) {
      final beforeIndex = source.indexOf(before);
      if (beforeIndex != -1) {
        return source.replaceRange(
          beforeIndex,
          beforeIndex,
          '$statement$newline',
        );
      }
    }
    if (fallbackAfter != null) {
      final afterIndex = source.indexOf(fallbackAfter);
      if (afterIndex != -1) {
        final insertAt = afterIndex + fallbackAfter.length;
        return source.replaceRange(insertAt, insertAt, '$newline$statement');
      }
    }
    final lastImport = RegExp(
      r'^import .+?;?\s*$',
      multiLine: true,
    ).allMatches(source).lastOrNull;
    if (lastImport == null) {
      throw MiniProgramHostCapabilityException(
        'Could not safely add `$statement` because the target file has no '
        'recognized imports.',
      );
    }
    return source.replaceRange(
      lastImport.end,
      lastImport.end,
      '$newline$statement',
    );
  }

  String _newlineFor(String source) => source.contains('\r\n') ? '\r\n' : '\n';

  static const String _dartLocationProviderSource =
      r'''import 'package:flutter/services.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

/// Host-owned Android adapter for one-time approximate foreground location.
///
/// Created by `miniprogram host capability init location`. Tooling will not
/// overwrite this file after installation.
class AppAndroidLocationProvider implements MiniProgramLocationProvider {
  const AppAndroidLocationProvider({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  static const String channelName = 'mini_program/location';

  final MethodChannel _channel;

  @override
  Future<MiniProgramLocationResult> getCurrentLocation({
    required MiniProgramLocationAccuracy accuracy,
    required Duration timeout,
  }) async {
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'getCurrentLocation',
        <String, Object?>{
          'accuracy': accuracy.wireValue,
          'timeoutMs': timeout.inMilliseconds,
        },
      );
      if (response == null) {
        throw const MiniProgramLocationException(
          errorCode: MiniProgramErrorCodes.locationInvalidResult,
          message: 'Android returned an empty current-location result.',
        );
      }
      try {
        return MiniProgramLocationResult.fromJson(response);
      } on FormatException catch (error) {
        throw MiniProgramLocationException(
          errorCode: MiniProgramErrorCodes.locationInvalidResult,
          message: error.message.toString(),
        );
      }
    } on PlatformException catch (error) {
      final code = _stableErrorCode(error.code);
      throw MiniProgramLocationException(
        errorCode: code,
        message: error.message ?? _defaultMessage(code),
        details: <String, Object?>{
          if (error.details != null) 'platformDetails': '${error.details}',
        },
      );
    } on MissingPluginException {
      throw const MiniProgramLocationException(
        errorCode: MiniProgramErrorCodes.locationUnavailable,
        message: 'Android current-location support is unavailable.',
      );
    }
  }

  static String _stableErrorCode(String code) {
    return switch (code) {
      MiniProgramErrorCodes.locationPermissionDenied => code,
      MiniProgramErrorCodes.locationPermissionDeniedPermanently => code,
      MiniProgramErrorCodes.locationServiceDisabled => code,
      MiniProgramErrorCodes.locationTimeout => code,
      MiniProgramErrorCodes.locationRequestInProgress => code,
      MiniProgramErrorCodes.locationInvalidResult => code,
      _ => MiniProgramErrorCodes.locationUnavailable,
    };
  }

  static String _defaultMessage(String code) {
    return switch (code) {
      MiniProgramErrorCodes.locationPermissionDenied =>
        'Approximate location permission was denied.',
      MiniProgramErrorCodes.locationPermissionDeniedPermanently =>
        'Approximate location permission is permanently denied.',
      MiniProgramErrorCodes.locationServiceDisabled =>
        'Android location services are disabled.',
      MiniProgramErrorCodes.locationTimeout =>
        'The current-location request timed out.',
      MiniProgramErrorCodes.locationRequestInProgress =>
        'A current-location request is already in progress.',
      MiniProgramErrorCodes.locationInvalidResult =>
        'Android returned an invalid current-location result.',
      _ => 'Android current location is unavailable.',
    };
  }
}
''';

  String _androidLocationChannelSource(String packageName) =>
      '''package $packageName

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Host-owned channel for one-time approximate foreground location.
 *
 * Created by `miniprogram host capability init location`. Tooling will not
 * overwrite this file after installation.
 */
internal class MiniProgramLocationChannel :
    FlutterPlugin,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener,
    DefaultLifecycleObserver {
    companion object {
        private const val CHANNEL_NAME = "mini_program/location"
        private const val LOCATION_PERMISSION_REQUEST = 4101
        private const val PREFS_NAME = "mini_program_location"
        private const val PREF_PERMISSION_REQUESTED = "coarse_permission_requested"
        private const val DEFAULT_TIMEOUT_MS = 10_000L
        private const val MAX_CACHED_LOCATION_AGE_MS = 15 * 60_000L
        private const val CACHED_FALLBACK_DELAY_MS = 2_500L

        fun register(flutterEngine: FlutterEngine) {
            flutterEngine.plugins.add(MiniProgramLocationChannel())
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var channel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingTimeoutMs = DEFAULT_TIMEOUT_MS
    private var permissionHadBeenRequested = false
    private var awaitingPermission = false
    private var locationListener: LocationListener? = null
    private var cancellationSignal: CancellationSignal? = null
    private var timeoutRunnable: Runnable? = null
    private var cachedFallbackRunnable: Runnable? = null
    private var cachedFallbackLocation: Location? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(::handleLocationCall)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (pendingResult != null) {
            failPending(
                "location_unavailable",
                "The location provider detached from the Flutter engine.",
            )
        }
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachToActivity(binding)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attachToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachFromActivity(
            "The location request stopped while Android configuration changed.",
        )
    }

    override fun onDetachedFromActivity() {
        detachFromActivity(
            "The location request stopped because the host activity detached.",
        )
    }

    private fun attachToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
        (binding.activity as? LifecycleOwner)?.lifecycle?.addObserver(this)
    }

    private fun detachFromActivity(message: String) {
        if (pendingResult != null) {
            failPending("location_unavailable", message)
        }
        val currentActivity = activity
        if (currentActivity is LifecycleOwner) {
            currentActivity.lifecycle.removeObserver(this)
        }
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    private fun handleLocationCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "getCurrentLocation") {
            result.notImplemented()
            return
        }
        if (pendingResult != null) {
            result.error(
                "location_request_in_progress",
                "A current-location request is already in progress.",
                null,
            )
            return
        }
        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                "location_unavailable",
                "Android current location is unavailable without a foreground activity.",
                null,
            )
            return
        }
        val arguments = call.arguments as? Map<*, *>
        if (arguments?.get("accuracy") != "approximate") {
            result.error(
                "location_invalid_result",
                "Only approximate location is supported.",
                null,
            )
            return
        }
        val timeoutMs = (arguments?.get("timeoutMs") as? Number)?.toLong()
        if (timeoutMs == null || timeoutMs !in 1_000L..60_000L) {
            result.error(
                "location_invalid_result",
                "Location timeout must be from 1 to 60 seconds.",
                null,
            )
            return
        }

        pendingResult = result
        pendingTimeoutMs = timeoutMs
        scheduleTimeout()

        val manager = currentActivity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        if (!manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            failPending(
                "location_service_disabled",
                "Android network location services are disabled.",
            )
            return
        }

        if (hasPermission()) {
            startLocationRequest(manager)
            return
        }

        val preferences = currentActivity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        permissionHadBeenRequested = preferences.getBoolean(
            PREF_PERMISSION_REQUESTED,
            false,
        )
        if (permissionHadBeenRequested &&
            !ActivityCompat.shouldShowRequestPermissionRationale(
                currentActivity,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            )
        ) {
            failPending(
                "location_permission_denied_permanently",
                "Approximate location permission is permanently denied.",
            )
            return
        }

        awaitingPermission = true
        preferences.edit().putBoolean(PREF_PERMISSION_REQUESTED, true).apply()
        ActivityCompat.requestPermissions(
            currentActivity,
            arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION),
            LOCATION_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != LOCATION_PERMISSION_REQUEST || pendingResult == null) {
            return false
        }
        awaitingPermission = false
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) {
            val currentActivity = activity
            if (currentActivity == null) {
                failPending(
                    "location_unavailable",
                    "Android current location is unavailable without a foreground activity.",
                )
                return true
            }
            val manager = currentActivity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            startLocationRequest(manager)
            return true
        }
        val currentActivity = activity
        val permanentlyDenied = permissionHadBeenRequested &&
            currentActivity != null &&
            !ActivityCompat.shouldShowRequestPermissionRationale(
                currentActivity,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            )
        failPending(
            if (permanentlyDenied) {
                "location_permission_denied_permanently"
            } else {
                "location_permission_denied"
            },
            if (permanentlyDenied) {
                "Approximate location permission is permanently denied."
            } else {
                "Approximate location permission was denied."
            },
        )
        return true
    }

    private fun hasPermission(): Boolean =
        activity?.let {
            ContextCompat.checkSelfPermission(
                it,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        } ?: false

    private fun startLocationRequest(locationManager: LocationManager) {
        if (pendingResult == null) return
        val currentActivity = activity
        if (currentActivity == null) {
            failPending(
                "location_unavailable",
                "Android current location is unavailable without a foreground activity.",
            )
            return
        }
        if (!locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            failPending(
                "location_service_disabled",
                "Android network location services are disabled.",
            )
            return
        }
        if (!hasPermission()) {
            failPending(
                "location_permission_denied",
                "Approximate location permission was denied.",
            )
            return
        }

        try {
            cachedFallbackLocation = recentNetworkLocation(locationManager)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val signal = CancellationSignal()
                cancellationSignal = signal
                locationManager.getCurrentLocation(
                    LocationManager.NETWORK_PROVIDER,
                    signal,
                    currentActivity.mainExecutor,
                ) { location ->
                    if (location == null) {
                        if (!completeWithCachedFallback()) {
                            failPending(
                                "location_unavailable",
                                "Android could not determine the current location.",
                            )
                        }
                    } else {
                        completePending(location)
                    }
                }
                scheduleCachedFallback()
            } else {
                @Suppress("DEPRECATION")
                val listener = object : LocationListener {
                    override fun onLocationChanged(location: Location) {
                        completePending(location)
                    }

                    override fun onProviderDisabled(provider: String) {
                        failPending(
                            "location_service_disabled",
                            "Android network location services are disabled.",
                        )
                    }

                    @Deprecated("Deprecated by Android")
                    override fun onStatusChanged(
                        provider: String?,
                        status: Int,
                        extras: Bundle?,
                    ) = Unit

                    override fun onProviderEnabled(provider: String) = Unit
                }
                locationListener = listener
                @Suppress("DEPRECATION")
                locationManager.requestSingleUpdate(
                    LocationManager.NETWORK_PROVIDER,
                    listener,
                    Looper.getMainLooper(),
                )
                scheduleCachedFallback()
            }
        } catch (_: SecurityException) {
            failPending(
                "location_permission_denied",
                "Approximate location permission was denied.",
            )
        } catch (_: Exception) {
            if (!completeWithCachedFallback()) {
                failPending(
                    "location_unavailable",
                    "Android current location is unavailable.",
                )
            }
        }
    }

    private fun recentNetworkLocation(locationManager: LocationManager): Location? {
        val location = try {
            @Suppress("MissingPermission")
            locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
        } catch (_: Exception) {
            null
        } ?: return null
        val ageMs = System.currentTimeMillis() - location.time
        if (ageMs !in 0..MAX_CACHED_LOCATION_AGE_MS) return null
        if (!location.latitude.isFinite() || location.latitude !in -90.0..90.0) return null
        if (!location.longitude.isFinite() || location.longitude !in -180.0..180.0) return null
        if (location.hasAccuracy() &&
            (!location.accuracy.isFinite() || location.accuracy < 0f)
        ) {
            return null
        }
        return location
    }

    private fun scheduleCachedFallback() {
        if (cachedFallbackLocation == null) return
        val delayMs = minOf(
            CACHED_FALLBACK_DELAY_MS,
            (pendingTimeoutMs - 500L).coerceAtLeast(500L),
        )
        val runnable = Runnable { completeWithCachedFallback() }
        cachedFallbackRunnable = runnable
        mainHandler.postDelayed(runnable, delayMs)
    }

    private fun completeWithCachedFallback(): Boolean {
        val location = cachedFallbackLocation ?: return false
        if (pendingResult == null) return false
        completePending(location)
        return true
    }

    private fun scheduleTimeout() {
        val runnable = Runnable {
            if (!completeWithCachedFallback()) {
                failPending(
                    "location_timeout",
                    "The current-location request timed out. Check Wi-Fi, mobile data, and Android location accuracy settings.",
                )
            }
        }
        timeoutRunnable = runnable
        mainHandler.postDelayed(runnable, pendingTimeoutMs)
    }

    private fun completePending(location: Location) {
        val result = pendingResult ?: return
        clearPending()
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        result.success(
            mapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "accuracyMeters" to if (location.hasAccuracy()) {
                    location.accuracy.toDouble()
                } else {
                    0.0
                },
                "capturedAtUtc" to formatter.format(Date(location.time)),
                "source" to "device",
            ),
        )
    }

    private fun failPending(code: String, message: String) {
        val result = pendingResult ?: return
        clearPending()
        result.error(code, message, null)
    }

    private fun clearPending() {
        timeoutRunnable?.let(mainHandler::removeCallbacks)
        timeoutRunnable = null
        cachedFallbackRunnable?.let(mainHandler::removeCallbacks)
        cachedFallbackRunnable = null
        cachedFallbackLocation = null
        cancellationSignal?.cancel()
        cancellationSignal = null
        val listener = locationListener
        if (listener != null) {
            val currentActivity = activity
            if (currentActivity != null) {
                val manager = currentActivity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
                manager.removeUpdates(listener)
            }
        }
        locationListener = null
        pendingResult = null
        awaitingPermission = false
    }

    override fun onStop(owner: LifecycleOwner) {
        if (pendingResult != null && !awaitingPermission) {
            failPending(
                "location_unavailable",
                "The location request stopped when the host left the foreground.",
            )
        }
    }

    override fun onDestroy(owner: LifecycleOwner) {
        if (pendingResult != null) {
            failPending(
                "location_unavailable",
                "The location request stopped because the host was destroyed.",
            )
        }
        owner.lifecycle.removeObserver(this)
    }
}
''';
}
