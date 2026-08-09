import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

const int miniProgramShareMaxMediaItems = 10;
const int miniProgramShareMaxTitleLength = 200;
const int miniProgramShareMaxTextLength = 32768;
const int miniProgramShareMaxUrlLength = 2048;

/// Host authority for opening the platform share chooser.
@immutable
class MiniProgramSharePolicy {
  const MiniProgramSharePolicy({
    this.enabled = false,
    this.allowText = true,
    this.allowUrls = true,
    this.allowMedia = true,
    this.maxMediaItems = miniProgramShareMaxMediaItems,
  }) : assert(maxMediaItems > 0),
       assert(maxMediaItems <= miniProgramShareMaxMediaItems);

  final bool enabled;
  final bool allowText;
  final bool allowUrls;
  final bool allowMedia;
  final int maxMediaItems;

  @override
  bool operator ==(Object other) =>
      other is MiniProgramSharePolicy &&
      enabled == other.enabled &&
      allowText == other.allowText &&
      allowUrls == other.allowUrls &&
      allowMedia == other.allowMedia &&
      maxMediaItems == other.maxMediaItems;

  @override
  int get hashCode =>
      Object.hash(enabled, allowText, allowUrls, allowMedia, maxMediaItems);
}

/// Resolves accepted sharing policy for one mini-program endpoint.
abstract interface class MiniProgramSharePolicyProvider {
  MiniProgramSharePolicy sharePolicyFor(String miniProgramId);
}

/// Trusted, validated request passed to the host share implementation.
@immutable
class MiniProgramShareRequest {
  const MiniProgramShareRequest({
    required this.miniProgramId,
    this.title,
    this.text,
    this.url,
    this.mediaRefs = const <String>[],
  });

  final String miniProgramId;
  final String? title;
  final String? text;
  final Uri? url;
  final List<String> mediaRefs;
}

/// Opens trusted platform sharing UI.
abstract interface class MiniProgramShareProvider {
  Future<MiniProgramShareResult> open(MiniProgramShareRequest request);
}

/// Structured share-provider failure mapped to a stable contract error.
class MiniProgramShareException implements Exception {
  const MiniProgramShareException({
    required this.errorCode,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final String errorCode;
  final String message;
  final Map<String, Object?> details;

  @override
  String toString() => message;
}

/// Validates share content and prevents concurrent chooser requests.
class MiniProgramShareManager {
  MiniProgramShareManager(this.provider);

  final MiniProgramShareProvider provider;
  bool _requestInProgress = false;
  bool _disposed = false;

  Future<MiniProgramShareResult> open({
    required String miniProgramId,
    String? title,
    String? text,
    Uri? url,
    List<String> mediaRefs = const <String>[],
  }) async {
    _ensureActive();
    if (_requestInProgress) {
      throw const MiniProgramShareException(
        errorCode: MiniProgramErrorCodes.shareRequestInProgress,
        message: 'A system share request is already in progress.',
      );
    }
    final request = _validatedRequest(
      miniProgramId: miniProgramId,
      title: title,
      text: text,
      url: url,
      mediaRefs: mediaRefs,
    );
    _requestInProgress = true;
    try {
      final result = await provider.open(request);
      result.validate();
      return result;
    } on FormatException catch (error) {
      throw MiniProgramShareException(
        errorCode: MiniProgramErrorCodes.shareOperationFailed,
        message: error.message.toString(),
      );
    } finally {
      _requestInProgress = false;
    }
  }

  void dispose() {
    _disposed = true;
  }

  MiniProgramShareRequest _validatedRequest({
    required String miniProgramId,
    required String? title,
    required String? text,
    required Uri? url,
    required List<String> mediaRefs,
  }) {
    final appId = miniProgramId.trim();
    final normalizedTitle = _boundedOptional(
      title,
      miniProgramShareMaxTitleLength,
      'title',
    );
    final normalizedText = _boundedOptional(
      text,
      miniProgramShareMaxTextLength,
      'text',
    );
    if (appId.isEmpty) {
      throw const MiniProgramShareException(
        errorCode: MiniProgramErrorCodes.shareInvalidContent,
        message: 'The mini-program share owner is invalid.',
      );
    }
    if (url != null &&
        (url.scheme.toLowerCase() != 'https' ||
            url.host.isEmpty ||
            url.userInfo.isNotEmpty ||
            url.toString().length > miniProgramShareMaxUrlLength)) {
      throw const MiniProgramShareException(
        errorCode: MiniProgramErrorCodes.shareInvalidContent,
        message: 'Shared URLs must be absolute HTTPS URLs.',
      );
    }
    if (mediaRefs.length > miniProgramShareMaxMediaItems) {
      throw const MiniProgramShareException(
        errorCode: MiniProgramErrorCodes.shareTooManyItems,
        message: 'The share request contains too many media items.',
      );
    }
    final normalizedRefs = <String>[];
    for (final mediaRef in mediaRefs) {
      final normalized = mediaRef.trim();
      if (normalized.isEmpty || normalized.length > 512) {
        throw const MiniProgramShareException(
          errorCode: MiniProgramErrorCodes.shareInvalidContent,
          message: 'A shared media reference is invalid.',
        );
      }
      if (!normalizedRefs.contains(normalized)) normalizedRefs.add(normalized);
    }
    if (normalizedText == null && url == null && normalizedRefs.isEmpty) {
      throw const MiniProgramShareException(
        errorCode: MiniProgramErrorCodes.shareInvalidContent,
        message: 'Share content requires text, an HTTPS URL, or media.',
      );
    }
    return MiniProgramShareRequest(
      miniProgramId: appId,
      title: normalizedTitle,
      text: normalizedText,
      url: url,
      mediaRefs: List<String>.unmodifiable(normalizedRefs),
    );
  }

  String? _boundedOptional(String? value, int maxLength, String name) {
    if (value == null) return null;
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > maxLength) {
      throw MiniProgramShareException(
        errorCode: MiniProgramErrorCodes.shareInvalidContent,
        message: 'Share $name must contain 1-$maxLength characters.',
      );
    }
    return normalized;
  }

  void _ensureActive() {
    if (_disposed) throw StateError('MiniProgramShareManager is disposed.');
  }
}
