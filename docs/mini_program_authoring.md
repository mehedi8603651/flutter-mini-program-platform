# Mini-Program Authoring

New mini-programs should use the platform-owned Mp JSON engine. Authors write
pure Dart with `Mp.*` helpers, build deterministic JSON, validate it, then
preview or publish through the same provider-neutral delivery layout used by
legacy Stac mini-programs.

Legacy Stac projects remain supported during the migration. Use
`--screen-format stac` only when you intentionally need the old Stac path.

## Quick Start

Create a new Mp mini-program:

```powershell
cd D:\
miniprogram create first_miniprogram
cd first_miniprogram
miniprogram build
miniprogram validate
miniprogram preview -d chrome
```

The default scaffold writes:

- `manifest.json`
- `mp/program.dart`
- `mp/screens/<id>_home.dart`
- `tool/build_mp.dart`
- `pubspec.yaml`
- `assets/`

The manifest includes:

```json
{
  "screenFormat": "mp",
  "screenSchemaVersion": 1
}
```

Build output is generated under:

```text
mp/.build/screens/<screenId>.json
```

Do not edit `mp/.build` directly. Edit `mp/program.dart` and
`mp/screens/*.dart`, then run `miniprogram build`.

## Legacy Stac

Create a legacy Stac mini-program only when you are testing compatibility or
migrating an existing package:

```powershell
miniprogram create old_profile_flow --screen-format stac
```

Missing `screenFormat` is treated as legacy `stac` by contracts, tooling, and
the SDK.

## Mp Source Pattern

Register screens explicitly:

```dart
import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/coupon_details.dart';
import 'screens/coupon_home.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    'coupon_home': buildCouponHome,
    'coupon_details': buildCouponDetails,
  },
);
```

Author UI with platform components:

```dart
MpNode buildCouponHome() {
  return Mp.column(
    children: <MpNode>[
      Mp.heading('Coupon Center'),
      Mp.text('Portable rewards for every host app.'),
      Mp.card(
        child: Mp.text('Rendered by the SDK Mp renderer.'),
      ),
      Mp.primaryButton(
        label: 'Open details',
        action: Mp.navigation.openScreen('coupon_details'),
      ),
    ],
  );
}
```

The SDK owns the visual system. Authors should not write Material, Cupertino,
or host app widgets inside mini-program source.

## Auth

Use publisher-owned email auth through the SDK auth controller:

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

Tokens are never available through bindings. Use safe bindings such as
`{{auth.authenticated}}`, `{{auth.user.uid}}`, and `{{auth.user.email}}`.

## Backend Data

Use `Mp.backendBuilder` for one backend response:

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

Use `Mp.pagedBackendBuilder` for large lists with manual Load more:

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

Provider backends should return:

```json
{
  "items": [],
  "nextCursor": null,
  "hasMore": false
}
```

## Navigation

Prefer internal mini-program navigation for portable page-to-page flows:

```dart
Mp.primaryButton(
  label: 'Details',
  action: Mp.navigation.openScreen('coupon_details'),
);

Mp.secondaryButton(
  label: 'Back',
  action: Mp.navigation.popScreen(),
);
```

Native host screens should remain behind approved host bridge contracts. Do not
download Dart, JavaScript, or arbitrary expressions.

## Build, Validate, Publish

Normal flow:

```powershell
miniprogram build
miniprogram validate
miniprogram publish --target static --output public_mini_program --clean
```

Firebase static delivery:

```powershell
miniprogram publish --target firebase-hosting --env my-firebase-prod --clean
```

AWS/S3 delivery:

```powershell
miniprogram publish --target cloud --env my-aws-prod
```

All publish targets copy the same engine-neutral layout:

```text
manifests/<appId>/manifest.json
screens/<appId>/<version>/<screenId>.json
assets/<appId>/<version>/
metadata/
```

## Practical Guidance

- Keep the default `analytics` capability until the flow needs more.
- Add `auth` only when using `Mp.authBuilder` or auth actions.
- Use publisher backend routes for business data, not static screen JSON.
- Use paged backend lists for large collections.
- Keep images on HTTPS URLs or bundled assets.
- Use `workflow status --json` to confirm `screenFormat: mp`,
  `screenSchemaVersion: 1`, entry readiness, and backend/auth/paged usage.
