String buildPreviewHostMainDart() {
  return r'''
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

const String _configuredPreviewBaseUrl = String.fromEnvironment(
  'MINI_PROGRAM_PREVIEW_BASE_URL',
);
const String _configuredMiniProgramId = String.fromEnvironment(
  'MINI_PROGRAM_PREVIEW_MINI_PROGRAM_ID',
);
const String _configuredTitle = String.fromEnvironment(
  'MINI_PROGRAM_PREVIEW_TITLE',
  defaultValue: 'Mini Program Preview',
);
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PreviewHostApp());
}

class PreviewHostApp extends StatefulWidget {
  const PreviewHostApp({super.key});

  @override
  State<PreviewHostApp> createState() => _PreviewHostAppState();
}

class _PreviewHostAppState extends State<PreviewHostApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final http.Client _statusClient = http.Client();
  late final Uri _previewBaseUri;
  late final PreviewMiniProgramSource _source;
  late final PreviewHostBridge _hostBridge;
  late final CapabilityRegistry _capabilityRegistry;
  late final MiniProgramDeliveryContext _deliveryContext;
  late MiniProgramCacheBundle _cacheBundle;

  Timer? _pollTimer;
  PreviewStatus _status = PreviewStatus.initial();

  @override
  void initState() {
    super.initState();
    _previewBaseUri = Uri.parse(_configuredPreviewBaseUrl);
    _hostBridge = PreviewHostBridge(navigatorKey: _navigatorKey);
    _capabilityRegistry = CapabilityRegistry(
      const <CapabilityId>[
        CapabilityIds.analytics,
        CapabilityIds.nativeNavigation,
        CapabilityIds.secureApi,
      ],
    );
    _deliveryContext = MiniProgramDeliveryContext(
      hostApp: 'mini-program-preview',
      hostVersion: 'local',
      sdkVersion: 'local',
      capabilities: _capabilityRegistry.supportedCapabilities,
      platform: defaultTargetPlatform.name,
    );
    _source = PreviewMiniProgramSource(
      previewBaseUri: _previewBaseUri,
      expectedMiniProgramId: _configuredMiniProgramId,
      deliveryContext: _deliveryContext,
    );
    _cacheBundle = _buildPreviewCacheBundle();
    _refreshStatus();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshStatus(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _statusClient.close();
    _source.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = (_status.title?.trim().isNotEmpty ?? false)
        ? _status.title!
        : _configuredTitle;
    final runtime = MiniProgramRuntime(
      sdkVersion: '1.0.0',
      source: _source,
      hostBridge: _hostBridge,
      capabilityRegistry: _capabilityRegistry,
      cacheBundle: _cacheBundle,
    );

    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF005B4F),
        ),
      ),
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: MiniProgramRuntimeScope(
                runtime: runtime,
                child: MiniProgramPage(
                  key: ValueKey<int>(_status.buildVersion),
                  miniProgramId: _configuredMiniProgramId,
                  title: title,
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: _PreviewStatusBanner(status: _status),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyStatus(PreviewStatus nextStatus) {
    if (!mounted || nextStatus == _status) {
      return;
    }

    setState(() {
      if (nextStatus.buildVersion != _status.buildVersion) {
        _cacheBundle = _buildPreviewCacheBundle();
      }
      _status = nextStatus;
    });
  }

  Future<void> _refreshStatus() async {
    try {
      final response = await _statusClient
          .get(_previewBaseUri.resolve('status.json'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) {
        _applyStatus(
          _status.copyWith(
            state: MiniProgramPreviewStates.buildFailed,
            lastBuildError:
                'Preview status returned HTTP ${response.statusCode}.',
          ),
        );
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Preview status is not a JSON object.');
      }

      final nextStatus = PreviewStatus.fromJson(decoded);
      _applyStatus(nextStatus);
    } catch (error) {
      _applyStatus(
        _status.copyWith(
          state: MiniProgramPreviewStates.buildFailed,
          lastBuildError: 'Preview polling failed: $error',
        ),
      );
    }
  }

}

class PreviewStatus {
  const PreviewStatus({
    required this.buildVersion,
    required this.state,
    this.title,
    this.lastBuildError,
  });

  factory PreviewStatus.initial() {
    return const PreviewStatus(
      buildVersion: 0,
      state: MiniProgramPreviewStates.ready,
    );
  }

  factory PreviewStatus.fromJson(Map<String, dynamic> json) {
    final rawBuildVersion = json['buildVersion'];
    final rawState = json['state'];

    return PreviewStatus(
      buildVersion: rawBuildVersion is int ? rawBuildVersion : 0,
      state: rawState is String && rawState.trim().isNotEmpty
          ? rawState
          : MiniProgramPreviewStates.ready,
      title: json['title']?.toString(),
      lastBuildError: json['lastBuildError']?.toString(),
    );
  }

  final int buildVersion;
  final String state;
  final String? title;
  final String? lastBuildError;

  PreviewStatus copyWith({
    int? buildVersion,
    String? state,
    String? title,
    String? lastBuildError,
  }) {
    return PreviewStatus(
      buildVersion: buildVersion ?? this.buildVersion,
      state: state ?? this.state,
      title: title ?? this.title,
      lastBuildError: lastBuildError ?? this.lastBuildError,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PreviewStatus &&
        other.buildVersion == buildVersion &&
        other.state == state &&
        other.title == title &&
        other.lastBuildError == lastBuildError;
  }

  @override
  int get hashCode => Object.hash(
    buildVersion,
    state,
    title,
    lastBuildError,
  );
}

abstract final class MiniProgramPreviewStates {
  static const String ready = 'ready';
  static const String building = 'building';
  static const String buildFailed = 'build_failed';
}

MiniProgramCacheBundle _buildPreviewCacheBundle() {
  if (kIsWeb) {
    return MiniProgramCacheBundle.webPersistent(
      runtimeCacheKeyPrefix: 'mini_program_preview_runtime_cache',
    );
  }
  return MiniProgramCacheBundle.inMemory();
}

class PreviewMiniProgramSource
    implements
        MiniProgramSource,
        MiniProgramJsonAssetSource,
        MiniProgramPublisherBackendContractSource,
        MiniProgramPublisherApiPolicyProvider,
        MiniProgramDeliveryContextProvider {
  PreviewMiniProgramSource({
    required this.previewBaseUri,
    required this.expectedMiniProgramId,
    required this.deliveryContext,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri previewBaseUri;
  final String expectedMiniProgramId;
  @override
  final MiniProgramDeliveryContext deliveryContext;
  final http.Client _client;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    if (miniProgramId != expectedMiniProgramId) {
      throw MiniProgramSourceException(
        message:
            'Preview host only exposes "$expectedMiniProgramId", but the SDK requested "$miniProgramId".',
        errorCode: MiniProgramErrorCodes.manifestParseFailure,
      );
    }

    final json = await _loadJson('manifest.json', resourceLabel: 'manifest');
    return MiniProgramManifest.fromJson(json);
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) {
    return _loadJson(
      'screens/$screenId.json',
      resourceLabel: 'screen',
    );
  }

  @override
  Future<List<int>> loadJsonAsset({
    required String miniProgramId,
    required String version,
    required String assetPath,
  }) async {
    if (miniProgramId != expectedMiniProgramId) {
      throw MiniProgramSourceException(
        message:
            'Preview host only exposes "$expectedMiniProgramId", but the SDK requested "$miniProgramId".',
        errorCode: MiniProgramErrorCodes.dataAssetUnavailable,
      );
    }
    final uri = previewBaseUri.resolve('assets/$assetPath');
    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw MiniProgramSourceException(
        message: 'Preview host timed out while loading JSON data from $uri.',
        errorCode: MiniProgramErrorCodes.backendTimeout,
        details: <String, dynamic>{'uri': uri.toString()},
      );
    } catch (error) {
      throw MiniProgramSourceException(
        message: 'Preview host could not load JSON data from $uri.',
        errorCode: MiniProgramErrorCodes.backendUnreachable,
        details: <String, dynamic>{
          'uri': uri.toString(),
          'transportError': '$error',
        },
      );
    }
    if (response.statusCode != 200) {
      throw MiniProgramSourceException(
        message:
            'Preview host returned HTTP ${response.statusCode} while loading JSON data.',
        errorCode: MiniProgramErrorCodes.dataResourceNotFound,
        statusCode: response.statusCode,
        details: <String, dynamic>{'uri': uri.toString()},
      );
    }
    return response.bodyBytes;
  }

  @override
  Future<MiniProgramPublisherBackendContract?> loadPublisherBackendContract({
    required String miniProgramId,
    required String version,
  }) async {
    if (miniProgramId != expectedMiniProgramId) {
      throw MiniProgramSourceException(
        message:
            'Preview host only exposes "$expectedMiniProgramId", but the SDK requested "$miniProgramId".',
        errorCode: MiniProgramPublisherBackendErrorCodes.invalidContract,
      );
    }
    try {
      final json = await _loadJson(
        'publisher_backend.json',
        resourceLabel: 'Publisher API contract',
      );
      return MiniProgramPublisherBackendContract.fromJson(
        json,
        allowLocalHttp: true,
      );
    } on MiniProgramSourceException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  MiniProgramPublisherApiPolicy publisherApiPolicyFor(String miniProgramId) {
    return const MiniProgramPublisherApiPolicy(enabled: true);
  }

  void close() {
    _client.close();
  }

  Future<Map<String, dynamic>> _loadJson(
    String relativePath, {
    required String resourceLabel,
  }) async {
    final uri = previewBaseUri.resolve(relativePath);
    late final http.Response response;

    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw MiniProgramSourceException(
        message:
            'Preview host timed out while loading $resourceLabel from $uri.',
        errorCode: MiniProgramErrorCodes.backendTimeout,
        details: <String, dynamic>{
          'uri': uri.toString(),
          'resourceLabel': resourceLabel,
        },
      );
    } catch (error) {
      throw MiniProgramSourceException(
        message:
            'Preview host could not load $resourceLabel from $uri.',
        errorCode: MiniProgramErrorCodes.backendUnreachable,
        details: <String, dynamic>{
          'uri': uri.toString(),
          'resourceLabel': resourceLabel,
          'transportError': '$error',
        },
      );
    }

    if (response.statusCode != 200) {
      throw MiniProgramSourceException(
        message:
            'Preview host returned HTTP ${response.statusCode} while loading $resourceLabel.',
        errorCode: MiniProgramErrorCodes.backendUnreachable,
        statusCode: response.statusCode,
        details: <String, dynamic>{
          'uri': uri.toString(),
          'resourceLabel': resourceLabel,
          'responseBody': response.body,
        },
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw MiniProgramSourceException(
        message: 'Preview host returned non-object JSON for $resourceLabel.',
        errorCode: MiniProgramErrorCodes.manifestParseFailure,
        details: <String, dynamic>{
          'uri': uri.toString(),
          'resourceLabel': resourceLabel,
        },
      );
    }
    return decoded;
  }
}

class PreviewHostBridge implements HostBridge {
  PreviewHostBridge({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return HostActionResult.failed(
        actionName: ActionNames.openNativeScreen,
        message: 'Preview navigator is not available.',
      );
    }

    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PreviewNativePlaceholderPage(payload: payload),
      ),
    );
    return HostActionResult.success(
      actionName: ActionNames.openNativeScreen,
      message: 'Opened a preview-native placeholder screen.',
      data: <String, dynamic>{
        'route': payload.route,
        'args': payload.args,
      },
    );
  }

  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async {
    return HostActionResult.failed(
      actionName: ActionNames.callSecureApi,
      errorCode: MiniProgramErrorCodes.secureApiNotAllowlisted,
      message:
          'Preview mode does not execute secure_api actions. Use a real host/backend flow for secure integrations.',
      data: <String, dynamic>{
        'endpoint': payload.endpoint,
        'method': payload.method,
      },
    );
  }

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async {
    debugPrint('[preview][analytics] ${payload.name} ${payload.properties}');
    return HostActionResult.success(
      actionName: ActionNames.trackEvent,
      message: 'Tracked preview analytics event.',
      data: payload.properties,
    );
  }
}

class PreviewNativePlaceholderPage extends StatelessWidget {
  const PreviewNativePlaceholderPage({
    super.key,
    required this.payload,
  });

  final OpenNativeScreenActionPayload payload;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Preview Native: ${payload.route}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview-only native placeholder',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Preview mode cannot execute your real host-native screen. This page shows the action details the host would receive.',
            ),
            const SizedBox(height: 24),
            _PreviewDetailCard(
              title: 'Route',
              child: Text(
                payload.route,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            _PreviewDetailCard(
              title: 'Expect Result',
              child: Text(payload.expectResult ? 'Yes' : 'No'),
            ),
            const SizedBox(height: 16),
            _PreviewDetailCard(
              title: 'Arguments',
              child: payload.args.isEmpty
                  ? const Text('No arguments were provided.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: payload.args.entries
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PreviewArgumentRow(
                                label: entry.key,
                                value: entry.value,
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatPreviewValue(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is String || value is num || value is bool) {
      return '$value';
    }
    return const JsonEncoder.withIndent('  ').convert(value);
  }
}

class _PreviewDetailCard extends StatelessWidget {
  const _PreviewDetailCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7E3DD)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF4B5563),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _PreviewArgumentRow extends StatelessWidget {
  const _PreviewArgumentRow({
    required this.label,
    required this.value,
  });

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final formattedValue = PreviewNativePlaceholderPage._formatPreviewValue(
      value,
    );
    final isStructuredValue = value is Map || value is List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF4B5563),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isStructuredValue
              ? SelectableText(
                  formattedValue,
                  style: const TextStyle(fontFamily: 'Courier'),
                )
              : Text(formattedValue),
        ),
      ],
    );
  }
}

class _PreviewStatusBanner extends StatelessWidget {
  const _PreviewStatusBanner({required this.status});

  final PreviewStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status.state) {
      case MiniProgramPreviewStates.building:
        return const LinearProgressIndicator(minHeight: 3);
      case MiniProgramPreviewStates.buildFailed:
        return Material(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status.lastBuildError ??
                        'Preview rebuild failed. Keeping the last successful UI visible.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      case MiniProgramPreviewStates.ready:
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }
}
''';
}
