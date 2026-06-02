import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'local_cli_state.dart';

part 'publisher_backend/models.dart';
part 'publisher_backend/internal_models.dart';
part 'publisher_backend/generated_files.dart';
part 'publisher_backend/starter_helpers.dart';
part 'publisher_backend/firebase_starter_ui.dart';
part 'publisher_backend/firebase_helpers.dart';
part 'publisher_backend/aws_helpers.dart';
part 'publisher_backend/runtime_smoke_helpers.dart';
part 'publisher_backend/core_operations.dart';
part 'publisher_backend/firebase_operations.dart';
part 'publisher_backend/aws_operations.dart';

class PublisherBackendStarter {
  const PublisherBackendStarter({
    PublisherBackendShellRunner shellRunner = _defaultShellRunner,
    PublisherBackendProcessStarter processStarter = _defaultProcessStarter,
    PublisherBackendHealthGetter healthGetter = http.get,
    PublisherBackendPostRequester postRequester = _defaultPostRequester,
    PublisherBackendHttpRequester httpRequester = _defaultHttpRequester,
    PublisherBackendFirebaseAccessTokenProvider firebaseAccessTokenProvider =
        _defaultFirebaseAccessTokenProvider,
    PublisherBackendClock clock = _defaultClock,
    PublisherBackendDelay delay = _defaultDelay,
  }) : _shellRunner = shellRunner,
       _processStarter = processStarter,
       _healthGetter = healthGetter,
       _postRequester = postRequester,
       _httpRequester = httpRequester,
       _firebaseAccessTokenProvider = firebaseAccessTokenProvider,
       _clock = clock,
       _delay = delay;

  final PublisherBackendShellRunner _shellRunner;
  final PublisherBackendProcessStarter _processStarter;
  final PublisherBackendHealthGetter _healthGetter;
  final PublisherBackendPostRequester _postRequester;
  final PublisherBackendHttpRequester _httpRequester;
  final PublisherBackendFirebaseAccessTokenProvider
  _firebaseAccessTokenProvider;
  final PublisherBackendClock _clock;
  final PublisherBackendDelay _delay;

  Future<PublisherBackendScaffoldResult> scaffold(
    PublisherBackendScaffoldRequest request,
  ) => _scaffoldImpl(request);

  Future<PublisherBackendFirebaseStarterUiResult> firebaseStarterUi(
    PublisherBackendFirebaseStarterUiRequest request,
  ) => _firebaseStarterUiImpl(request);

  Future<PublisherBackendRunResult> run({
    required String miniProgramRootPath,
    int port = 9090,
  }) => _runImpl(miniProgramRootPath: miniProgramRootPath, port: port);

  Future<PublisherBackendStatusResult> status({
    required String miniProgramRootPath,
  }) => _statusImpl(miniProgramRootPath: miniProgramRootPath);

  Future<PublisherBackendStopResult> stop({
    required String miniProgramRootPath,
  }) => _stopImpl(miniProgramRootPath: miniProgramRootPath);

  PublisherBackendUrlsResult urls({int port = 9090}) => _urlsImpl(port: port);

  Future<PublisherBackendAwsDeployResult> awsDeploy(
    PublisherBackendAwsDeployRequest request,
  ) => _awsDeployImpl(request);

  Future<PublisherBackendAwsStatusResult> awsStatus(
    PublisherBackendAwsStatusRequest request,
  ) => _awsStatusImpl(request);

  Future<PublisherBackendAwsOutputsResult> awsOutputs(
    PublisherBackendAwsOutputsRequest request,
  ) => _awsOutputsImpl(request);

  Future<PublisherBackendAwsSmokeResult> awsSmoke(
    PublisherBackendAwsSmokeRequest request,
  ) => _awsSmokeImpl(request);

  Future<PublisherBackendFirebaseDeployResult> firebaseDeploy(
    PublisherBackendFirebaseDeployRequest request,
  ) => _firebaseDeployImpl(request);

