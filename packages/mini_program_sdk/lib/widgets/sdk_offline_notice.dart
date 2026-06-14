import 'package:flutter/material.dart';

/// Floating offline-state notice shown when the SDK renders stale cached data.
class SdkOfflineNotice extends StatelessWidget {
  const SdkOfflineNotice({super.key, required this.cachedAssetCount});

  final int cachedAssetCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetSummary = cachedAssetCount > 0
        ? ' Includes $cachedAssetCount cached asset${cachedAssetCount == 1 ? '' : 's'}.'
        : '';

    return SafeArea(
      minimum: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            color: const Color(0xFFE8F3FF),
            elevation: 2,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Showing cached content while the backend is unavailable.$assetSummary',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
