part of '../../mp_screen_renderer.dart';

class _MpToastView extends StatelessWidget {
  const _MpToastView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _MpDialogView extends StatelessWidget {
  const _MpDialogView({
    required this.message,
    required this.confirmLabel,
    this.title,
  });

  final String? title;
  final String message;
  final String confirmLabel;

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
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Text(
                    title!,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF263238),
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: _MpTapButton(
                    label: confirmLabel,
                    primary: true,
                    onTap: () => Navigator.of(context).pop(),
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