  Future<PublisherBackendFirebaseStatusResult> firebaseStatus(
    PublisherBackendFirebaseStatusRequest request,
  ) => _firebaseStatusImpl(request);

  Future<PublisherBackendFirebaseOutputsResult> firebaseOutputs(
    PublisherBackendFirebaseOutputsRequest request,
  ) => _firebaseOutputsImpl(request);

  Future<PublisherBackendFirebaseAuthStatusResult> firebaseAuthStatus(
    PublisherBackendFirebaseAuthStatusRequest request,
  ) => _firebaseAuthStatusImpl(request);

  Future<PublisherBackendFirebaseAccessKeyCreateResult> firebaseAccessKeyCreate(
    PublisherBackendFirebaseAccessKeyCreateRequest request,
  ) => _firebaseAccessKeyCreateImpl(request);

  Future<PublisherBackendFirebaseAccessKeyListResult> firebaseAccessKeyList(
    PublisherBackendFirebaseAccessKeyListRequest request,
  ) => _firebaseAccessKeyListImpl(request);

  Future<PublisherBackendFirebaseAccessKeyRevokeResult> firebaseAccessKeyRevoke(
    PublisherBackendFirebaseAccessKeyRevokeRequest request,
  ) => _firebaseAccessKeyRevokeImpl(request);

  Future<PublisherBackendFirebaseAccessKeyRotateResult> firebaseAccessKeyRotate(
    PublisherBackendFirebaseAccessKeyRotateRequest request,
  ) => _firebaseAccessKeyRotateImpl(request);

  Future<PublisherBackendFirebaseSmokeResult> firebaseSmoke(
    PublisherBackendFirebaseSmokeRequest request,
  ) => _firebaseSmokeImpl(request);

  Future<PublisherBackendFirebaseSeedResult> firebaseSeed(
    PublisherBackendFirebaseSeedRequest request,
  ) => _firebaseSeedImpl(request);

  Future<PublisherBackendFirebaseDataStatusResult> firebaseDataStatus(
    PublisherBackendFirebaseDataStatusRequest request,
  ) => _firebaseDataStatusImpl(request);

  Future<PublisherBackendFirebaseDataExportResult> firebaseDataExport(
    PublisherBackendFirebaseDataExportRequest request,
  ) => _firebaseDataExportImpl(request);

  Future<PublisherBackendFirebaseDataImportResult> firebaseDataImport(
    PublisherBackendFirebaseDataImportRequest request,
  ) => _firebaseDataImportImpl(request);

  Future<PublisherBackendFirebaseDataRedemptionsResult> firebaseDataRedemptions(
    PublisherBackendFirebaseDataRedemptionsRequest request,
  ) => _firebaseDataRedemptionsImpl(request);

  Future<PublisherBackendFirebaseDestroyResult> firebaseDestroy(
    PublisherBackendFirebaseDestroyRequest request,
  ) => _firebaseDestroyImpl(request);

  Future<PublisherBackendAwsSeedResult> awsSeed(
    PublisherBackendAwsSeedRequest request,
  ) => _awsSeedImpl(request);

  Future<PublisherBackendAwsDataStatusResult> awsDataStatus(
    PublisherBackendAwsDataStatusRequest request,
  ) => _awsDataStatusImpl(request);

  Future<PublisherBackendAwsDataExportResult> awsDataExport(
    PublisherBackendAwsDataExportRequest request,
  ) => _awsDataExportImpl(request);

  Future<PublisherBackendAwsDataImportResult> awsDataImport(
    PublisherBackendAwsDataImportRequest request,
  ) => _awsDataImportImpl(request);

  Future<PublisherBackendAwsDataRedemptionsResult> awsDataRedemptions(
    PublisherBackendAwsDataRedemptionsRequest request,
  ) => _awsDataRedemptionsImpl(request);

  Future<PublisherBackendAwsLogsResult> awsLogs(
    PublisherBackendAwsLogsRequest request,
  ) => _awsLogsImpl(request);

