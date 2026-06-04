import 'package:mini_program_sdk/mini_program_sdk.dart';

/// SDK-local Stac action model for appending the next publisher backend page.
class SdkMiniProgramLoadMoreAction {
  const SdkMiniProgramLoadMoreAction({
    required this.requestId,
    this.endpoint,
    this.limit = 20,
    this.initialCursor,
    this.cursorParam = 'cursor',
    this.limitParam = 'limit',
    this.itemsPath = 'items',
    this.nextCursorPath = 'nextCursor',
    this.hasMorePath = 'hasMore',
    this.cacheTtlSeconds,
  });

  static const String stacActionType = 'miniProgramLoadMore';

  final String requestId;
  final String? endpoint;
  final int limit;
  final String? initialCursor;
  final String cursorParam;
  final String limitParam;
  final String itemsPath;
  final String nextCursorPath;
  final String hasMorePath;
  final int? cacheTtlSeconds;

  factory SdkMiniProgramLoadMoreAction.fromJson(Map<String, dynamic> json) {
    final actionType = json['actionType'];
    if (actionType != stacActionType) {
      throw FormatException(
        'Expected actionType "$stacActionType", got "$actionType".',
      );
    }

    return SdkMiniProgramLoadMoreAction(
      requestId: _requiredString(json, 'requestId'),
      endpoint: _optionalString(json, 'endpoint'),
      limit: _optionalPositiveInt(json, 'limit') ?? 20,
      initialCursor: _optionalString(json, 'initialCursor'),
      cursorParam: _optionalString(json, 'cursorParam') ?? 'cursor',
      limitParam: _optionalString(json, 'limitParam') ?? 'limit',
      itemsPath: _optionalString(json, 'itemsPath') ?? 'items',
      nextCursorPath: _optionalString(json, 'nextCursorPath') ?? 'nextCursor',
      hasMorePath: _optionalString(json, 'hasMorePath') ?? 'hasMore',
      cacheTtlSeconds: _optionalPositiveInt(json, 'cacheTtlSeconds'),
    );
  }

  MiniProgramPagedBackendQuery? toQuery() {
    final resolvedEndpoint = endpoint;
    if (resolvedEndpoint == null || resolvedEndpoint.trim().isEmpty) {
      return null;
    }
    final ttl = cacheTtlSeconds;
    return MiniProgramPagedBackendQuery(
      requestId: requestId,
      endpoint: resolvedEndpoint,
      limit: limit,
      initialCursor: initialCursor,
      cursorParam: cursorParam,
      limitParam: limitParam,
      itemsPath: itemsPath,
      nextCursorPath: nextCursorPath,
      hasMorePath: hasMorePath,
      cacheTtl: ttl == null ? null : Duration(seconds: ttl),
    );
  }

  static String _requiredString(Map<String, dynamic> json, String fieldName) {
    final value = json[fieldName];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'miniProgramLoadMore requires a non-empty "$fieldName" string.',
      );
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> json, String fieldName) {
    final value = json[fieldName];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw FormatException('"$fieldName" must be a string when provided.');
    }
    return value;
  }

  static int? _optionalPositiveInt(
    Map<String, dynamic> json,
    String fieldName,
  ) {
    final value = json[fieldName];
    if (value == null) {
      return null;
    }
    if (value is! int || value <= 0) {
      throw FormatException('"$fieldName" must be a positive integer.');
    }
    return value;
  }
}
