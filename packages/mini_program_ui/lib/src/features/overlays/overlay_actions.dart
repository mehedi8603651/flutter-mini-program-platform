import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';
import '../../core/mp_node.dart';
import '../shared/presentation_validation.dart';

/// Opens custom side panels using ordinary Mp nodes and actions.
final class MpDrawerActions {
  const MpDrawerActions();

  /// Opens a panel on the physical left edge of the mini-program's route.
  MpAction left({
    required MpNode child,
    num width = 320,
    bool dismissible = true,
    bool enableDrag = true,
    num padding = 16,
    num borderRadius = 16,
    String? backgroundColor,
    String? barrierColor,
    String? semanticLabel,
  }) => _drawer(
    'left',
    child,
    width,
    dismissible,
    enableDrag,
    padding,
    borderRadius,
    backgroundColor,
    barrierColor,
    semanticLabel,
  );

  /// Opens a panel on the physical right edge of the mini-program's route.
  MpAction right({
    required MpNode child,
    num width = 320,
    bool dismissible = true,
    bool enableDrag = true,
    num padding = 16,
    num borderRadius = 16,
    String? backgroundColor,
    String? barrierColor,
    String? semanticLabel,
  }) => _drawer(
    'right',
    child,
    width,
    dismissible,
    enableDrag,
    padding,
    borderRadius,
    backgroundColor,
    barrierColor,
    semanticLabel,
  );

  /// Closes the topmost owned drawer, if it is the current route.
  MpAction close() => MpAction(ActionNames.drawerClose);
}

/// Opens custom sheets using ordinary Mp nodes and actions.
final class MpSheetActions {
  const MpSheetActions();

  /// Opens a sheet at the bottom of the mini-program's route.
  MpAction bottom({
    required MpNode child,
    num heightFactor = 0.6,
    num maxWidth = 640,
    bool dismissible = true,
    bool enableDrag = true,
    bool showDragHandle = true,
    num padding = 16,
    num borderRadius = 24,
    String? backgroundColor,
    String? barrierColor,
    String? semanticLabel,
  }) => _sheet(
    'bottom',
    child,
    heightFactor,
    maxWidth,
    dismissible,
    enableDrag,
    showDragHandle,
    padding,
    borderRadius,
    backgroundColor,
    barrierColor,
    semanticLabel,
  );

  /// Opens a sheet at the top, below the system safe area.
  MpAction top({
    required MpNode child,
    num heightFactor = 0.6,
    num maxWidth = 640,
    bool dismissible = true,
    bool enableDrag = true,
    bool showDragHandle = true,
    num padding = 16,
    num borderRadius = 24,
    String? backgroundColor,
    String? barrierColor,
    String? semanticLabel,
  }) => _sheet(
    'top',
    child,
    heightFactor,
    maxWidth,
    dismissible,
    enableDrag,
    showDragHandle,
    padding,
    borderRadius,
    backgroundColor,
    barrierColor,
    semanticLabel,
  );

  /// Closes the topmost owned sheet, if it is the current route.
  MpAction close() => MpAction(ActionNames.sheetClose);
}

/// Callable dialog namespace preserving the existing `Mp.dialog(...)` API.
final class MpDialogActions {
  const MpDialogActions();

  /// Opens an alert or confirmation. Callbacks require a button press;
  /// tapping the backdrop or pressing Back does not confirm or cancel.
  MpAction call({
    String? title,
    required String message,
    String confirmLabel = 'OK',
    String? cancelLabel,
    MpAction? onConfirm,
    MpAction? onCancel,
    bool dismissible = true,
    String? backgroundColor,
    String? barrierColor,
    String? semanticLabel,
  }) => MpAction(
    ActionNames.dialogOpen,
    props: <String, Object?>{
      if (title != null) 'title': requiredAuthoringString(title, 'title'),
      'message': requiredAuthoringString(message, 'message'),
      'confirmLabel': requiredAuthoringString(confirmLabel, 'confirmLabel'),
      if (cancelLabel != null || onCancel != null)
        'cancelLabel': requiredAuthoringString(
          cancelLabel ?? 'Cancel',
          'cancelLabel',
        ),
      if (onConfirm != null) 'onConfirm': onConfirm,
      if (onCancel != null) 'onCancel': onCancel,
      if (!dismissible) 'dismissible': false,
      ..._colorsAndLabel(backgroundColor, barrierColor, semanticLabel),
    },
  );

