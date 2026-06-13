/// Provider-neutral Publisher API contract.
///
/// Mini-program screens use relative endpoints. Host endpoint configuration
/// supplies the Publisher API base URL and optional MiniProgram access key.
library;

/// Standard request header names used by Publisher APIs.
abstract final class MiniProgramPublisherBackendHeaders {
  /// Mini-program app id.
  static const String appId = 'x-mini-program-app-id';

  /// Host application identifier.
  static const String hostApp = 'x-mini-program-host-app';

  /// Host application version.
  static const String hostVersion = 'x-mini-program-host-version';

  /// MiniProgram SDK/runtime version.
  static const String sdkVersion = 'x-mini-program-sdk-version';

  /// Host platform identifier such as `cli`, `android`, `ios`, or `web`.
  static const String platform = 'x-mini-program-platform';

  /// Host locale, when available.
  static const String locale = 'x-mini-program-locale';

  /// Partner access key for protected Publisher APIs.
  static const String accessKey = 'x-mini-program-access-key';

  /// Publisher-owned signed-in user token.
  static const String authorization = 'authorization';

  /// Smoke-test or runtime request identifier.
  static const String requestId = 'x-mini-program-request-id';

  /// Provider-neutral Publisher API contract version.
  static const String contractVersion =
      'x-mini-program-backend-contract-version';
}

/// Stable provider-neutral Publisher API error codes.
abstract final class MiniProgramPublisherBackendErrorCodes {
  /// The Publisher API could not be reached.
  static const String unreachable = 'publisher_backend_unreachable';

  /// The Publisher API did not respond before the configured timeout.
  static const String timeout = 'publisher_backend_timeout';

  /// The Publisher API contract file is malformed.
  static const String invalidContract = 'publisher_backend_invalid_contract';

  /// A smoke route returned an unexpected status.
  static const String unexpectedStatus = 'publisher_backend_unexpected_status';

  /// A smoke route did not return the expected JSON object.
  static const String invalidJson = 'publisher_backend_invalid_json';

  /// Protected Publisher API access requires a MiniProgram access key.
  static const String accessKeyMissing = 'access_key_missing';

  /// Protected Publisher API access rejected the MiniProgram access key.
  static const String accessKeyInvalid = 'access_key_invalid';
}

/// Provider-neutral Publisher API contract document.
class MiniProgramPublisherBackendContract {
  /// Creates a provider-neutral Publisher API contract.
  MiniProgramPublisherBackendContract({
    this.schemaVersion = currentSchemaVersion,
    this.contractVersion = currentContractVersion,
    required String appId,
    required Uri backendBaseUri,
    String accessMode = accessModeProtected,
    String healthEndpoint = defaultHealthEndpoint,
    List<MiniProgramPublisherBackendSmokeCase>? smokeTests,
    bool allowLocalHttp = false,
  }) : appId = _normalizeAppId(appId),
       backendBaseUri = _normalizeBackendBaseUri(
         backendBaseUri,
         allowLocalHttp: allowLocalHttp,
       ),
       accessMode = _normalizeAccessMode(accessMode),
       healthEndpoint = _normalizeRelativeEndpoint(
         healthEndpoint,
         'healthEndpoint',
       ),
       smokeTests = List.unmodifiable(
         _normalizeSmokeTests(smokeTests, healthEndpoint: healthEndpoint),
       ) {
    if (schemaVersion != currentSchemaVersion) {
      throw FormatException(
        'Unsupported Publisher API contract schemaVersion: '
        '$schemaVersion.',
      );
    }
    if (contractVersion.trim() != currentContractVersion) {
      throw FormatException(
        'Unsupported Publisher API contractVersion: $contractVersion.',
      );
    }
  }

