/// JSON-safe metadata for a photo captured by a trusted host provider.
///
/// [mediaRef] is an opaque, short-lived host reference. It is not a native
/// path, content URI, or encoded image payload.
class MiniProgramCameraPhotoResult {
  MiniProgramCameraPhotoResult({
    required String captureId,
    required String mediaRef,
    required String fileName,
    required String mimeType,
    required this.bytes,
    required this.width,
    required this.height,
    required this.capturedAtUtc,
    this.source = cameraSource,
  }) : captureId = _cameraString(captureId, 'captureId', 512),
       mediaRef = _cameraString(mediaRef, 'mediaRef', 512),
       fileName = _cameraString(fileName, 'fileName', 255),
       mimeType = _cameraMimeType(mimeType) {
    validate();
  }

  factory MiniProgramCameraPhotoResult.fromJson(Map<String, dynamic> json) {
    final bytes = json['bytes'];
    final width = json['width'];
    final height = json['height'];
    final capturedAtUtc = json['capturedAtUtc'];
    if (json['captureId'] is! String ||
        json['mediaRef'] is! String ||
        json['fileName'] is! String ||
        json['mimeType'] is! String ||
        bytes is! int ||
        width is! int ||
        height is! int ||
        capturedAtUtc is! String ||
        json['source'] is! String) {
      throw const FormatException('Invalid mini-program camera result.');
    }
    final capturedAt = DateTime.tryParse(capturedAtUtc);
    if (capturedAt == null) {
      throw const FormatException(
        'Camera capturedAtUtc must be an ISO-8601 timestamp.',
      );
    }
    return MiniProgramCameraPhotoResult(
      captureId: json['captureId']! as String,
      mediaRef: json['mediaRef']! as String,
      fileName: json['fileName']! as String,
      mimeType: json['mimeType']! as String,
      bytes: bytes,
      width: width,
      height: height,
      capturedAtUtc: capturedAt,
      source: json['source']! as String,
    );
  }

  static const String cameraSource = 'camera';

  final String captureId;
  final String mediaRef;
  final String fileName;
  final String mimeType;
  final int bytes;
  final int width;
  final int height;
  final DateTime capturedAtUtc;
  final String source;

  void validate() {
    if (bytes <= 0) {
      throw const FormatException('Camera bytes must be positive.');
    }
    if (width <= 0 || width > 65535 || height <= 0 || height > 65535) {
      throw const FormatException(
        'Camera dimensions must be integers from 1 to 65535.',
      );
    }
    if (!capturedAtUtc.isUtc) {
      throw const FormatException('Camera capturedAtUtc must be UTC.');
    }
    if (source != cameraSource) {
      throw const FormatException('Camera source must be "camera".');
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return <String, dynamic>{
      'captureId': captureId,
      'mediaRef': mediaRef,
      'fileName': fileName,
      'mimeType': mimeType,
      'bytes': bytes,
      'width': width,
      'height': height,
      'capturedAtUtc': capturedAtUtc.toIso8601String(),
      'source': source,
    };
  }
}

String _cameraString(String value, String name, int maxLength) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > maxLength) {
    throw FormatException('$name must be 1-$maxLength characters.');
  }
  return normalized;
}

String _cameraMimeType(String value) {
  final normalized = value.trim().toLowerCase();
  final parts = normalized.split('/');
  final token = RegExp(r'^[a-z0-9!#$&^_.+-]+$');
  if (parts.length != 2 ||
      parts.first != 'image' ||
      !token.hasMatch(parts.last)) {
    throw const FormatException('Camera mimeType must be an image MIME type.');
  }
  return normalized;
}
