import 'package:flutter/material.dart';

import '../mini_program_failure.dart';

/// Default fallback error view when a mini-program cannot be loaded or rendered.
class SdkErrorView extends StatelessWidget {
  const SdkErrorView({super.key, required this.failure});

  final MiniProgramFailure failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                'Mini-program unavailable',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                failure.displayMessage,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (failure.errorCode != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Error code: ${failure.errorCode}',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
