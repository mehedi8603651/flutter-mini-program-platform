import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Host-owned presentation only. It has no SDK, model, or network dependency.
@immutable
class HostAiBubbleStyle {
  const HostAiBubbleStyle({
    this.label = 'AI assistant',
    this.icon = const Icon(Icons.auto_awesome_rounded),
    this.diameter = 56,
    this.edgeMargin = 12,
    this.initialAlignment = const Alignment(1, 0.6),
    this.backgroundColor,
    this.foregroundColor,
  }) : assert(diameter >= 48 && diameter <= 88),
       assert(edgeMargin >= 0 && edgeMargin < double.infinity);

  final String label;
  final Widget icon;
  final double diameter;
  final double edgeMargin;
  final Alignment initialAlignment;
  final Color? backgroundColor;
  final Color? foregroundColor;
}

/// Place around a Navigator in MaterialApp.builder, outside SDK observation.
/// The child keeps its full constraints and identity as the assistant changes.
class HostAiBubble extends StatefulWidget {
  const HostAiBubble({
    super.key,
    required this.child,
    required this.onPressed,
    required this.status,
    this.running = false,
    this.canStop = false,
    this.onStop,
    this.statusLabel,
    this.badge,
    this.visible = true,
    this.style = const HostAiBubbleStyle(),
    this.onDocked,
  }) : assert(!(running || canStop) || onStop != null);

  final Widget child;
  final VoidCallback onPressed;
  final String status;
  final bool running;
  final bool canStop;
  final VoidCallback? onStop;
  final String? statusLabel;
  final Widget? badge;
  final bool visible;
  final HostAiBubbleStyle style;

  /// Normalized edge position; a host may persist it with its own preferences.
  final ValueChanged<Alignment>? onDocked;

  @override
  State<HostAiBubble> createState() => _HostAiBubbleState();
}

class _HostAiBubbleState extends State<HostAiBubble> {
  late Alignment _alignment = widget.style.initialAlignment;
  Offset? _dragPosition;

  static const _moveLeft = CustomSemanticsAction(label: 'Move assistant left');
  static const _moveRight = CustomSemanticsAction(
    label: 'Move assistant right',
  );
  static const _moveUp = CustomSemanticsAction(label: 'Move assistant up');
  static const _moveDown = CustomSemanticsAction(label: 'Move assistant down');

  void _dock(Alignment alignment) {
    setState(() {
      _alignment = Alignment(
        alignment.x < 0 ? -1 : 1,
        alignment.y.clamp(-1.0, 1.0),
      );
      _dragPosition = null;
    });
    widget.onDocked?.call(_alignment);
  }

