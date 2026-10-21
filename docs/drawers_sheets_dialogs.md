# Drawers, sheets, and dialogs

These APIs require UI `0.3.2`, SDK `0.7.2`, and contracts `0.3.19` or newer
compatible versions. Mini-program authors use pure Dart and the existing
`mini_program_ui` import. The SDK validates the JSON
and renders Material panels without another dependency, native bridge, or
Android permission. No new page or host setup parameters are needed.

## API

| API | Result |
| --- | --- |
| `Mp.drawer.left(child: ...)` | Open a panel on the physical left edge |
| `Mp.drawer.right(child: ...)` | Open a panel on the physical right edge |
| `Mp.drawer.close()` | Close the current owned drawer |
| `Mp.sheet.bottom(child: ...)` | Open a bottom sheet |
| `Mp.sheet.top(child: ...)` | Open a top sheet |
| `Mp.sheet.close()` | Close the current owned sheet |
| `Mp.dialog(message: ...)` | Open an alert or confirmation |
| `Mp.dialog.custom(child: ...)` | Open a centered panel with fully custom content |
| `Mp.dialog.close()` | Close the current owned dialog |

All builders return an `MpAction`. Attach them to any existing action control,
including an app-bar icon, list item, button, or floating action button. The
left/right names denote physical edges even in a right-to-left locale.

## A custom menu

```dart
import 'package:mini_program_ui/mini_program_ui.dart';

MpNode shopMenuButton() => Mp.iconButton(
  'menu',
  semanticLabel: 'Open shop menu',
  action: Mp.drawer.left(
    semanticLabel: 'Shop menu',
    child: Mp.column(children: [
      Mp.heading('My shop'),
      Mp.stateBuilder(
        keys: ['cart.count'],
        child: Mp.text('Cart items: {{state.cart.count}}'),
      ),
      Mp.primaryButton(
        label: 'Add an item',
        action: Mp.state.increment('cart.count'),
      ),
      Mp.primaryButton(
        label: 'Orders',
        action: Mp.action.sequence([
          Mp.drawer.close(),
          Mp.navigation.openScreen('orders'),
        ]),
      ),
      Mp.secondaryButton(label: 'Close', action: Mp.drawer.close()),
    ]),
  ),
);
```

The panel shares the calling mini-program's state store, route parameters,
named action definitions, item/index bindings, theme, and trusted host services.
Controls inside it retain the usual gesture and accepted-permission checks.
Existing action controls do not automatically close a panel: a filter can
change several values before the user chooses Apply.

As elsewhere in the DSL, use `Mp.stateBuilder` when display content should
rebuild after a state change. State-bound selection/input controls keep their
existing subscriptions. Store drafts in state with `Mp.stateTextField` or the
existing date/time fields when they should survive closing and reopening.

## Bottom and top sheets

```dart
final filters = Mp.sheet.bottom(
  heightFactor: 0.7,
  semanticLabel: 'Product filters',
  child: Mp.column(children: [
    Mp.heading('Filter products'),
    Mp.stateTextField(stateKey: 'filters.query', label: 'Search products'),
    Mp.primaryButton(label: 'Apply filters', action: Mp.sheet.close()),
  ]),
);

final information = Mp.sheet.top(
  heightFactor: 0.4,
  child: Mp.column(children: [
    Mp.heading('Shop information'),
    Mp.text('Open every day from 09:00 to 21:00.'),
    Mp.secondaryButton(label: 'Close', action: Mp.sheet.close()),
  ]),
);
```

Sheets use the available height after system safe areas and keyboard insets.
Content scrolls vertically; the drag handle remains outside the scroll area.
Top sheets place their handle on the lower edge and dismiss toward the top.
Bottom sheets place it on the upper edge and dismiss toward the bottom.

## Alerts and confirmations

Existing `Mp.dialog(title: ..., message: ..., confirmLabel: ...)` source and
default JSON remain supported. The callable namespace also supports explicit
close, custom content, and optional confirmation/cancel buttons:

```dart
final confirmBooking = Mp.dialog(
  title: 'Confirm booking',
  message: 'Book the selected ticket?',
  confirmLabel: 'Book ticket',
  cancelLabel: 'Keep editing',
  onConfirm: Mp.state.set('booking.confirmed', true),
);

final editNote = Mp.dialog.custom(
  semanticLabel: 'Edit booking note',
  child: Mp.column(children: [
    Mp.heading('Booking note'),
    Mp.stateTextField(stateKey: 'booking.note', label: 'Note'),
    Mp.primaryButton(label: 'Save', action: Mp.dialog.close()),
  ]),
);
```

`onConfirm` and `onCancel` run only when their respective button is pressed.
An explicit Cancel button can be requested using `cancelLabel`; supplying
`onCancel` alone gives it the default label `Cancel`. Back or backdrop dismissal
does not run either callback. A successful button action closes that dialog;
a failed action keeps it open with feedback. Pending confirmation actions
disable both buttons to prevent duplicate execution.

