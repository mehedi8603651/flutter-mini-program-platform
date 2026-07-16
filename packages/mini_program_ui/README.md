# mini_program_ui

Pure-Dart authoring helpers for the Mp JSON mini-program engine.

This package intentionally has no Flutter, Stac, Material, Cupertino,
analyzer, or build_runner dependency. Mini-program authors write `Mp.*`
source, then `mini_program_tooling` runs `tool/build_mp.dart` and writes
versioned JSON for the SDK renderer.

## Supported Import

Mini-program source should use only the package barrel:

```dart
import 'package:mini_program_ui/mini_program_ui.dart';
```

Files below `lib/src/` are implementation details. The implementation is
organized into dependency-free core values, program assembly, and
feature-owned node/action builders. Legacy `src` paths remain as temporary
compatibility re-exports and are scheduled for removal in `0.2.0`.

## Program Shape

```dart
import 'package:mini_program_ui/mini_program_ui.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    'coupon_home': buildCouponHome,
    'coupon_details': buildCouponDetails,
  },
);
```

The build script is small and deterministic:

```dart
import 'package:mini_program_ui/mini_program_ui.dart';

import '../mp/program.dart';

Future<void> main(List<String> arguments) {
  return writeMpBuildOutput(miniProgram, arguments: arguments);
}
```

## Basic UI

```dart
MpNode buildCouponHome() {
  return Mp.column(
    children: <MpNode>[
      Mp.heading('Coupon Center'),
      Mp.text('Portable rewards for host apps.'),
      Mp.image(src: 'https://example.com/reward.png'),
      Mp.card(child: Mp.text('SDK-owned component styling')),
      Mp.primaryButton(
        label: 'Open details',
        action: Mp.navigation.openScreen('coupon_details'),
      ),
    ],
  );
}
```

## Auth

```dart
Mp.authBuilder(
  loading: Mp.text('Checking session...'),
  signedOut: Mp.card(
    child: Mp.column(
      children: <MpNode>[
        Mp.text('Sign in to continue.'),
        Mp.primaryButton(
          label: 'Sign in with email',
          action: Mp.auth.showEmailAuth(),
        ),
      ],
    ),
  ),
  signedIn: Mp.card(
    child: Mp.column(
      children: <MpNode>[
        Mp.text('Signed in as {{auth.user.email}}'),
        Mp.secondaryButton(label: 'Sign out', action: Mp.auth.signOut()),
      ],
    ),
  ),
  error: Mp.text('{{auth.message}}'),
);
```

Auth bindings never expose `idToken`, `refreshToken`, passwords, or backend
secrets.

## Backend Data

```dart
Mp.backendBuilder(
  requestId: 'home',
  endpoint: 'home/bootstrap',
  loading: Mp.text('Loading...'),
  error: Mp.text('{{backend.home.message}}'),
  child: Mp.card(
    child: Mp.column(
      children: <MpNode>[
        Mp.heading('{{backend.home.data.title}}'),
        Mp.text('{{backend.home.data.message}}'),
      ],
    ),
  ),
);
```

## Artifact-Local Data And Visualization

Large immutable lookup data can stay under the mini-program's `assets/`
directory. The runtime validates it, persists it only in the host-approved
`data` cache, and keeps search indexes outside live state.

```dart
Mp.initialize(
  actions: <MpAction>[
    Mp.data.loadJsonAsset(
      id: 'locations',
      asset: 'data/locations.json',
      statusState: 'location.resource_status',
      errorState: 'location.resource_error',
    ),
  ],
  child: Mp.column(
    children: <MpNode>[
      Mp.searchField(
        stateKey: 'location.query',
        hint: 'Dhaka',
        onChanged: Mp.data.search(
          resourceId: 'locations',
          query: '{{state.location.query}}',
          fields: const <String>['name', 'district'],
          itemsPath: 'locations',
          targetState: 'location.results',
        ),
      ),
      Mp.lineChart(
        source: '{{state.forecast.hourly}}',
        valueField: 'temperature',
        labelField: 'timeLabel',
      ),
    ],
  ),
);
```

JSON data paths are artifact-relative and cannot be remote URLs. Use
`direction: 'horizontal'` with an explicit `height` on `Mp.listView` or
`Mp.repeat` for horizontal collections. `Mp.refreshIndicator` is supported
only as a screen root.

