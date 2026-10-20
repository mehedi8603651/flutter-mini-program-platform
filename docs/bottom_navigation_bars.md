# Bottom navigation bars

`Mp.bottomNavigationBar` is a standalone pure-Dart builder for everyday section
navigation. The SDK validates its JSON and renders Flutter's Material 3
`NavigationBar`. Requires UI `0.3.1` and SDK `0.7.1`; tooling `0.7.19` generates
these dependencies. Contracts remain `0.3.18`. No new package, permission,
native bridge, page parameter, or host configuration is required.

## A shop with two sections

Place the bar below expanded content. Each item's existing action controls the
selected index and content. State-bound field values survive section unmounting.

```dart
import 'package:mini_program_ui/mini_program_ui.dart';

MpNode buildShopHome() => Mp.page(
  child: Mp.initialize(
    actions: [
      Mp.state.setDefault('shop.tab', 0),
      Mp.state.setDefault('shop.showHome', true),
    ],
    child: Mp.column(
      children: [
        Mp.appBar(title: Mp.text('My shop')),
        Mp.expanded(
          child: Mp.condition(
            condition: '{{state.shop.showHome}}',
            whenTrue: Mp.scrollView(
              child: Mp.column(
                children: [
                  Mp.heading('Home'),
                  Mp.stateTextField(
                    stateKey: 'draft.booking',
                    label: 'Booking information',
                  ),
                ],
              ),
            ),
            whenFalse: Mp.scrollView(
              child: Mp.column(
                children: [
                  Mp.heading('Orders'),
                  Mp.stateTextField(
                    stateKey: 'draft.orders',
                    label: 'Order note',
                  ),
                ],
              ),
            ),
          ),
        ),
        Mp.bottomNavigationBar(
          selectedIndex: '{{state.shop.tab}}',
          items: [
            MpBottomNavigationItem(
              icon: 'home',
              label: 'Home',
              action: Mp.state.patch({
                'shop.tab': 0,
                'shop.showHome': true,
              }),
            ),
            MpBottomNavigationItem(
              icon: 'history',
              label: 'Orders',
              action: Mp.state.patch({
                'shop.tab': 1,
                'shop.showHome': false,
              }),
            ),
          ],
        ),
      ],
    ),
  ),
);
```

Register this screen with `MpProgram` and build its artifact normally. When the
mini-program owns its header, the host's existing `showAppBar: false` launch
option avoids displaying a second header; see [app bars](app_bars.md).

## Selection, actions, and state

- `items` requires 2–5 `MpBottomNavigationItem`s, each with `icon`, `label`, and
  an existing `MpAction`. `selectedIcon` is optional; `enabled` defaults to true.
- `selectedIndex` defaults to literal `0`. A literal must be an integer in the
  item range. A full binding such as `{{state.shop.tab}}` is also supported.
- The bar automatically watches only the state paths referenced by selection
  and labels. No surrounding `Mp.stateBuilder` is needed for those state bindings.
  Other binding sources follow their existing rebuild behavior.
- Missing, non-integer, negative, or out-of-range runtime selection displays
  item zero. It never repairs or overwrites state. Integer-valued doubles and
  numeric strings are not indices.
- Tapping an enabled item, including the selected item, runs its action with
  the existing user-gesture and host-policy checks. Selection changes only when
  the supplied literal/binding changes. The bar does not create routes, write
  state, or mount section content automatically.
- While an action is pending, the bar suppresses further taps. Disabled items
  never dispatch actions. Finishing after disposal does not update a dead widget.

Use distinct state keys for section drafts, cart data, filters, and booking data.
The bar does not retain entire pages, scroll positions, focus, or nested routes.
Content retention follows the existing layout/state/navigation APIs; clearing
state or disposing its owning mini-program still follows host policy. This
widget does not change Android task behavior or system Back.

## Styling, layout, and accessibility

| Property | Default | Allowed values |
| --- | --- | --- |
| `labelBehavior` | `alwaysShow` | `alwaysShow`, `onlyShowSelected`, `alwaysHide` |
| `height` | `80` | Finite literal 64–128 logical pixels |
| `elevation` | `0` | Finite literal 0–24 |
| `backgroundColor` | Host navigation-bar theme | Literal `#RRGGBB` or `#AARRGGBB` |
| `indicatorColor` | Host navigation-bar theme | Literal `#RRGGBB` or `#AARRGGBB` |
| `selectedItemColor` | Host navigation-bar theme | Selected icon and label color |
| `unselectedItemColor` | Host navigation-bar theme | Unselected icon and label color |

All four colors use the same hex formats. Existing host theme and disabled-state
styling are preserved when no override is supplied. The SDK uses Material's
navigation component and respects the host's theme choice.

Icons use the existing supported icon names and cannot be bindings. Labels
support safe text bindings; authored labels are non-empty and at most 512
characters. Long labels use a single line with ellipsis; full labels remain
available to accessibility and Material tooltips even when visible labels are
hidden. Material provides selection semantics, keyboard interaction, and its
built-in text scaling behavior.

The surrounding `Mp.page` or `Mp.safeArea` owns system insets. The bar adds no
second status/navigation inset. Keep it outside the scrolling content for a
fixed bottom position. Normal layouts distribute items evenly. When there is
less than 64 logical pixels per item, the destinations scroll horizontally
instead of shrinking their touch areas. RTL follows the host text direction.
