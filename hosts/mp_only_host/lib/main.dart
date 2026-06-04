import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  runApp(const MpOnlyHostApp());
}

class MpOnlyHostApp extends StatelessWidget {
  const MpOnlyHostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MiniProgramScope(
      config: MiniProgramConfig(
        sdkVersion: '1.0.0',
        source: const _BundledMpSource(),
        hostBridge: const _MpOnlyHostBridge(),
        capabilityRegistry: CapabilityRegistry(const <CapabilityId>[
          CapabilityIds.analytics,
        ]),
        cacheBundle: MiniProgramCacheBundle.inMemory(),
      ),
      child: MaterialApp(
        title: 'Mp-only Host',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006B5E)),
        ),
        home: const _HomePage(),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mp-only Host')),
      body: Center(
        child: FilledButton(
          onPressed: () => MiniProgramScope.of(context).openMiniProgram<void>(
            appId: 'mp_profile_center',
            title: 'Mp Profile Center',
          ),
          child: const Text('Open Mp Profile Center'),
        ),
      ),
    );
  }
}

class _BundledMpSource implements MiniProgramSource {
  const _BundledMpSource();

  static const String _root = 'assets/mini_programs/mp_profile_center';

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    if (miniProgramId != 'mp_profile_center') {
      throw StateError('Unknown bundled mini-program "$miniProgramId".');
    }
    return MiniProgramManifest.fromJson(
      await _loadJson('$_root/manifest.json'),
    );
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) {
    if (miniProgramId != 'mp_profile_center') {
      throw StateError('Unknown bundled mini-program "$miniProgramId".');
    }
    return _loadJson('$_root/screens/$screenId.json');
  }

  Future<Map<String, dynamic>> _loadJson(String assetPath) async {
    final decoded = jsonDecode(await rootBundle.loadString(assetPath));
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Asset "$assetPath" is not a JSON object.');
    }
    return decoded;
  }
}

class _MpOnlyHostBridge implements HostBridge {
  const _MpOnlyHostBridge();

  @override
  Future<HostActionResult> callSecureApi(CallSecureApiActionPayload payload) {
    return Future<HostActionResult>.value(
      HostActionResult.failed(
        actionName: ActionNames.callSecureApi,
        message: 'Secure API is not enabled in the Mp-only reference host.',
      ),
    );
  }

  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) {
    return Future<HostActionResult>.value(
      HostActionResult.failed(
        actionName: ActionNames.openNativeScreen,
        message: 'Native navigation is not enabled in the Mp-only host.',
      ),
    );
  }

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) {
    return Future<HostActionResult>.value(
      HostActionResult.success(
        actionName: ActionNames.trackEvent,
        message: 'Tracked Mp-only host event.',
        data: payload.properties,
      ),
    );
  }
}