  /// Decodes a provider-neutral Publisher API contract.
  factory MiniProgramPublisherBackendContract.fromJson(
    Object? json, {
    bool allowLocalHttp = false,
  }) {
    if (json is! Map) {
      throw const FormatException(
        'Publisher API contract must be a JSON object.',
      );
    }
    final type = _readString(json, 'type');
    if (type != documentType) {
      throw FormatException(
        'Publisher API contract type must be "$documentType".',
      );
    }
    final backendBaseUri = Uri.tryParse(_readString(json, 'backendBaseUrl'));
    if (backendBaseUri == null) {
      throw const FormatException(
        'Publisher API contract backendBaseUrl is invalid.',
      );
    }
    final healthEndpoint =
        _readOptionalString(json, 'healthEndpoint') ?? defaultHealthEndpoint;
    return MiniProgramPublisherBackendContract(
      schemaVersion: _readInt(json, 'schemaVersion'),
      contractVersion: _readString(json, 'contractVersion'),
      appId: _readString(json, 'appId'),
      backendBaseUri: backendBaseUri,
      accessMode:
          _readOptionalString(json, 'accessMode') ?? accessModeProtected,
      healthEndpoint: healthEndpoint,
      smokeTests: _readSmokeTests(
        json['smokeTests'],
        healthEndpoint: healthEndpoint,
      ),
      allowLocalHttp: allowLocalHttp,
    );
  }

  /// Current contract document schema version.
  static const int currentSchemaVersion = 1;

  /// Current provider-neutral Publisher API contract version.
  static const String currentContractVersion = '1';

  /// Contract document type.
  static const String documentType = 'mini_program_publisher_backend_contract';

  /// Protected Publisher API mode.
  static const String accessModeProtected = 'protected';

  /// Public Publisher API mode.
  static const String accessModePublic = 'public';

  /// Default health route.
  static const String defaultHealthEndpoint = 'health';

  /// Contract schema version.
  final int schemaVersion;

  /// Contract version understood by SDK/tooling.
  final String contractVersion;

  /// Mini-program app id.
  final String appId;

  /// Publisher-owned Publisher API base URL.
  final Uri backendBaseUri;

  /// `protected` or `public`.
  final String accessMode;

  /// Relative health endpoint.
  final String healthEndpoint;

  /// Smoke cases used by provider-neutral tooling.
  final List<MiniProgramPublisherBackendSmokeCase> smokeTests;

  /// Whether the contract is protected.
  bool get isProtected => accessMode == accessModeProtected;

  /// Serializes the contract to stable JSON.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'type': documentType,
      'contractVersion': contractVersion,
      'appId': appId,
      'backendBaseUrl': backendBaseUri.toString(),
      'accessMode': accessMode,
      'healthEndpoint': healthEndpoint,
      'smokeTests': smokeTests.map((test) => test.toJson()).toList(),
    };
  }

  static List<MiniProgramPublisherBackendSmokeCase> _normalizeSmokeTests(
    List<MiniProgramPublisherBackendSmokeCase>? smokeTests, {
    required String healthEndpoint,
  }) {
    final tests =
        smokeTests ??
        <MiniProgramPublisherBackendSmokeCase>[
          MiniProgramPublisherBackendSmokeCase(
            id: 'health',
            endpoint: healthEndpoint,
          ),
        ];
    if (tests.isEmpty) {
      throw const FormatException(
        'Publisher API contract smokeTests must not be empty.',
      );
    }
    final ids = <String>{};
    for (final test in tests) {
      if (!ids.add(test.id)) {
        throw FormatException(
          'Publisher API contract has duplicate smoke test id: ${test.id}.',
        );
      }
    }
    return tests;
  }

  static List<MiniProgramPublisherBackendSmokeCase>? _readSmokeTests(
    Object? value, {
    required String healthEndpoint,
  }) {
    if (value == null) {
      return null;
    }
    if (value is! List) {
      throw const FormatException(
        'Publisher API contract smokeTests must be a list.',
      );
    }
    return value.map(MiniProgramPublisherBackendSmokeCase.fromJson).toList();
  }
}

