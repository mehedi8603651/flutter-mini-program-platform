part of '../../mp_screen_renderer.dart';

class _MpQrCode extends StatelessWidget {
  const _MpQrCode({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final size = (node.props['size'] as num).toDouble();
    final padding = (node.props['padding'] as num).toDouble();
    final semanticLabel = bindings.resolveString(
      node.props['semanticLabel'] as String,
    );
    final value = bindings.resolveString(node.props['value'] as String);
    if (value.isEmpty || value.length > 4096) {
      return _invalidQr(size, semanticLabel);
    }
    try {
      final code = QrCode.fromData(
        data: value,
        errorCorrectLevel: _qrErrorCorrection(
          node.props['errorCorrection'] as String,
        ),
      );
      final image = QrImage(code);
      return Semantics(
        image: true,
        label: semanticLabel,
        child: SizedBox.square(
          dimension: size,
          child: ColoredBox(
            color: _mpColor(
              node.props['backgroundColor'] as String,
              fallback: const Color(0xFFFFFFFF),
            ),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _MpQrPainter(
                    image: image,
                    color: _mpColor(
                      node.props['foregroundColor'] as String,
                      fallback: const Color(0xFF000000),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } on Object {
      return _invalidQr(size, semanticLabel);
    }
  }

  Widget _invalidQr(double size, String semanticLabel) {
    return Semantics(
      image: true,
      label: '$semanticLabel unavailable',
      child: SizedBox.square(
        dimension: size,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

class _MpQrPainter extends CustomPainter {
  const _MpQrPainter({required this.image, required this.color});

  final QrImage image;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final modules = image.moduleCount;
    const quietZoneModules = 4;
    final moduleSize =
        math.min(size.width, size.height) / (modules + quietZoneModules * 2);
    final left = (size.width - moduleSize * modules) / 2;
    final top = (size.height - moduleSize * modules) / 2;
    final paint = Paint()..color = color;
    for (var row = 0; row < modules; row++) {
      for (var column = 0; column < modules; column++) {
        if (!image.isDark(row, column)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            left + column * moduleSize,
            top + row * moduleSize,
            moduleSize + 0.01,
            moduleSize + 0.01,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MpQrPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.color != color;
}

int _qrErrorCorrection(String value) => switch (value) {
  'low' => QrErrorCorrectLevel.L,
  'medium' => QrErrorCorrectLevel.M,
  'quartile' => QrErrorCorrectLevel.Q,
  'high' => QrErrorCorrectLevel.H,
  _ => QrErrorCorrectLevel.M,
};
