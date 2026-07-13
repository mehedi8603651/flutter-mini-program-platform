/// Stable error code constants shared across contracts, SDK, and hosts.
abstract final class MiniProgramErrorCodes {
  static const String manifestParseFailure = 'manifest_parse_failure';
  static const String unsupportedContractVersion =
      'unsupported_contract_version';
  static const String unsupportedSdkVersion = 'unsupported_sdk_version';
  static const String unsupportedCapability = 'unsupported_capability';
  static const String screenNotFound = 'screen_not_found';
  static const String screenNotInStack = 'screen_not_in_stack';
  static const String unknownAction = 'unknown_action';
  static const String invalidResultPayload = 'invalid_result_payload';
  static const String backendUnreachable = 'backend_unreachable';
  static const String backendTimeout = 'backend_timeout';
  static const String endpointNotConfigured = 'endpoint_not_configured';
  static const String secureApiNotAllowlisted = 'secure_api_not_allowlisted';
  static const String secureApiSessionMissing = 'secure_api_session_missing';
  static const String secureApiSessionExpired = 'secure_api_session_expired';
  static const String secureApiUnauthorized = 'secure_api_unauthorized';
  static const String secureApiForbidden = 'secure_api_forbidden';
  static const String secureApiInvalidPayload = 'secure_api_invalid_payload';
  static const String secureApiValidationFailed =
      'secure_api_validation_failed';
  static const String stateInvalidValue = 'state_invalid_value';
  static const String stateLimitExceeded = 'state_limit_exceeded';
  static const String stateIndexOutOfRange = 'state_index_out_of_range';
  static const String initializeFailed = 'initialize_failed';
  static const String conditionInvalidValue = 'condition_invalid_value';
  static const String mathInvalidExpression = 'math_invalid_expression';
  static const String mathDivisionByZero = 'math_division_by_zero';
  static const String mathDomainError = 'math_domain_error';
  static const String mathResultNotFinite = 'math_result_not_finite';
  static const String mathComplexityExceeded = 'math_complexity_exceeded';
  static const String mathInvalidOperand = 'math_invalid_operand';
  static const String mathInvalidRange = 'math_invalid_range';
  static const String mathEmptyValues = 'math_empty_values';
}