  /// Opens a centered dialog whose complete content is supplied by the author.
  /// Custom content owns its buttons and can use [close] to dismiss itself.
  MpAction custom({
    required MpNode child,
    num width = 420,
    num padding = 24,
    num borderRadius = 24,
    bool dismissible = true,
    String? backgroundColor,
    String? barrierColor,
    String? semanticLabel,
  }) => MpAction(
    ActionNames.dialogOpen,
    props: <String, Object?>{
      'child': child,
      'width': _number(width, 'width', 80, 1200),
      ..._surface(
        padding,
        borderRadius,
        dismissible,
        backgroundColor,
        barrierColor,
        semanticLabel,
      ),
    },
  );

  /// Closes the topmost owned dialog, if it is the current route.
  MpAction close() => MpAction(ActionNames.dialogClose);
}

MpAction _drawer(
  String side,
  MpNode child,
  num width,
  bool dismissible,
  bool enableDrag,
  num padding,
  num borderRadius,
  String? backgroundColor,
  String? barrierColor,
  String? semanticLabel,
) => MpAction(
  ActionNames.drawerOpen,
  props: <String, Object?>{
    'side': side,
    'child': child,
    'width': _number(width, 'width', 80, 1200),
    'enableDrag': enableDrag,
    ..._surface(
      padding,
      borderRadius,
      dismissible,
      backgroundColor,
      barrierColor,
      semanticLabel,
    ),
  },
);

MpAction _sheet(
  String side,
  MpNode child,
  num heightFactor,
  num maxWidth,
  bool dismissible,
  bool enableDrag,
  bool showDragHandle,
  num padding,
  num borderRadius,
  String? backgroundColor,
  String? barrierColor,
  String? semanticLabel,
) => MpAction(
  ActionNames.sheetOpen,
  props: <String, Object?>{
    'side': side,
    'child': child,
    'heightFactor': _number(heightFactor, 'heightFactor', 0.1, 1),
    'maxWidth': _number(maxWidth, 'maxWidth', 80, 1200),
    'enableDrag': enableDrag,
    'showDragHandle': showDragHandle,
    ..._surface(
      padding,
      borderRadius,
      dismissible,
      backgroundColor,
      barrierColor,
      semanticLabel,
    ),
  },
);

Map<String, Object?> _surface(
  num padding,
  num borderRadius,
  bool dismissible,
  String? backgroundColor,
  String? barrierColor,
  String? semanticLabel,
) => {
  'padding': _number(padding, 'padding', 0, 64),
  'borderRadius': _number(borderRadius, 'borderRadius', 0, 64),
  'dismissible': dismissible,
  ..._colorsAndLabel(backgroundColor, barrierColor, semanticLabel),
};

Map<String, Object?> _colorsAndLabel(
  String? backgroundColor,
  String? barrierColor,
  String? semanticLabel,
) => {
  if (backgroundColor != null)
    'backgroundColor': widgetColor(backgroundColor, 'backgroundColor'),
  if (barrierColor != null)
    'barrierColor': widgetColor(barrierColor, 'barrierColor'),
  if (semanticLabel != null)
    'semanticLabel': requiredAuthoringString(semanticLabel, 'semanticLabel'),
};

num _number(num value, String name, num minimum, num maximum) {
  if (!value.isFinite || value < minimum || value > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'Value must be finite and between $minimum and $maximum.',
    );
  }
  return value;
}