/// Provider-neutral smoke-test route.
class MiniProgramPublisherBackendSmokeCase {
  /// Creates a provider-neutral smoke-test route.
  MiniProgramPublisherBackendSmokeCase({
    required String id,
    String method = 'GET',
    required String endpoint,
    Map<String, Object?> body = const <String, Object?>{},
    MiniProgramPublisherBackendSmokeExpectation? expectation,
  }) : id = _normalizeSafeId(id, 'id'),
       method = _normalizeMethod(method),
       endpoint = _normalizeRelativeEndpoint(endpoint, 'endpoint'),
       body = Map.unmodifiable(_normalizeBody(body)),
       expectation = _normalizeExpectation(
         expectation ?? const MiniProgramPublisherBackendSmokeExpectation(),
       );

  /// Decodes a smoke-test route from JSON.
  factory MiniProgramPublisherBackendSmokeCase.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException(
        'Publisher API smoke test must be a JSON object.',
      );
    }
    return MiniProgramPublisherBackendSmokeCase(
      id: _readString(json, 'id'),
      method: _readOptionalString(json, 'method') ?? 'GET',
      endpoint: _readString(json, 'endpoint'),
      body: _readOptionalMap(json, 'body') ?? const <String, Object?>{},
      expectation: MiniProgramPublisherBackendSmokeExpectation(
        expectedStatus:
            _readOptionalInt(json, 'expectedStatus') ??
            MiniProgramPublisherBackendSmokeExpectation.defaultExpectedStatus,
        expectJsonObject:
            _readOptionalBool(json, 'expectJsonObject') ??
            MiniProgramPublisherBackendSmokeExpectation.defaultExpectJsonObject,
      ),
    );
  }

  /// Stable smoke case id.
  final String id;

  /// HTTP method.
  final String method;

  /// Relative Publisher API endpoint.
  final String endpoint;

  /// JSON body for non-GET methods.
  final Map<String, Object?> body;

  /// Expected route behavior.
  final MiniProgramPublisherBackendSmokeExpectation expectation;

  /// Serializes the smoke case to stable JSON.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'method': method,
      'endpoint': endpoint,
      if (body.isNotEmpty) 'body': body,
      'expectedStatus': expectation.expectedStatus,
      'expectJsonObject': expectation.expectJsonObject,
    };
  }
}

/// Expected provider-neutral smoke-test route behavior.
class MiniProgramPublisherBackendSmokeExpectation {
  /// Creates a smoke-test expectation.
  const MiniProgramPublisherBackendSmokeExpectation({
    this.expectedStatus = defaultExpectedStatus,
    this.expectJsonObject = defaultExpectJsonObject,
  });

  /// Default HTTP status expected by smoke tests.
  static const int defaultExpectedStatus = 200;

  /// Default response-shape expectation.
  static const bool defaultExpectJsonObject = true;

  /// Expected HTTP status.
  final int expectedStatus;

  /// Whether response body must decode to a JSON object.
  final bool expectJsonObject;
}

String _normalizeAppId(String value) => _normalizeSafeId(value, 'appId');

String _normalizeSafeId(String value, String label) {
  final trimmed = value.trim();
  if (trimmed.isEmpty ||
      trimmed == '.' ||
      trimmed == '..' ||
      !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(trimmed)) {
    throw FormatException('Publisher API contract $label is invalid.');
  }
  return trimmed;
}

Uri _normalizeBackendBaseUri(Uri uri, {required bool allowLocalHttp}) {
  if (!uri.hasScheme || uri.host.isEmpty) {
    throw const FormatException(
      'Publisher API contract backendBaseUrl must be absolute.',
    );
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https') {
    if (scheme != 'http' ||
        !_isAllowedHttpHost(uri.host, allowLocalHttp: allowLocalHttp)) {
      throw const FormatException(
        'Publisher API contract backendBaseUrl must use HTTPS in '
        'production. HTTP is allowed only for loopback, or local LAN when '
        'explicitly enabled.',
      );
    }
  }
  return Uri.parse(uri.toString().replaceFirst(RegExp(r'/+$'), ''));
}

