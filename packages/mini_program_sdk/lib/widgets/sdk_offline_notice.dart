import 'dart:async';

import 'package:flutter/material.dart';

/// Floating offline-state notice shown when the SDK renders stale cached data.
class SdkOfflineNotice extends StatefulWidget {
  const SdkOfflineNotice({
    super.key,
    required this.cachedAssetCount,
    this.displayDuration = const Duration(seconds: 2),
  });

  final int cachedAssetCount;
  final Duration displayDuration;

  @override
  State<SdkOfflineNotice> createState() => _SdkOfflineNoticeState();
}

class _SdkOfflineNoticeState extends State<SdkOfflineNotice> {
  static const _backgroundColor = Color.fromARGB(255, 59, 33, 153);
  static const _textColor = Color.fromARGB(255, 250, 249, 248);
  static const _iconColor = Color.fromARGB(255, 252, 249, 249);

  Timer? _dismissTimer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(widget.displayDuration, () {
      if (mounted) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final assetSummary = widget.cachedAssetCount > 0
        ? ' Includes ${widget.cachedAssetCount} cached asset${widget.cachedAssetCount == 1 ? '' : 's'}.'
        : '';

    return SafeArea(
      minimum: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            color: _backgroundColor,
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, color: _iconColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Showing cached content while the backend is unavailable.$assetSummary',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _textColor,
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