Custom dialog content owns its complete header and buttons. It uses ordinary
`MpAction`s and closes explicitly. An existing form around the opening control
can be shared with its panel; alternatively place an independent `Mp.form`
inside the panel.

## Styling and limits

| Option | Supported values |
| --- | --- |
| Drawer `width` | 80–1200 logical pixels; default 320; clamped to 94% of available width |
| Sheet `heightFactor` | 0.1–1 of available height; default 0.6 |
| Sheet `maxWidth` | 80–1200 logical pixels; default 640 |
| Custom dialog `width` | 80–1200 logical pixels; default 420 |
| `padding` | 0–64; default 16 for drawers/sheets and 24 for custom dialogs |
| `borderRadius` | 0–64; default 16 for drawers and 24 for sheets/custom dialogs |
| `backgroundColor`, `barrierColor` | Optional literal `#RRGGBB` or `#AARRGGBB` |
| `semanticLabel` | Optional accessible route label |
| `dismissible` | Backdrop taps close the panel when true; default true |
| Drawer/sheet `enableDrag` | Enables directional swipe dismissal; default true |
| Sheet `showDragHandle` | Shows the handle; default true |

Sheets and dialogs leave horizontal margins on narrow screens. Panels include
system safe areas, keyboard avoidance, bounded scrolling, route semantics, and
focus traversal. Content follows the existing scroll-layout rules: use a
column/list of naturally sized controls, or explicitly size a complex layout.

Opening is explicit; there is no implicit app-bar menu button or closed-edge
gesture to discover a panel definition. Users can close through an action,
Back, the backdrop when enabled, or an enabled directional swipe. Setting
`dismissible: false` disables backdrop dismissal; Back remains available.

## State, navigation, and lifecycle

- Opening a panel keeps the underlying mini-program screen mounted.
- Open actions complete after the panel closes, matching Flutter modal calls
  and the existing dialog behavior. Put preparatory sequence steps before the
  open action; put panel interactions inside its content.
- A close action is idempotent. It closes only the topmost panel of its family
  when that exact route is current; otherwise it succeeds with `closed: false`.
  It never pops the host, another mini-program, a date picker, or a different
  panel family. Explicit close actions complete without waiting for animation.
- Nested panels are supported up to eight live panels per rendered screen.
  Back dismisses the top route first. Normal screen navigation still belongs
  to the existing router/navigation actions.
- Owner disposal, app/store changes, and explicit hidden visibility cancel
  owned panels and remove their exact routes. Ordinary OS pauses keep pure UI
  mounted, including when a system photo picker or external app opens. The
  host retains its normal foreground-capability cleanup. Permission-dialog
  inactivity also keeps panels mounted. Late callbacks cannot close a new
  host route. The underlying live state keeps its existing lifetime.
- Closing a panel disposes its local widgets. Drafts in the app's state store
  remain available on reopening; local unbound widget state is not retained.
- Nested nodes/actions are validated before display. The payload, total node,
  node-depth, and structural limits cover panel content as well as the screen.

Stable runtime errors are `overlay_unavailable`, `overlay_foreground_required`,
`overlay_limit_exceeded`, and `overlay_request_cancelled`.

## Setup and upgrades

Update authoring and host dependencies to the compatible versions above.
Run pub get, rebuild the authored JSON/artifact, and rebuild the Flutter host.
Standard embedded hosts need no additional setup for panels.

For existing separate Android task integrations, also refresh the generated
Activity and Dart task root using tooling `0.7.20` or newer. Older generated
Activities return directly to the host on every Back press, bypassing panels.
The updated integration dismisses the keyboard first, then gives Flutter
panels and the mini-program's inner navigation priority. It returns to the
retained host only at the root. Embedded hosts need no native setup change.

```powershell
dart pub global activate mini_program_tooling 0.7.20
miniprogram embed init --project-root 'D:\path\to\host_app' --android-separate-tasks --force
```

The generator preserves host-owned setup and accepted policies. Custom native
integrations should follow the updated `hosts/mp_only_host` Back handling.

## Repository development checks

Use local path overrides for `mini_program_ui`, `mini_program_sdk`, and
`mini_program_contracts` when testing changes from this repository. The local
CLI can be run with `dart run bin/miniprogram.dart` from
`packages/mini_program_tooling` instead of the globally installed command.

```powershell
cd D:\flutter-mini-program-platform\packages\mini_program_ui
dart test test/features/overlays/overlay_actions_test.dart

cd D:\flutter-mini-program-platform\packages\mini_program_sdk
flutter test test/mp_screen_renderer_test.dart --plain-name "drawers, sheets and dialogs"
```