  @override
  Widget build(BuildContext context) => Overlay.wrap(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final style = widget.style;
        final colorScheme = Theme.of(context).colorScheme;
        final diameter = style.diameter;
        final stopWidth = math.max(88.0, media.textScaler.scale(28) + 56);
        final showStop = widget.running || widget.canStop;
        final rowWidth = diameter + (showStop ? stopWidth + 8 : 0);
        final showStatus = widget.statusLabel?.isNotEmpty == true;
        final statusHeight = showStatus
            ? (media.textScaler.scale(12) * 1.4).ceilToDouble() + 12
            : 0.0;
        final height = diameter + statusHeight;
        final width = showStatus
            ? math.max(
                rowWidth,
                math.min(
                  180.0,
                  constraints.maxWidth -
                      media.viewPadding.horizontal -
                      style.edgeMargin * 2,
                ),
              )
            : rowWidth;
        final right = _alignment.x >= 0;
        // The root builder is not resized by Scaffold's keyboard avoidance.
        // Account for both system safe areas and the IME here, without applying
        // padding to (or otherwise moving) the mini-program beneath the bubble.
        final leftInset = media.viewPadding.left + style.edgeMargin;
        final topInset = media.viewPadding.top + style.edgeMargin;
        final rightInset = media.viewPadding.right + style.edgeMargin;
        final bottomInset =
            math.max(media.viewInsets.bottom, media.viewPadding.bottom) +
            style.edgeMargin;
        final minX = math.min(
          leftInset,
          math.max(0.0, constraints.maxWidth - width),
        );
        final minY = math.min(
          topInset,
          math.max(0.0, constraints.maxHeight - height),
        );
        final maxX = math.max(minX, constraints.maxWidth - rightInset - width);
        final maxY = math.max(
          minY,
          constraints.maxHeight - bottomInset - height,
        );
        Offset clamp(Offset value) =>
            Offset(value.dx.clamp(minX, maxX), value.dy.clamp(minY, maxY));
        final position = clamp(
          _dragPosition ??
              Offset(
                right ? maxX : minX,
                minY + (maxY - minY) * (_alignment.y.clamp(-1.0, 1.0) + 1) / 2,
              ),
        );

        final bubble = GestureDetector(
          onPanStart: (_) => setState(() => _dragPosition = position),
          onPanUpdate: (details) => setState(
            () => _dragPosition = clamp(
              (_dragPosition ?? position) + details.delta,
            ),
          ),
          onPanEnd: (_) {
            final current = clamp(_dragPosition ?? position);
            final centerX =
                current.dx + (right ? width - diameter : 0) + diameter / 2;
            _dock(
              Alignment(
                centerX < constraints.maxWidth / 2 ? -1 : 1,
                maxY == minY ? 0 : 2 * (current.dy - minY) / (maxY - minY) - 1,
              ),
            );
          },
          onPanCancel: () => _dock(_alignment),
          child: Semantics(
            key: const ValueKey('host_ai_bubble'),
            container: true,
            button: true,
            label: style.label,
            value: widget.status,
            hint: 'Tap to open. Drag to move.',
            onTap: widget.onPressed,
            customSemanticsActions: {
              _moveLeft: () => _dock(Alignment(-1, _alignment.y)),
              _moveRight: () => _dock(Alignment(1, _alignment.y)),
              _moveUp: () =>
                  _dock(Alignment(_alignment.x, _alignment.y - 0.25)),
              _moveDown: () =>
                  _dock(Alignment(_alignment.x, _alignment.y + 0.25)),
            },
            child: ExcludeSemantics(
              child: Tooltip(
                message: style.label,
                child: SizedBox.square(
                  dimension: diameter,
                  child: Material(
                    elevation: 6,
                    color:
                        style.backgroundColor ?? colorScheme.primaryContainer,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: widget.running
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                        width: widget.running ? 3 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.onPressed,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          IconTheme(
                            data: IconThemeData(
                              color:
                                  style.foregroundColor ??
                                  colorScheme.onPrimaryContainer,
                              size: diameter * 0.44,
                            ),
                            child: style.icon,
                          ),
                          if (widget.badge != null)
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: widget.badge!,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final stop = Semantics(
          container: true,
          button: true,
          label: 'Stop AI',
          onTap: widget.onStop,
          child: ExcludeSemantics(
            child: Tooltip(
              message: 'Stop AI',
              child: SizedBox(
                width: stopWidth,
                height: 48,
                child: FilledButton.icon(
                  key: const ValueKey('host_ai_bubble_stop'),
                  onPressed: widget.onStop,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.errorContainer,
                    foregroundColor: colorScheme.onErrorContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.stop_rounded, size: 20),
                  label: const Text('Stop', style: TextStyle(fontSize: 14)),
                ),
              ),
            ),
          ),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            // SDK modal routes may block previous semantics within the Navigator,
            // but must not hide the assistant's sibling accessibility controls.
            Semantics(
              container: true,
              explicitChildNodes: true,
              child: widget.child,
            ),
            if (widget.visible)
              Positioned(
                left: position.dx,
                top: position.dy,
                width: width,
                height: height,
                child: Column(
                  crossAxisAlignment: right
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: diameter,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showStop && right) ...[
                            stop,
                            const SizedBox(width: 8),
                          ],
                          bubble,
                          if (showStop && !right) ...[
                            const SizedBox(width: 8),
                            stop,
                          ],
                        ],
                      ),
                    ),
                    if (showStatus)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Material(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: widget.onPressed,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                widget.statusLabel!,
                                key: const ValueKey('host_ai_bubble_status'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}
