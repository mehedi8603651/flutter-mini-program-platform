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
feature-owned node/action builders. The temporary legacy `src` compatibility
re-exports were removed in `0.2.0`; direct internal imports are unsupported.

## Floating action buttons

Standalone `Mp.floatingActionButton(...)`, `.small`, `.large`, and `.extended`
builders dispatch existing `MpAction`s. Position them with `Mp.stack` and
`Mp.positioned`. Icons, accessible labels, disabled state, and optional colors
are validated in pure Dart; no rendering framework dependency is added.
Requires SDK `0.6.17` or newer compatible versions. See the
[floating action button guide](https://github.com/mehedi8603651/flutter-mini-program-platform/blob/main/docs/floating_action_buttons.md).

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
  return Mp.page(
    child: Mp.column(
      children: <MpNode>[
        Mp.topBar(
          leading: Mp.icon('coupon', semanticLabel: 'Coupons'),
          title: Mp.heading('Coupon Center'),
          actions: <MpNode>[
            Mp.iconButton(
              'refresh',
              semanticLabel: 'Refresh coupons',
              action: Mp.backend.refresh(requestId: 'coupon-list'),
            ),
          ],
        ),
        Mp.expanded(
          child: Mp.scrollView(
            child: Mp.column(
              children: <MpNode>[
                Mp.text('Portable rewards for host apps.'),
                Mp.image(src: 'https://example.com/reward.png'),
                Mp.card(child: Mp.text('SDK-owned component styling')),
                Mp.primaryButton(
                  label: 'Open details',
                  action: Mp.navigation.openScreen('coupon_details'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
```

Use `Mp.page` for new full-screen mini-program screens. It owns the safe area
and avoids legacy outer scroll padding. Keep `Mp.topBar` outside the expanded
scrolling body so headers do not move or compress when the keyboard opens.

Configure responsive thresholds once at the screen root. Values are Flutter
logical pixels and may be adjusted for the mini-program's content:

```dart
Mp.page(
  breakpoints: const MpResponsiveBreakpoints(
    mediumMinWidth: 600,
    expandedMinWidth: 840,
  ),
  child: Mp.constrainedContent(
    maxWidth: 1200,
    child: Mp.responsive(
      compact: compactLayout,
      medium: tabletLayout,
      expanded: largeLayout,
    ),
  ),
);
```

Missing medium or expanded variants fall back toward the compact layout. For
collections that only need more columns, prefer one adaptive grid instead of
duplicating the complete screen:

```dart
Mp.grid(
  minItemWidth: 180,
  maxColumns: 4,
  spacing: 12,
  children: cards,
);
```

## Date and time selection

Use `Mp.dateTime.dateField`, `Mp.dateTime.timeField`, or
`Mp.dateTime.dateRangeField` with a `stateKey` and `label`. Optional initial
values use `YYYY-MM-DD`, `HH:mm`, or `{start, end}` dates. Fields integrate with
`Mp.form`, support required/disabled controls, and preserve selections on cancel.
Authoring stays pure Dart; the host SDK uses Flutter's built-in pickers.
See [date/time fields](https://github.com/mehedi8603651/flutter-mini-program-platform/blob/main/docs/date_time_selection_fields.md) for complete
examples, date bounds, form names, and state/lifecycle behavior.

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

## Local Text Editing

Use a state-bound field for local drafts and editors that are not submitted as
a backend form. The SDK keeps its controller synchronized with live state, and
the host's live-state limits still apply.

```dart
Mp.stateTextField(
  stateKey: 'note.body',
  hint: 'Enter text...',
  maxLength: 4096,
  minLines: 8,
  maxLines: 30,
  keyboardType: 'multiline',
  textInputAction: 'newline',
);
```

Wrap custom visual content with `Mp.tap` when it needs one semantic action
without adopting button presentation.

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

## Camera And Flashlight

Camera capture delegates to the Android system camera. Bounds are optional;
when omitted, the camera's native output size is retained. The host returns an
opaque media reference and metadata rather than a path, URI, or image bytes.

```dart
Mp.camera.capturePhoto(
  quality: 95,
  maxWidth: 1920,
  targetState: 'camera.photo',
  statusState: 'camera.status',
  errorState: 'camera.error',
);

Mp.camera.cancel(statusState: 'camera.status');

Mp.flashlight.toggle(
  targetState: 'flashlight.status',
  errorState: 'flashlight.error',
);
```

Camera and flashlight are separate host permissions. Camera does not provide a
live camera feed, video recording, or arbitrary camera access. A captured
photo can be rendered through the trusted host media provider without exposing
its path or bytes to mini-program state:

```dart
Mp.image(
  src: '{{state.camera.photo.mediaRef}}',
  source: MpImageSource.hostMedia,
  alt: 'Captured photo',
);
```

## QR Codes

QR generation is a cross-platform renderer node and requires no host
permission. Scanning requires a trusted host provider, accepted
`permissions.qrScanner` policy, and an explicit user gesture.

```dart
Mp.qr.generate(
  value: '{{state.share.url}}',
  size: 240,
  errorCorrection: 'medium',
  semanticLabel: 'Share link QR code',
);

Mp.button(
  text: 'Scan QR code',
  action: Mp.qr.scan(
    allowTorch: true,
    timeout: const Duration(seconds: 60),
    targetState: 'qr.result',
    statusState: 'qr.status',
    errorState: 'qr.error',
  ),
);
```

The scan target contains `rawValue`, `format`, `valueType`, and
`scannedAtUtc`. Treat `rawValue` as untrusted text. The runtime never opens a
scanned URL or performs another action automatically.

## System Sharing

System sharing must run from an explicit button or other user gesture. A host
must install a platform provider and accept `permissions.share` for the app.

```dart
Mp.button(
  text: 'Share note',
  action: Mp.share.open(
    title: 'Share note',
    text: '{{state.note.text}}',
    url: 'https://example.com/notes/42',
    mediaRefs: '{{state.note.mediaRefs}}',
    targetState: 'share.result',
    statusState: 'share.status',
    errorState: 'share.error',
  ),
);
```

`mediaRefs` are opaque temporary resources already owned by the mini-program,
such as delegated camera results. The result is
`{"chooserOpened": true}`; it does not indicate whether the user selected a
target or completed sharing. Native paths, content URIs, and raw bytes are
never accepted.

## Temporary Display Brightness

Use a lifecycle scope around content such as an on-screen QR code. The host
may deny or clamp the request and always owns restoration.

```dart
Mp.display.brightnessScope(
  level: 1,
  statusState: 'invite.brightness_status',
  errorState: 'invite.brightness_error',
  child: Mp.qr.generate(
    value: '{{state.invite.url}}',
    size: 240,
    semanticLabel: 'Friend invitation QR code',
  ),
);
```

Do not pair this node with a manual brightness-off action. The SDK releases
the override when the child unmounts or the host leaves the foreground.

## Streamed Audio And Inline Video

Media sources are either immutable artifact assets or relative Publisher API
routes. Arbitrary URLs and device files are rejected. Audio is headless;
video is rendered inline in the authored layout.

```dart
Mp.audio.play(
  audioId: 'answer-sound',
  source: MpAudioSource.publisher(endpoint: 'media/answer-sound'),
  cacheMode: 'temporary',
  statusState: 'audio.status',
  errorState: 'audio.error',
);

Mp.videoView(
  playerId: 'product-demo',
  source: MpVideoSource.asset('video/product-demo.mp4'),
  poster: 'images/product-poster.webp',
  controls: true,
  onReady: Mp.state.set('video.ready', true),
  onEnded: Mp.state.increment('video.completedCount'),
  onError: Mp.state.set('video.failed', true),
  semanticLabel: 'Product demonstration',
);
```

Use `Mp.audio.pause/seek/stop/setVolume/setSpeed/getStatus/release` and
`Mp.video.play/pause/seek/stop/setMuted/setVolume/setSpeed/enterFullscreen/
exitFullscreen/getStatus/release` for explicit controls. Temporary cache is
only a request; host-accepted media and cache policy remains authoritative.

## Publisher File Transfers

File actions use relative routes on the artifact-declared Publisher API. The
host must accept file policy and install a platform transfer provider. Files
are streamed by the host; mini-program state receives only progress and
sanitized result metadata.

```dart
Mp.file.upload(
  endpoint: 'files/upload',
  mimeTypes: const <String>['image/*', 'application/pdf'],
  mediaRefs: const <String>['{{state.camera.photo.mediaRef}}'],
  multiple: true,
  metadata: const <String, Object?>{'folderId': 'inbox'},
  progressState: 'files.progress',
  targetState: 'files.uploadResult',
  statusState: 'files.status',
  errorState: 'files.error',
);

Mp.file.download(
  endpoint: 'files/download',
  request: const <String, Object?>{'fileId': 'file-1'},
  destination: 'downloads',
  suggestedName: 'report.pdf',
  expectedMimeType: 'application/pdf',
  progressState: 'files.progress',
  targetState: 'files.downloadResult',
);

Mp.file.cancel(
  transferId: '{{state.files.progress.transferId}}',
  statusState: 'files.status',
);

Mp.media.release(
  mediaRef: '{{state.camera.photo.mediaRef}}',
  statusState: 'camera.status',
);
```

Upload and download are network operations, not aliases for local pick/save.
The publisher server owns file IDs, folders, ACLs, and business metadata.
When `mediaRefs` is empty, upload opens the platform document picker. When it
is present, the host streams already-owned temporary media. Release media only
after upload succeeds or when the user discards it; host lifecycle cleanup is
the final fallback.

## Security Model

`mini_program_ui` only serializes declarative JSON. It does not execute host
code and it does not contain renderer logic. Runtime validation,
auth sessions, runtime API headers, and bridge dispatch are owned by
`mini_program_sdk`.

## Gallery photo selection

`Mp.gallery.pickImages(targetState: 'photos', maxImages: 3)` opens a
host-installed native photo picker after a user gesture. Optional
`statusState` and `errorState` bindings report progress. Cancellation keeps the
previous selection; `Mp.gallery.cancel()` logically cancels an active request.
Use `Mp.image(source: MpImageSource.hostMedia, src: '{{state.photos.images.0.mediaRef}}')`
inside `Mp.stateBuilder(keys: const ['photos'], child: ...)` for a reactive
preview, and `Mp.media.release` when finished. File upload and system sharing
independently require host acceptance. See the
[Android gallery guide](https://github.com/mehedi8603651/flutter-mini-program-platform/blob/main/docs/android_gallery_photo_picker.md).

## Microphone voice notes

Use `Mp.microphone.record(targetState: 'voice.note', statusState: 'voice.status')`
from a user gesture. A separate `Mp.microphone.stop()` finalizes the pending
record action; `Mp.microphone.cancel()` discards partial audio and preserves the
previous target. Use `MpAudioSource.hostMedia('{{state.voice.note.mediaRef}}')`
for accepted audio playback and `Mp.media.release` for cleanup. See the
[Android microphone guide](https://github.com/mehedi8603651/flutter-mini-program-platform/blob/main/docs/android_microphone_recording.md).

## Clipboard, vibration and phone dialer

Use `Mp.clipboard.writeText(text: 'booking code')` and
`Mp.clipboard.readText(targetState: 'paste')` for explicit plain-text copy/paste,
`Mp.vibration.trigger(effect: MpVibrationEffect.success)` for short system
haptics, and `Mp.phone.openDialer(number: '+15550101234')` to open a
user-controlled dialer. These actions require a user gesture, foreground
visibility, a host provider and accepted policy. Clipboard reads require
separate acceptance. See [Android setup and limits](https://github.com/mehedi8603651/flutter-mini-program-platform/blob/main/docs/android_clipboard_vibration_phone.md).


## Shop location and directions

`Mp.maps.openLocation` displays a known shop; `Mp.maps.openDirections` opens driving or walking route planning in a host-approved external map app. See the [Android shop location guide](https://github.com/mehedi8603651/flutter-mini-program-platform/blob/main/docs/android_shop_location_directions.md) for setup, host acceptance, coordinate systems and provider limits.
