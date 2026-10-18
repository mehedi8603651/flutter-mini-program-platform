/// Maximum number of images in one gallery selection.
const int miniProgramGalleryMaxImages = 30;

/// JSON-safe metadata for a selected photo held privately by the host.
class MiniProgramGalleryImage {
  MiniProgramGalleryImage({
    required this.mediaRef,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.width,
    required this.height,
  }) {
    validate();
  }

  factory MiniProgramGalleryImage.fromJson(Map<String, dynamic> json) {
    if (json['mediaRef'] is! String ||
        json['fileName'] is! String ||
        json['mimeType'] is! String ||
        json['bytes'] is! int ||
        json['width'] is! int ||
        json['height'] is! int ||
        json['source'] != 'gallery') {
      throw const FormatException('Invalid gallery image metadata.');
    }
    return MiniProgramGalleryImage(
      mediaRef: json['mediaRef'] as String,
      fileName: json['fileName'] as String,
      mimeType: json['mimeType'] as String,
      bytes: json['bytes'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
    );
  }

  final String mediaRef;
  final String fileName;
  final String mimeType;
  final int bytes;
  final int width;
  final int height;

  void validate() {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,160}$').hasMatch(mediaRef) ||
        fileName.isEmpty ||
        fileName.length > 255 ||
        RegExp(r'[/\\\x00-\x1f]').hasMatch(fileName) ||
        !const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType) ||
        bytes <= 0 ||
        bytes > 100 * 1024 * 1024 ||
        width < 1 ||
        height < 1 ||
        width > 8192 ||
        height > 8192 ||
        width * height > 16 * 1024 * 1024) {
      throw const FormatException('Invalid gallery image metadata.');
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'mediaRef': mediaRef,
      'fileName': fileName,
      'mimeType': mimeType,
      'bytes': bytes,
      'width': width,
      'height': height,
      'source': 'gallery',
    };
  }
}

/// One atomic image selection. No native locations or image bytes are exposed.
class MiniProgramGalleryResult {
  MiniProgramGalleryResult({
    required this.selectionId,
    required List<MiniProgramGalleryImage> images,
    required this.selectedAtUtc,
  }) : images = List.unmodifiable(images) {
    validate();
  }

  factory MiniProgramGalleryResult.fromJson(Map<String, dynamic> json) {
    final images = json['images'];
    final selectedAt = json['selectedAtUtc'];
    if (json['selectionId'] is! String ||
        images is! List ||
        images.isEmpty ||
        images.length > miniProgramGalleryMaxImages ||
        selectedAt is! String) {
      throw const FormatException('Invalid gallery selection metadata.');
    }
    final timestamp = DateTime.tryParse(selectedAt);
    if (timestamp == null) {
      throw const FormatException('Invalid gallery selection timestamp.');
    }
    return MiniProgramGalleryResult(
      selectionId: json['selectionId'] as String,
      images: images.map((image) {
        if (image is! Map<String, dynamic>) {
          throw const FormatException('Invalid gallery image metadata.');
        }
        return MiniProgramGalleryImage.fromJson(image);
      }).toList(),
      selectedAtUtc: timestamp,
    );
  }

  final String selectionId;
  final List<MiniProgramGalleryImage> images;
  final DateTime selectedAtUtc;

  void validate() {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,160}$').hasMatch(selectionId) ||
        images.isEmpty ||
        images.length > miniProgramGalleryMaxImages ||
        !selectedAtUtc.isUtc ||
        images.map((image) => image.mediaRef).toSet().length != images.length) {
      throw const FormatException('Invalid gallery selection metadata.');
    }
    for (final image in images) {
      image.validate();
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'selectionId': selectionId,
      'images': images.map((image) => image.toJson()).toList(growable: false),
      'selectedAtUtc': selectedAtUtc.toIso8601String(),
    };
  }
}