  Future<PublisherBackendAwsDestroyResult> awsDestroy(
    PublisherBackendAwsDestroyRequest request,
  ) => _awsDestroyImpl(request);

  static Future<ProcessResult> _defaultShellRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: true,
    );
  }

  static Future<StartedPublisherBackendProcess> _defaultProcessStarter({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.detached,
    );
    return StartedPublisherBackendProcess(pid: process.pid);
  }

  static Future<http.Response> _defaultPostRequester(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http.post(uri, headers: headers, body: body);
  }

  static Future<http.Response> _defaultHttpRequester(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return switch (method.toUpperCase()) {
      'GET' => http.get(uri, headers: headers),
      'POST' => http.post(uri, headers: headers, body: body),
      'PATCH' => http.patch(uri, headers: headers, body: body),
      'PUT' => http.put(uri, headers: headers, body: body),
      'DELETE' => http.delete(uri, headers: headers, body: body),
      _ => throw PublisherBackendException(
        'Unsupported HTTP method for publisher backend request: $method',
      ),
    };
  }

  static Future<String?> _defaultFirebaseAccessTokenProvider() async {
    final environmentToken = Platform.environment['FIREBASE_TOKEN']?.trim();
    if (environmentToken != null && environmentToken.isNotEmpty) {
      return await _exchangeFirebaseRefreshToken(environmentToken) ??
          environmentToken;
    }
    for (final path in _firebaseCliConfigStoreCandidates()) {
      final file = File(path);
      if (!await file.exists()) {
        continue;
      }
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map) {
          continue;
        }
        final tokens = decoded['tokens'];
        if (tokens is! Map) {
          continue;
        }
        final refreshToken = tokens['refresh_token']?.toString().trim();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          final accessToken = await _exchangeFirebaseRefreshToken(refreshToken);
          if (accessToken != null && accessToken.isNotEmpty) {
            return accessToken;
          }
        }
        final accessToken = tokens['access_token']?.toString().trim();
        if (accessToken != null && accessToken.isNotEmpty) {
          return accessToken;
        }
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
    }
    return null;
  }

  static Future<String?> _exchangeFirebaseRefreshToken(
    String refreshToken,
  ) async {
    try {
      final response = await http.post(
        Uri.https('www.googleapis.com', '/oauth2/v3/token'),
        body: <String, String>{
          'refresh_token': refreshToken,
          'client_id': _firebaseCliClientId,
          'client_secret': _firebaseCliClientSecret,
          'grant_type': 'refresh_token',
          'scope': _firebaseCliTokenScopes.join(' '),
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return null;
      }
      final accessToken = decoded['access_token']?.toString().trim();
      return accessToken == null || accessToken.isEmpty ? null : accessToken;
    } on FormatException {
      return null;
    } on http.ClientException {
      return null;
    } on SocketException {
      return null;
    } on TlsException {
      return null;
    }
  }

  static List<String> _firebaseCliConfigStoreCandidates() {
    final candidates = <String>{};
    final env = Platform.environment;
    void addCandidate(String? root) {
      if (root == null || root.trim().isEmpty) {
        return;
      }
      candidates.add(p.join(root, 'configstore', 'firebase-tools.json'));
    }

    addCandidate(env['XDG_CONFIG_HOME']);
    addCandidate(env['APPDATA']);
    addCandidate(env['HOME'] == null ? null : p.join(env['HOME']!, '.config'));
    addCandidate(
      env['USERPROFILE'] == null
          ? null
          : p.join(env['USERPROFILE']!, '.config'),
    );
    addCandidate(
      env['USERPROFILE'] == null
          ? null
          : p.join(env['USERPROFILE']!, 'AppData', 'Roaming'),
    );
    return candidates.toList();
  }

  static DateTime _defaultClock() => DateTime.now();

  static Future<void> _defaultDelay(Duration duration) {
    return Future<void>.delayed(duration);
  }
}