## Paged Lists

Use `Mp.lazy.chunk` when repeated data is large, dynamic, comes from a
Publisher API, and needs pagination or manual Load more:

```dart
Mp.lazy.chunk(
  id: 'rewards_chunk',
  itemsState: 'rewards.items',
  cursorState: 'rewards.next_cursor',
  hasMoreState: 'rewards.has_more',
  statusState: 'rewards.status',
  cacheKeyPrefix: 'rewards_chunk',
  placeholder: Mp.text('Loading rewards...'),
  loadingMore: Mp.text('Loading more...'),
  empty: Mp.text('No rewards yet.'),
  end: Mp.text('No more rewards.'),
  error: Mp.text('Rewards failed to load.'),
  itemTemplate: Mp.card(child: Mp.text('{{item.title}}')),
  initialActions: <MpAction>[
    Mp.backend.loadMore(
      requestId: 'rewards',
      endpoint: 'coupons/page',
      limit: 20,
    ),
  ],
  loadMoreActions: <MpAction>[
    Mp.backend.loadMore(
      requestId: 'rewards',
      endpoint: 'coupons/page',
      limit: 20,
    ),
  ],
  loadMore: Mp.secondaryButton(
    label: 'Load more',
    action: Mp.lazy.loadMore(id: 'rewards_chunk'),
  ),
);
```

Do not use `Mp.lazy.chunk` for login pages, small settings pages, static about
pages, single detail pages, payment forms, fixed menus, or small local JSON
lists.

`Mp.pagedBackendBuilder` remains available for direct backend-bound paged
lists:

```dart
Mp.pagedBackendBuilder(
  requestId: 'rewards',
  endpoint: 'coupons/page',
  limit: 20,
  loading: Mp.text('Loading rewards...'),
  loadingMore: Mp.text('Loading more...'),
  empty: Mp.text('No rewards yet.'),
  end: Mp.text('No more rewards.'),
  error: Mp.text('{{backend.rewards.message}}'),
  itemTemplate: Mp.card(
    child: Mp.column(
      children: <MpNode>[
        Mp.heading('{{item.title}}'),
        Mp.text('{{item.description}}'),
      ],
    ),
  ),
  loadMore: Mp.secondaryButton(
    label: 'Load more',
    action: Mp.backend.loadMore(requestId: 'rewards'),
  ),
);
```

Default provider-neutral response shape:

```json
{
  "items": [],
  "nextCursor": null,
  "hasMore": false
}
```

## Navigation

```dart
Mp.primaryButton(
  label: 'Open details',
  action: Mp.navigation.openScreen('coupon_details'),
);

Mp.secondaryButton(
  label: 'Back',
  action: Mp.navigation.popScreen(),
);
```

## Control Flow And Timers

Conditions are strict booleans or full bindings. Countdown state contains the
remaining whole seconds, rounded up.

```dart
Mp.timer.countdown(
  duration: const Duration(seconds: 10),
  running: '{{state.screen.running}}',
  restartToken: '{{state.screen.content_id}}',
  remainingState: 'screen.remaining_seconds',
  onComplete: Mp.action.ifElse(
    condition: '{{state.screen.can_advance}}',
    thenAction: Mp.state.set('screen.status', 'advanced'),
    elseAction: Mp.state.set('screen.status', 'expired'),
  ),
  child: Mp.condition(
    condition: '{{state.screen.ready}}',
    whenTrue: Mp.text('{{state.screen.remaining_seconds}} seconds'),
    whenFalse: Mp.text('Waiting'),
  ),
);
```

Setting `running` to false pauses the countdown. Changing `restartToken`
resets it to the configured duration. Timers are cancelled when their node is
disposed.

## Current Location

Mini-programs can request one foreground, approximate location through a host
provider. The host must separately accept the request and install the native
provider.

```dart
Mp.location.getCurrent(
  accuracy: 'approximate',
  timeout: const Duration(seconds: 10),
  targetState: 'location.current',
  statusState: 'location.status',
  errorState: 'location.error',
  requestId: 'current-location',
);
```

This API does not support background tracking, continuous updates, or precise
location.

## Security Model

`mini_program_ui` only serializes declarative JSON. It does not execute host
code and it does not contain renderer logic. Runtime validation,
auth sessions, runtime API headers, and bridge dispatch are owned by
`mini_program_sdk`.
