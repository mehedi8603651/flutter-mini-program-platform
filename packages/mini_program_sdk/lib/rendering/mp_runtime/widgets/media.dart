part of '../../mp_screen_renderer.dart';

class _MpImage extends StatelessWidget {
  const _MpImage({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final src = bindings.resolveString(node.props['src'] as String);
    final source = _resolvedImageSource(src);
    Widget image;
    switch (source) {
      case 'network':
        if (!_isHttpImageSrc(src)) {
          image = _imageErrorFallback(context);
          break;
        }
        image = Image.network(
          src,
          errorBuilder: (context, error, stackTrace) =>
              _imageErrorFallback(context),
          fit: _mpBoxFit(_string(node, 'fit')),
          frameBuilder: _imageFrameBuilder,
          headers: _resolvedHeaders(),
          semanticLabel: _semanticLabel,
        );
        break;
      case 'asset':
        image = Image.asset(
          src,
          errorBuilder: (context, error, stackTrace) =>
              _imageErrorFallback(context),
          fit: _mpBoxFit(_string(node, 'fit')),
          frameBuilder: _imageFrameBuilder,
          semanticLabel: _semanticLabel,
        );
        break;
      case 'base64':
        try {
          image = Image.memory(
            base64Decode(_paddedBase64(_base64ImagePayload(src))),
            errorBuilder: (context, error, stackTrace) =>
                _imageErrorFallback(context),
            fit: _mpBoxFit(_string(node, 'fit')),
            frameBuilder: _imageFrameBuilder,
            semanticLabel: _semanticLabel,
          );
        } on FormatException {
          image = _imageErrorFallback(context);
        }
        break;
      default:
        image = _imageErrorFallback(context);
        break;
    }

    final width = _optionalDouble(node, 'width');
    final height = _optionalDouble(node, 'height');
    if (width == null && height == null) {
      return image;
    }
    return SizedBox(width: width, height: height, child: image);
  }

  String? get _semanticLabel {
    final label = node.props['semanticLabel'] ?? node.props['alt'];
    return label == null ? null : bindings.resolveString(label as String);
  }

  String _resolvedImageSource(String src) {
    final configured = _string(node, 'source');
    if (configured != 'auto') {
      return configured;
    }
    if (_isHttpImageSrc(src)) {
      return 'network';
    }
    if (_isDataUriBase64Image(src)) {
      return 'base64';
    }
    if (_isAssetLikeImageSrc(src)) {
      return 'asset';
    }
    try {
      base64Decode(_paddedBase64(_base64ImagePayload(src)));
      return 'base64';
    } on FormatException {
      return 'asset';
    }
  }

  Map<String, String>? _resolvedHeaders() {
    final headers = node.props['headers'] as Map<String, dynamic>?;
    if (headers == null || headers.isEmpty) {
      return null;
    }
    return <String, String>{
      for (final entry in headers.entries)
        entry.key: bindings.resolveString(entry.value as String),
    };
  }

  Widget _imageFrameBuilder(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded || frame != null) {
      return _fadeIn(child, wasSynchronouslyLoaded: wasSynchronouslyLoaded);
    }
    return _imageLoadingFallback(context);
  }

  Widget _fadeIn(Widget child, {required bool wasSynchronouslyLoaded}) {
    final durationMs = _int(node, 'fadeInDurationMs', fallback: 200);
    if (wasSynchronouslyLoaded || durationMs <= 0) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: durationMs),
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: child,
    );
  }

  Widget _imageLoadingFallback(BuildContext context) {
    final placeholder = node.props['placeholder'] as _MpNode?;
    if (placeholder == null) {
      return const SizedBox.shrink();
    }
    return _MpNodeView(node: placeholder, bindings: bindings);
  }

  Widget _imageErrorFallback(BuildContext context) {
    final error = node.props['error'] as _MpNode?;
    if (error != null) {
      return _MpNodeView(node: error, bindings: bindings);
    }
    final label = _semanticLabel;
    if (label != null && label.isNotEmpty) {
      return Text(label);
    }
    return const Text('Image unavailable');
  }
}

class _MpIcon extends StatelessWidget {
  const _MpIcon({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = node.props['semanticLabel'] as String?;
    return _MpIconGlyph(
      name: _string(node, 'name'),
      size: _double(node, 'size', fallback: 20),
      color: node.props['color'] == null
          ? _mpThemeToken(
              bindings.theme,
              'icon',
              fallback: _mpThemeToken(
                bindings.theme,
                'textMuted',
                fallback: const Color(0xFF4B5563),
              ),
            )
          : _mpColor(
              node.props['color'] as String?,
              fallback: const Color(0xFF4B5563),
            ),
      semanticLabel: semanticLabel == null
          ? null
          : bindings.resolveString(semanticLabel),
    );
  }
}

class _MpIconGlyph extends StatelessWidget {
  const _MpIconGlyph({
    required this.name,
    required this.size,
    required this.color,
    this.semanticLabel,
  });

  final String name;
  final double size;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Icon(
      _mpIconData(name),
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    );
  }
}

