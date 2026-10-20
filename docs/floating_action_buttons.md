# Floating action buttons

`Mp.floatingActionButton` creates standalone action buttons using pure Dart.
The authoring package serializes JSON; the existing Flutter host SDK renders
the corresponding Material button. No new package, Android permission, native
bridge, or page API is required.

Requires UI `0.2.15`, SDK `0.6.17`, and tooling `0.7.17` or newer compatible
releases. Contracts remain `0.3.18`. Rebuild hosts with the new SDK before
delivering artifacts containing this new node to them.

## Variants

```dart
import 'package:mini_program_ui/mini_program_ui.dart';

final addBooking = Mp.state.increment('booking.count');

final standard = Mp.floatingActionButton(
  icon: 'add',
  semanticLabel: 'Add booking',
  action: addBooking,
);

final small = Mp.floatingActionButton.small(
  icon: 'edit',
  semanticLabel: 'Edit booking',
  action: Mp.navigation.openScreen('booking_edit'),
);

final large = Mp.floatingActionButton.large(
  icon: 'add',
  semanticLabel: 'Create booking',
  action: Mp.navigation.openScreen('booking_create'),
);

final extended = Mp.floatingActionButton.extended(
  label: 'Book now',
  icon: 'add', // Optional for the extended variant.
  action: Mp.navigation.openScreen('booking_create'),
);
```

The three icon variants require `icon`, `semanticLabel`, and `action`. The
extended variant requires `label` and `action`; `icon` is optional and
`semanticLabel` defaults to the visible label. Icons use the existing Mp icon
allowlist, for example `add`, `edit`, `search`, or `location`.

Every variant accepts `enabled` (default true), `backgroundColor`, and
`foregroundColor`. Colors are optional literal `#RRGGBB` or `#AARRGGBB` strings;
omitted values use the host's Material FAB theme. Size and shape follow the
corresponding Flutter variant and host theme. The default Material visual sizes
are 56, 40, and 96 logical pixels for standard, small, and large; accessible tap
targets may be larger. Extended buttons size to their text and available width.

Labels and accessible descriptions must be non-empty and at most 512 characters.
They can use existing runtime bindings. Wrap a state-dependent label in
`Mp.stateBuilder` with the relevant keys for reactive updates. `enabled` is a
literal boolean; use existing conditional nodes to select a disabled variant
from state. Disabled buttons retain their name and do not dispatch actions.

## Positioning

Place the button inside the current layout using `Mp.stack` and
`Mp.positioned`; these builders do not require a new page or scaffold slot:

```dart
MpNode withBookingButton(MpNode scrollableContent) => Mp.stack(
  children: [
    scrollableContent,
    Mp.positioned(
      right: 16,
      bottom: 16,
      child: Mp.floatingActionButton.extended(
        label: 'Book now',
        icon: 'add',
        action: Mp.navigation.openScreen('booking_create'),
      ),
    ),
  ],
);
```

For a button that stays fixed while content scrolls, the stack belongs in a
bounded viewport and its content should fill that area. Put the scrolling
content inside the stack, and keep the positioned button outside that scrolling
content. A stack placed inside an outer scroll view scrolls with it. Existing
screen layout and safe-area ownership still apply. Leave bottom content spacing
so the floating button does not cover the last list item; leave both horizontal
edges or an explicit width when an extended button needs a particular bound.

Extended labels stay on one line and ellipsize within the available width.
Their full accessible label and tooltip remain available. This is an in-app
control; it does not create a system overlay or a separate Android task.

## Actions and lifecycle

Pressing the button dispatches its existing `MpAction` with a user gesture.
Action payload bindings resolve at execution time. The same action validation,
foreground requirements, and host-accepted capability policies continue to
apply. A button never grants a permission by itself.

Further presses on that button are ignored until its action completes, then
the button becomes available again, including after an action failure. A late
completion after disposal does not update the disposed widget. Individual
buttons do not serialize actions dispatched by other buttons or cancel actions
already handed to the runtime; each existing action owns its lifecycle.

Several buttons can coexist on a screen. SDK buttons disable Flutter's default
Hero tag to avoid duplicate-tag failures during navigation. They work in both
standard embedding and separate Android tasks and have no native task setup.

## Validation

Authoring tests check deterministic pure-Dart JSON, variants, disabled state,
accessibility text, icons, and colors. SDK tests validate both generated and
invalid JSON, render all variants, dispatch existing actions, verify live
bindings, disabled behavior, narrow layouts, scrolling, navigation with several
buttons, duplicate taps, and disposal during pending actions.

An Android API 36 emulator release build was checked in both standard embedding
and separate tasks. All variants dispatched their actions, disabled buttons
left state unchanged, the positioned button stayed fixed during scrolling, and
two native mini-program tasks retained independent state when switching back
through the host.
