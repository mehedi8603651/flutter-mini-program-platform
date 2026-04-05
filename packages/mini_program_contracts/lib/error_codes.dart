/// Stable error code constants shared across contracts, SDK, and hosts.
abstract final class MiniProgramErrorCodes {
  static const String manifestParseFailure = 'manifest_parse_failure';
  static const String unsupportedContractVersion =
      'unsupported_contract_version';
  static const String unsupportedSdkVersion = 'unsupported_sdk_version';
  static const String unsupportedCapability = 'unsupported_capability';
  static const String unknownAction = 'unknown_action';
  static const String invalidResultPayload = 'invalid_result_payload';
  static const String backendUnreachable = 'backend_unreachable';
  static const String backendTimeout = 'backend_timeout';
  static const String secureApiNotAllowlisted = 'secure_api_not_allowlisted';
  static const String secureApiSessionMissing = 'secure_api_session_missing';
  static const String secureApiSessionExpired = 'secure_api_session_expired';
  static const String secureApiUnauthorized = 'secure_api_unauthorized';
  static const String secureApiForbidden = 'secure_api_forbidden';
  static const String secureApiInvalidPayload = 'secure_api_invalid_payload';
  static const String secureApiValidationFailed =
      'secure_api_validation_failed';
}