BoxFit _mpBoxFit(String value) {
  return switch (value) {
    'contain' => BoxFit.contain,
    'fill' => BoxFit.fill,
    'fitWidth' => BoxFit.fitWidth,
    'fitHeight' => BoxFit.fitHeight,
    'none' => BoxFit.none,
    _ => BoxFit.cover,
  };
}

bool _isRenderableImageUrl(String src) {
  final uri = Uri.tryParse(src);
  if (uri == null || !uri.hasAuthority) {
    return false;
  }
  return uri.scheme == 'https' ||
      (uri.scheme == 'http' && _isLocalPreviewHost(uri.host));
}

bool _isHttpImageSrc(String src) {
  final uri = Uri.tryParse(src);
  return uri != null &&
      uri.hasAuthority &&
      (uri.scheme == 'http' || uri.scheme == 'https');
}

bool _isDataUriBase64Image(String src) {
  return RegExp(
    r'^data:image\/[-+.\w]+;base64,',
    caseSensitive: false,
  ).hasMatch(src.trim());
}

bool _isAssetLikeImageSrc(String src) {
  final normalized = src.trim().toLowerCase();
  if (normalized.startsWith('assets/') ||
      normalized.startsWith('asset/') ||
      normalized.startsWith('images/') ||
      normalized.startsWith('packages/')) {
    return true;
  }
  return normalized.endsWith('.png') ||
      normalized.endsWith('.jpg') ||
      normalized.endsWith('.jpeg') ||
      normalized.endsWith('.gif') ||
      normalized.endsWith('.webp') ||
      normalized.endsWith('.bmp') ||
      normalized.endsWith('.avif');
}

IconData _mpIconData(String name) {
  final icon = _mpIcons[name];
  if (icon == null) {
    throw MiniProgramRenderException(
      message: 'Unsupported Mp icon "$name".',
      details: <String, dynamic>{'iconName': name},
    );
  }
  return icon;
}

const Map<String, IconData> _mpIcons = <String, IconData>{
  'person': IconData(0xe491, fontFamily: 'MaterialIcons'),
  'settings': IconData(0xe57f, fontFamily: 'MaterialIcons'),
  'chevronRight': IconData(
    0xe15f,
    fontFamily: 'MaterialIcons',
    matchTextDirection: true,
  ),
  'star': IconData(0xe5f9, fontFamily: 'MaterialIcons'),
  'gift': IconData(0xe13e, fontFamily: 'MaterialIcons'),
  'check': IconData(0xe156, fontFamily: 'MaterialIcons'),
  'warning': IconData(0xe6cb, fontFamily: 'MaterialIcons'),
  'info': IconData(0xe33d, fontFamily: 'MaterialIcons'),
  'lock': IconData(0xe3b1, fontFamily: 'MaterialIcons'),
  'mail': IconData(0xe3c4, fontFamily: 'MaterialIcons'),
  'home': IconData(0xf107, fontFamily: 'MaterialIcons'),
  'search': IconData(0xe567, fontFamily: 'MaterialIcons'),
  'history': IconData(0xe314, fontFamily: 'MaterialIcons'),
  'backspace': IconData(
    0xe0c5,
    fontFamily: 'MaterialIcons',
    matchTextDirection: true,
  ),
  'arrowBack': IconData(
    0xe092,
    fontFamily: 'MaterialIcons',
    matchTextDirection: true,
  ),
  'brain': IconData(0xf08b1, fontFamily: 'MaterialIcons'),
  'trophy': IconData(0xf01a, fontFamily: 'MaterialIcons'),
  'timer': IconData(0xf44a, fontFamily: 'MaterialIcons'),
  'close': IconData(0xf647, fontFamily: 'MaterialIcons'),
  'refresh': IconData(0xf00e9, fontFamily: 'MaterialIcons'),
  'bolt': IconData(0xf5ca, fontFamily: 'MaterialIcons'),
  'location': IconData(0xf193, fontFamily: 'MaterialIcons'),
  'menu': IconData(0xf8b6, fontFamily: 'MaterialIcons'),
  'add': IconData(0xe047, fontFamily: 'MaterialIcons'),
  'delete': IconData(0xe1b9, fontFamily: 'MaterialIcons'),
  'edit': IconData(0xe21a, fontFamily: 'MaterialIcons'),
  'note': IconData(
    0xe449,
    fontFamily: 'MaterialIcons',
    matchTextDirection: true,
  ),
  'sunny': IconData(0xf4bc, fontFamily: 'MaterialIcons'),
  'cloudy': IconData(0xef62, fontFamily: 'MaterialIcons'),
  'rain': IconData(0xf46d, fontFamily: 'MaterialIcons'),
  'thunderstorm': IconData(0xf071b, fontFamily: 'MaterialIcons'),
  'waterDrop': IconData(0xf0695, fontFamily: 'MaterialIcons'),
  'wind': IconData(0xf542, fontFamily: 'MaterialIcons'),
  'thermometer': IconData(0xf022c, fontFamily: 'MaterialIcons'),
  'snow': IconData(0xe037, fontFamily: 'MaterialIcons'),
  'fog': IconData(0xf0505, fontFamily: 'MaterialIcons'),
  'public': IconData(0xe4f0, fontFamily: 'MaterialIcons'),
};
