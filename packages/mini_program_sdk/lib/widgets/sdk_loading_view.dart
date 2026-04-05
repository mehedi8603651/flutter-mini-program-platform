import 'package:flutter/material.dart';

/// Default loading view used while the SDK resolves a mini-program.
class SdkLoadingView extends StatelessWidget {
  const SdkLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );
  }
}
