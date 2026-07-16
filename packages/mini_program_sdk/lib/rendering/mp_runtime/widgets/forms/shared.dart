part of '../../../mp_screen_renderer.dart';

class _MpFieldFrame extends StatelessWidget {
  const _MpFieldFrame({
    required this.label,
    required this.child,
    this.hint,
    this.error,
  });

  final String label;
  final String? hint;
  final String? error;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (label.isNotEmpty) ...<Widget>[
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          child,
          if (hint != null && hint!.isNotEmpty && error == null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
          if (error != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

BoxDecoration _fieldDecoration({String? error, bool focused = false}) {
  return BoxDecoration(
    color: const Color(0xFFFFFFFF),
    border: Border.all(
      color: error != null
          ? const Color(0xFFDC2626)
          : focused
          ? const Color(0xFF0B7A75)
          : const Color(0xFFD1D5DB),
    ),
    borderRadius: BorderRadius.circular(8),
  );
}

TextInputType _keyboardType(String? value) {
  return switch (value) {
    'email' => TextInputType.emailAddress,
    'number' => TextInputType.number,
    'phone' => TextInputType.phone,
    'url' => TextInputType.url,
    _ => TextInputType.text,
  };
}

List<Map<String, dynamic>> _options(_MpNode node) {
  return (node.props['options'] as List)
      .whereType<Map>()
      .map((option) => Map<String, dynamic>.from(option))
      .toList(growable: false);
}

Map<String, dynamic>? _optionForValue(_MpNode node, String value) {
  for (final option in _options(node)) {
    if (option['value'] == value) {
      return option;
    }
  }
  return null;
}

class _MpOptionDialog extends StatelessWidget {
  const _MpOptionDialog({
    required this.title,
    required this.options,
    required this.onSelected,
  });

  final String title;
  final List<Map<String, dynamic>> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                for (final option in options)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(option['value'] as String),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        option['label'] as String,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MpCheckMark extends StatelessWidget {
  const _MpCheckMark({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: checked ? const Color(0xFF0B7A75) : const Color(0xFFFFFFFF),
        border: Border.all(color: const Color(0xFF0B7A75), width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: checked
              ? const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFFFFFFFF)),
                  child: SizedBox(width: 10, height: 10),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _MpRadioMark extends StatelessWidget {
  const _MpRadioMark({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0B7A75), width: 1.5),
      ),
      child: SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: checked
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF0B7A75),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 10, height: 10),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
