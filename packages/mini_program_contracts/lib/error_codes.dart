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
  static const String actionNotFound = 'action_not_found';
  static const String actionCallLimitExceeded = 'action_call_limit_exceeded';
  static const String invalidResultPayload = 'invalid_result_payload';
  static const String backendUnreachable = 'backend_unreachable';
  static const String backendTimeout = 'backend_timeout';
  static const String endpointNotConfigured = 'endpoint_not_configured';
  static const String publisherApiDisabled = 'publisher_api_disabled';
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
  static const String dataAssetUnavailable = 'data_asset_unavailable';
  static const String dataInvalidJson = 'data_invalid_json';
  static const String dataResourceTooLarge = 'data_resource_too_large';
  static const String dataResourceNotFound = 'data_resource_not_found';
  static const String dataInvalidQuery = 'data_invalid_query';
  static const String dataSearchFailed = 'data_search_failed';
  static const String locationNotAccepted = 'location_not_accepted';
  static const String locationUnavailable = 'location_unavailable';
  static const String locationPermissionDenied = 'location_permission_denied';
  static const String locationPermissionDeniedPermanently =
      'location_permission_denied_permanently';
  static const String locationServiceDisabled = 'location_service_disabled';
  static const String locationTimeout = 'location_timeout';
  static const String locationRequestInProgress =
      'location_request_in_progress';
  static const String locationInvalidResult = 'location_invalid_result';
  static const String fileNotAccepted = 'file_not_accepted';
  static const String fileTransferUnavailable = 'file_transfer_unavailable';
  static const String filePickerCancelled = 'file_picker_cancelled';
  static const String fileTypeNotAccepted = 'file_type_not_accepted';
  static const String fileTooLarge = 'file_too_large';
  static const String fileInsufficientStorage = 'file_insufficient_storage';
  static const String fileUploadFailed = 'file_upload_failed';
  static const String fileDownloadFailed = 'file_download_failed';
  static const String fileTransferCancelled = 'file_transfer_cancelled';
  static const String fileTransferNotFound = 'file_transfer_not_found';
  static const String fileTransferLimitExceeded =
      'file_transfer_limit_exceeded';
  static const String fileInvalidResult = 'file_invalid_result';
  static const String cameraNotAccepted = 'camera_not_accepted';
  static const String cameraUnavailable = 'camera_unavailable';
  static const String cameraPermissionDenied = 'camera_permission_denied';
  static const String cameraPermissionDeniedPermanently =
      'camera_permission_denied_permanently';
  static const String cameraCaptureCancelled = 'camera_capture_cancelled';
  static const String cameraRequestInProgress = 'camera_request_in_progress';
  static const String cameraInvalidResult = 'camera_invalid_result';
  static const String cameraStorageUnavailable = 'camera_storage_unavailable';
  static const String mediaUnavailable = 'media_unavailable';
  static const String mediaNotFound = 'media_not_found';
  static const String mediaNotOwned = 'media_not_owned';
  static const String mediaPreviewTooLarge = 'media_preview_too_large';
  static const String mediaInvalidResult = 'media_invalid_result';
  static const String flashlightNotAccepted = 'flashlight_not_accepted';
  static const String flashlightUnavailable = 'flashlight_unavailable';
  static const String flashlightPermissionDenied =
      'flashlight_permission_denied';
  static const String flashlightPermissionDeniedPermanently =
      'flashlight_permission_denied_permanently';
  static const String flashlightInUse = 'flashlight_in_use';
  static const String flashlightOperationFailed = 'flashlight_operation_failed';
}
