part of '../publisher_backend_starter.dart';

typedef PublisherBackendShellRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });
typedef PublisherBackendProcessStarter =
    Future<StartedPublisherBackendProcess> Function({
      required String executable,
      required List<String> arguments,
      required String workingDirectory,
    });
typedef PublisherBackendHealthGetter = Future<http.Response> Function(Uri uri);
typedef PublisherBackendPostRequester =
    Future<http.Response> Function(
      Uri uri, {
      Map<String, String>? headers,
      Object? body,
    });
typedef PublisherBackendHttpRequester =
    Future<http.Response> Function(
      String method,
      Uri uri, {
      Map<String, String>? headers,
      Object? body,
    });
typedef PublisherBackendFirebaseAccessTokenProvider =
    Future<String?> Function();
typedef PublisherBackendClock = DateTime Function();
typedef PublisherBackendDelay = Future<void> Function(Duration duration);

const List<String> _publisherBackendAwsSmokeRoutePaths = <String>[
  '/health',
  '/home/bootstrap',
  '/coupons/list',
  '/auth/session',
];
const List<String> _publisherBackendFirebaseSmokeRoutePaths = <String>[
  '/health',
  '/home/bootstrap',
  '/coupons/list',
];

const Duration _awsDeployHealthWaitTimeout = Duration(seconds: 45);
const Duration _awsDeployHealthAttemptTimeout = Duration(seconds: 5);
const Duration _awsDeployHealthRetryDelay = Duration(seconds: 1);
const Duration _firebaseDeployHealthWaitTimeout = Duration(seconds: 45);
const Duration _firebaseDeployHealthAttemptTimeout = Duration(seconds: 5);
const Duration _firebaseDeployHealthRetryDelay = Duration(seconds: 1);
const int _dynamoDbBatchWriteMaxAttempts = 5;

const String _publisherBackendStorageBundled = 'bundled';
const String _publisherBackendStorageDynamoDb = 'dynamodb';
const String _publisherBackendStorageFirestore = 'firestore';
const Set<String> _firebaseDataCollections = <String>{
  'home',
  'sessions',
  'coupons',
  'redemptions',
};
const String _firebaseCliClientId =
    '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const String _firebaseCliClientSecret = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const List<String> _firebaseCliTokenScopes = <String>[
  'https://www.googleapis.com/auth/cloud-platform',
  'https://www.googleapis.com/auth/firebase',
];
const String _awsSdkJavaScriptV3Version = '^3.1052.0';
const String _firebaseFunctionsVersion = '^7.2.5';
const String _firebaseAdminVersion = '^13.10.0';

class PublisherBackendException implements Exception {
  const PublisherBackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PublisherBackendScaffoldRequest {
  const PublisherBackendScaffoldRequest({
    required this.miniProgramRootPath,
    this.template = 'mock',
    this.storageMode = 'bundled',
    this.force = false,
    this.withStarterUi = false,
  });

  final String miniProgramRootPath;
  final String template;
  final String storageMode;
  final bool force;
  final bool withStarterUi;
}

class PublisherBackendScaffoldResult {
  const PublisherBackendScaffoldResult({
    required this.miniProgramRootPath,
    required this.backendRootPath,
    required this.template,
    required this.createdPaths,
    this.storageMode,
    this.starterUi,
  });

  final String miniProgramRootPath;
  final String backendRootPath;
  final String template;
  final List<String> createdPaths;
  final String? storageMode;
  final PublisherBackendFirebaseStarterUiResult? starterUi;
}