bool _isAllowedHttpHost(String host, {required bool allowLocalHttp}) {
  final lower = host.toLowerCase();
  if (lower == 'localhost' || lower == '127.0.0.1' || lower == '::1') {
    return true;
  }
  // Android emulator loopback.
  if (lower == '10.0.2.2') {
    return true;
  }
  if (!allowLocalHttp) {
    return false;
  }
  final parts = lower.split('.');
  if (parts.length != 4) {
    return lower.endsWith('.local');
  }
  final octets = parts.map(int.tryParse).toList();
  if (octets.any((value) => value == null || value < 0 || value > 255)) {
    return false;
  }
  final first = octets[0]!;
  final second = octets[1]!;
  return first == 10 ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168);
}

String _normalizeAccessMode(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == MiniProgramPublisherBackendContract.accessModeProtected ||
      normalized == MiniProgramPublisherBackendContract.accessModePublic) {
    return normalized;
  }
  throw const FormatException(
    'Publisher API contract accessMode must be "protected" or "public".',
  );
}

String _normalizeRelativeEndpoint(String value, String label) {
  final endpoint = value.trim();
  if (endpoint.isEmpty) {
    throw FormatException('Publisher API contract $label must not be empty.');
  }
  final parsed = Uri.tryParse(endpoint);
  if (parsed == null || parsed.hasScheme || parsed.hasAuthority) {
    throw FormatException(
      'Publisher API contract $label must be a relative endpoint.',
    );
  }
  final normalized = endpoint.replaceFirst(RegExp(r'^/+'), '');
  if (normalized.isEmpty) {
    throw FormatException('Publisher API contract $label must not be empty.');
  }
  final segments = Uri.parse(normalized).pathSegments;
  if (segments.any((segment) => segment == '..')) {
    throw FormatException(
      'Publisher API contract $label must not contain ".." segments.',
    );
  }
  return normalized;
}

String _normalizeMethod(String value) {
  final method = value.trim().toUpperCase();
  const allowed = <String>{'GET', 'POST', 'PUT', 'PATCH', 'DELETE'};
  if (!allowed.contains(method)) {
    throw FormatException('Publisher API smoke method is unsupported: $value.');
  }
  return method;
}

Map<String, Object?> _normalizeBody(Map<String, Object?> value) {
  for (final entry in value.entries) {
    if (entry.key.trim().isEmpty) {
      throw const FormatException(
        'Publisher API smoke body contains a blank key.',
      );
    }
  }
  return value;
}

MiniProgramPublisherBackendSmokeExpectation _normalizeExpectation(
  MiniProgramPublisherBackendSmokeExpectation expectation,
) {
  if (expectation.expectedStatus < 100 || expectation.expectedStatus > 599) {
    throw const FormatException(
      'Publisher API smoke expectedStatus must be between 100 and 599.',
    );
  }
  return expectation;
}

String _readString(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Publisher API contract is missing "$key".');
  }
  return value.trim();
}

String? _readOptionalString(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Publisher API contract "$key" must be a string.');
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _readInt(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Publisher API contract "$key" must be an integer.');
  }
  return value;
}

int? _readOptionalInt(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! int) {
    throw FormatException('Publisher API contract "$key" must be an integer.');
  }
  return value;
}

bool? _readOptionalBool(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! bool) {
    throw FormatException('Publisher API contract "$key" must be a boolean.');
  }
  return value;
}

Map<String, Object?>? _readOptionalMap(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! Map) {
    throw FormatException(
      'Publisher API contract "$key" must be a JSON object.',
    );
  }
  return Map<String, Object?>.from(value);
}
