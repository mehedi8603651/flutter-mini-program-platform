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
            style: const TextStyle(
              inherit: false,
              color: Color(0xFFFFFFFF),
              decoration: TextDecoration.none,
              fontSize: 14,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}
