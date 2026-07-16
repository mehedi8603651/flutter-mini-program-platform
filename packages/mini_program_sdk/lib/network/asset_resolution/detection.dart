part of '../asset_resolver.dart';

extension _AssetResolverDetection on AssetResolver {
  bool _isNetworkImageWidget(Map<String, dynamic> json) {
    if (json['type'] != 'image') {
      return false;
    }

    final sourceUri = json['src'];
    if (sourceUri is! String || !_looksLikeRemoteUrl(sourceUri)) {
      return false;
    }

    final imageType = json['imageType'];
    return imageType == null || imageType == 'network';
  }

  bool _looksLikeRemoteUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  String? _extensionFromSource(String sourceUri) {
    final uri = Uri.tryParse(sourceUri);
    if (uri == null) {
      return null;
    }

    final path = uri.path.toLowerCase();
    if (path.endsWith('.png')) {
      return '.png';
    }
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
      return '.jpg';
    }
    if (path.endsWith('.webp')) {
      return '.webp';
    }
    if (path.endsWith('.svg')) {
      return '.svg';
    }
    if (path.endsWith('.gif')) {
      return '.gif';
    }
    return null;
  }
}
