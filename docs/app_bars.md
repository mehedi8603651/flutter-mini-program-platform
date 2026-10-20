# Mini-program-owned app bars

`Mp.appBar(...)` is a standalone pure-Dart authoring builder. It serializes an
`appBar` node, and the existing Flutter host SDK renders a Material `AppBar`.
The mini-program developer owns its title, leading control, actions, and style.
There are no new dependencies, Android permissions, native bridges, or page API
parameters.

Requires UI `0.3.0`, SDK `0.7.0`, and tooling `0.7.18` for generated projects.
Contracts remain `0.3.18`.

## Authoring

```dart
import 'package:mini_program_ui/mini_program_ui.dart';

MpNode buildShopHome() => Mp.page(
  child: Mp.column(
    children: [
      Mp.appBar(
        title: Mp.text('My shop', maxLines: 1, overflow: 'ellipsis'),
        centerTitle: true,
        backgroundColor: '#123456',
        foregroundColor: '#FFFFFF',
        elevation: 2,
        actions: [
          Mp.iconButton(
            'search',
            semanticLabel: 'Search products',
            action: Mp.navigation.openScreen('shop_search'),
          ),
        ],
      ),
      Mp.expanded(
        child: Mp.scrollView(
          child: Mp.column(
            children: [
              Mp.heading('Products'),
              Mp.text('Your shop content'),
            ],
          ),
        ),
      ),
    ],
  ),
);
```

Register navigation destinations such as `shop_search` in the program as usual.
Title, leading and action slots accept supported `Mp` nodes, including custom
rows, logos, text fields, and buttons that fit the available toolbar space.
An app bar accepts at most four action widgets. It inserts no back or menu
control automatically. A detail screen can supply an explicit back control:

```dart
leading: Mp.iconButton(
  'arrowBack',
  semanticLabel: 'Back',
  action: Mp.navigation.popScreen(),
),
```

Use `Mp.stateBuilder` around state-dependent content for live title or badge
updates. Controls use existing `MpAction`s and their normal gesture, foreground,
and host-policy checks.

## Styling and layout

| Property | Default | Allowed values |
| --- | --- | --- |
| `centerTitle` | `false` | Literal boolean |
| `height` | `64` | 48–160 logical pixels |
| `leadingWidth` | `56` | 0–256 logical pixels; used when `leading` is supplied |
| `paddingHorizontal` | `12` | 0–48 logical pixels |
| `spacing` | `8` | 0–24 logical pixels between title/leading and between actions |
| `elevation` | `0` | 0–24 |
| `backgroundColor` | Host app-bar theme / surface | Literal `#RRGGBB` or `#AARRGGBB` |
| `foregroundColor` | Host app-bar theme / on-surface | Literal `#RRGGBB` or `#AARRGGBB` |
| `shadowColor` | Host app-bar theme / shadow | Literal `#RRGGBB` or `#AARRGGBB` |

Numeric values must be finite and literal. Uncolored text, `Mp.icon` and
`Mp.iconButton` use the toolbar foreground. Plain text also inherits the
toolbar text defaults. Explicit text properties, typography variants, and
explicit icon colors take priority. Styled buttons retain their own colors.
Outside app bars, existing text/icon defaults stay the same.

The bar owns its toolbar height. The surrounding page owns safe areas; the bar
does not add a second status-bar inset. Keep it outside the scrolling body to
remain fixed. A bar inside scrolling content scrolls with that content. The
existing `Mp.page` root is convenient for a bounded column and expanded body.

Leading width and insets are clamped to available width on narrow layouts. Long
action groups scroll horizontally within a bounded area so they do not push the
title outside the screen. Centering follows Material toolbar layout and respects
leading/action space and right-to-left direction. Choose suitable title content
and text overflow for the available width. Background color remains stable as
the body scrolls; toolbar styling does not change Android system status-bar
settings.

## Host setup and system Back

The optional host-provided outer app bar is controlled by the existing SDK
launch options. A host can configure its shared mini-program launch helper once:

```dart
await MiniProgramScope.of(context).openMiniProgram(
  appId: appId,
  options: const MiniProgramLaunchOptions(showAppBar: false),
);
```

This works with standard in-host navigation and generated separate Android
tasks. For direct embedding, use `MiniProgramPage(showAppBar: false, ...)`.
Avoid displaying both an outer host header and a mini-program-owned header.
There is no artifact inspection or host-specific header construction required.

Android system Back continues through the existing navigation/task integration.
The app-bar node neither intercepts it nor closes a mini-program itself. A
visible back button is optional and dispatches its supplied action.

## Replacement of the testing API

`Mp.topBar` and `topBar` JSON are removed completely. There is no deprecated
alias or legacy renderer. Update Dart authoring calls to `Mp.appBar`, rebuild
test artifacts, and rebuild hosts against SDK `0.7.0`. Previously published
version directories must remain immutable; put changed artifacts in a new
version or a disposable development output directory.

Authoring tests cover pure-Dart serialization, defaults, slots, styling, bounds,
and optional icon colors. SDK tests cover strict JSON rejection (including old
`topBar`), Material rendering, scoped styles, actions and live state, narrow
layouts, scrolling, RTL, and system Back without inferred host controls.

A release APK was also verified on an Android API 36 emulator with separate
mini-program tasks and ordinary in-host navigation. Checks covered toolbar
actions, typed booking data and host-draft retention, independent task state,
fixed headers during scrolling, and increased system text size.
