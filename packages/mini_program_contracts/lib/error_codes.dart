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
  static const String galleryNotAccepted = 'gallery_not_accepted';
  static const String galleryUnavailable = 'gallery_unavailable';
  static const String galleryUserGestureRequired =
      'gallery_user_gesture_required';
  static const String gallerySelectionCancelled = 'gallery_selection_cancelled';
  static const String galleryRequestInProgress = 'gallery_request_in_progress';
  static const String galleryInvalidRequest = 'gallery_invalid_request';
  static const String galleryInvalidResult = 'gallery_invalid_result';
  static const String galleryLimitExceeded = 'gallery_limit_exceeded';
  static const String galleryUnsupportedImage = 'gallery_unsupported_image';
  static const String galleryStorageUnavailable = 'gallery_storage_unavailable';
  static const String galleryOperationFailed = 'gallery_operation_failed';
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
  static const String qrNotAccepted = 'qr_not_accepted';
  static const String qrUnavailable = 'qr_unavailable';
  static const String qrPermissionDenied = 'qr_permission_denied';
  static const String qrPermissionDeniedPermanently =
      'qr_permission_denied_permanently';
  static const String qrRequestInProgress = 'qr_request_in_progress';
  static const String qrCameraInUse = 'qr_camera_in_use';
  static const String qrScanCancelled = 'qr_scan_cancelled';
  static const String qrTimeout = 'qr_timeout';
  static const String qrInvalidResult = 'qr_invalid_result';
  static const String qrUserGestureRequired = 'qr_user_gesture_required';
  static const String qrOperationFailed = 'qr_operation_failed';

  static const String shareNotAccepted = 'share_not_accepted';
  static const String shareUnavailable = 'share_unavailable';
  static const String shareUserGestureRequired = 'share_user_gesture_required';
  static const String shareInvalidContent = 'share_invalid_content';
  static const String shareMediaNotOwned = 'share_media_not_owned';
  static const String shareTooManyItems = 'share_too_many_items';
  static const String shareRequestInProgress = 'share_request_in_progress';
  static const String shareOperationFailed = 'share_operation_failed';
  static const String displayBrightnessNotAccepted =
      'display_brightness_not_accepted';
  static const String displayBrightnessUnavailable =
      'display_brightness_unavailable';
  static const String displayBrightnessInvalidLevel =
      'display_brightness_invalid_level';
  static const String displayBrightnessOperationFailed =
      'display_brightness_operation_failed';
  static const String mediaNotAccepted = 'media_not_accepted';
  static const String microphoneNotAccepted = 'microphone_not_accepted';
  static const String microphoneUnavailable = 'microphone_unavailable';
  static const String microphonePermissionDenied =
      'microphone_permission_denied';
  static const String microphonePermissionDeniedPermanently =
      'microphone_permission_denied_permanently';
  static const String microphoneUserGestureRequired =
      'microphone_user_gesture_required';
  static const String microphoneRequestInProgress =
      'microphone_request_in_progress';
  static const String microphoneRecordingCancelled =
      'microphone_recording_cancelled';
  static const String microphoneInvalidRequest = 'microphone_invalid_request';
  static const String microphoneInvalidResult = 'microphone_invalid_result';
  static const String microphoneLimitExceeded = 'microphone_limit_exceeded';
  static const String microphoneStorageUnavailable =
      'microphone_storage_unavailable';
  static const String microphoneOperationFailed = 'microphone_operation_failed';
  static const String mediaProviderUnavailable = 'media_provider_unavailable';
  static const String mediaInvalidSource = 'media_invalid_source';
  static const String mediaSourceExpired = 'media_source_expired';
  static const String mediaUnsupportedFormat = 'media_unsupported_format';
  static const String mediaLoadFailed = 'media_load_failed';
  static const String mediaNetworkError = 'media_network_error';
  static const String mediaTimeout = 'media_timeout';
  static const String mediaPlayerNotFound = 'media_player_not_found';
  static const String mediaCacheUnavailable = 'media_cache_unavailable';
  static const String mediaCacheFailed = 'media_cache_failed';
  static const String mediaFullscreenUnavailable =
      'media_fullscreen_unavailable';
  static const String mediaInterrupted = 'media_interrupted';
  static const String mediaPlaybackFailed = 'media_playback_failed';
  static const String mediaRequestInProgress = 'media_request_in_progress';
}
