# mini_program_sdk

Flutter runtime SDK for rendering mini-program UI from static Mp JSON artifacts.

Host applications should use the supported package barrel:

```dart
import 'package:mini_program_sdk/mini_program_sdk.dart';
```

The `0.6.x` line uses feature-oriented runtime internals while preserving
public APIs, historical public import paths, and wire formats.

New screens can use a root `Mp.page` plus `Mp.topBar` to opt into explicit
safe-area ownership and stable fixed headers. Existing artifacts retain the
legacy outer padding and scrolling behavior.

`Mp.page` may also provide logical-pixel responsive breakpoints inherited by
`Mp.responsive` descendants. Selection uses each node's available layout
width, while `Mp.constrainedContent` and adaptive `Mp.grid` keep tablet,
foldable, landscape, and resizable-window layouts bounded without exposing
viewport dimensions through live state.

The SDK stays provider-neutral:

- artifact opening uses `MiniProgramEndpoint.public(apiBaseUri: artifactBaseUrl)`
- optional runtime data uses the artifact-owned `publisher_backend.json`
- provider SDKs, database clients, payment clients, secrets, and business rules stay outside the host app

## Static Opening

```dart
final config = MiniProgramConfig(
  source: EndpointRoutingMiniProgramSource(
    endpoints: {
      'coupon_demo': MiniProgramEndpoint.public(
        apiBaseUri: Uri.parse('https://static.example.com/coupon_demo/'),
      ),
    },
  ),
);
```

The host fetches manifest and screen/static artifact JSON from the artifact base URL. No runtime API URL is required to open the mini-program.

Artifact-local JSON resources are loaded through the optional
`MiniProgramJsonAssetSource` capability. `HttpMiniProgramSource` and
`EndpointRoutingMiniProgramSource` implement it for immutable files at
`artifacts/<appId>/<version>/assets/<path>`. Resources are constrained by the
host-accepted `data` cache policy and are never copied wholesale into live
state.

## Optional Runtime API

```json
{
  "schemaVersion": 1,
  "type": "mini_program_publisher_backend_contract",
  "contractVersion": "1",
  "appId": "coupon_demo",
  "backendBaseUrl": "https://publisher.example.com/api/coupon_demo/",
  "permissionReason": "Load current coupon offers.",
  "healthEndpoint": "health",
  "smokeTests": [
    {
      "id": "health",
      "method": "GET",
      "endpoint": "health",
      "expectedStatus": 200,
      "expectJsonObject": true
    }
  ]
}
```

Artifact tooling validates and packages this file. The generated endpoint sets
`publisherApiPolicy` from host-owned accepted policy. During loading, the SDK
reads the contract, checks that policy, and creates an app-scoped connector.
Denied calls fail with `publisher_api_disabled`.

Runtime APIs are used only by actions such as `Mp.backend.call`,
`Mp.backend.query`, `Mp.lazy.chunk`, search/load-more, and form submit.

## Host Rule

Opening a mini-program requires only `appId + artifactBaseUrl`. The publisher
owns the optional runtime API declaration; the host owns only permission to use
it.

## Android Native Mini-Program Windows

The current Android integration focuses on separate native windows: one host
task and one Activity/task for each opened mini-program. The reference
[`mp_only_host`](../../hosts/mp_only_host/README.md) uses this flow directly,
with five reusable mini-program slots. No presentation-mode build flag is
required. Reopening an app brings its existing task forward; Back and the
mini-program toolbar return to the host while retaining the mini-program.

Android Activity/task creation belongs to the host's Kotlin and manifest
integration. Importing the Dart SDK alone does not install native windows.
For generated host setup, run
`miniprogram embed init --project-root . --android-separate-tasks` and wire
`navigationDelegate: openMiniProgramInAndroidTask` on `MiniProgramScope`.
Plain `embed init` and the SDK's default navigation still open pages inside the
host. See [optional separate Android tasks](../../docs/android_separate_tasks_setup.md).
The SDK supplies rendering, app-scoped state, navigation, and capability
lifecycle handling inside each window. Existing `MiniProgramPage` embedding
and route-based APIs remain available.

`MiniProgramVisibility` remains an optional lifecycle signal for a host-owned
page. Marking a mounted page hidden pauses or releases foreground-only
resources without reloading its screen stack. Android lifecycle events also
suspend those resources when a native window enters the background. In-memory
state lasts while its Activity, Flutter engine, and process remain alive;
durable drafts need an explicit persistence policy.

Some OEM launchers filter separate Recent apps cards even when the tasks stay
alive. This was confirmed on the inspected Vivo S10 Pro launcher; no measured
worldwide affected-device percentage is established. See
[Android native windows compatibility](../../docs/android_native_windows_compatibility.md)
for device evidence and verification steps.

An SDK-provided scrollable in-app workspace and live transfer between native
and in-app presentation are deferred. Their requirements are recorded in the
[future one-window workspace design](../../docs/android_in_app_workspace_future.md).

## Optional Current Location

`location.getCurrent` is provider-neutral. A host opts in by accepting a
per-app `MiniProgramLocationPolicy`, installing a
`MiniProgramLocationProvider`, and advertising `CapabilityIds.locationCurrent`.
The SDK validates the host result and exposes only one approximate,
foreground, user-initiated snapshot to the requesting mini-program.

```dart
final config = MiniProgramConfig(
  source: source,
  locationProvider: appLocationProvider,
  capabilityRegistry: CapabilityRegistry(
    const <CapabilityId>{CapabilityIds.locationCurrent},
  ),
);
```

Missing providers and denied policy fail with stable location error codes;
they do not fall through to host bridge actions.

## Optional Camera And Flashlight

`camera.capturePhoto` delegates still-photo capture to a host
`MiniProgramCameraProvider`. The SDK enforces accepted camera policy, one
host-wide capture at a time, logical cancellation, opaque media references,
and temporary-media cleanup when the mini-program closes.

Captured media can be registered with `MiniProgramMediaManager`, rendered by
`hostMedia` images through a bounded trusted preview, supplied to file uploads
as opaque references, and released explicitly with `media.release`. Ownership
is checked again in both the SDK and native provider. Native paths, content
URIs, and raw bytes never enter live state.

Flashlight actions use `MiniProgramFlashlightProvider` under a separate
`MiniProgramFlashlightPolicy`. The manager prevents cross-app control and turns
the torch off when its owning mini-program closes. Neither capability exposes
camera identifiers, native paths, content URIs, or bytes to live state.

## Optional QR Scanning

`qrCode` nodes render locally on every supported Flutter platform. `qr.scan`
uses a host-installed `MiniProgramQrScannerProvider` and an accepted
`MiniProgramQrPolicy`; it is rejected unless dispatched from an explicit user
gesture. The manager permits one scanner session at a time and cancels it when
the mini-program closes.

Providers return `MiniProgramQrScanResult` as inert structured data. The SDK
validates its size, type, format, and UTC timestamp, but deliberately does not
open URLs, join Wi-Fi, add contacts, or execute any scanned content. Scanner
torch controls belong to the scanner session and are separate from
`MiniProgramFlashlightProvider`.

## Optional System Sharing

`share.open` invokes a host `MiniProgramShareProvider` only after an explicit
user gesture and accepted `MiniProgramSharePolicy`. The SDK validates bounded
text, one absolute HTTPS URL, and up to the accepted number of opaque media
references. Media ownership is revalidated against `MiniProgramMediaManager`
before the provider is called.

Providers return `MiniProgramShareResult(chooserOpened: true)` when platform
sharing UI opens. The SDK intentionally does not report share completion,
because Android's chooser does not provide a reliable completion result.
Native paths, content URIs, authorization data, and media bytes remain inside
the trusted host integration.

## Optional Publisher File Transfers

`file.upload`, `file.download`, and `file.cancel` use a separate streaming host
provider because the normal Publisher API connector is intentionally bounded
to JSON responses. The SDK still resolves only relative routes against the
validated artifact Publisher API and applies delivery and auth headers.

Hosts accept a per-app `MiniProgramFilePolicy` and install one
`MiniProgramFileTransferProvider`. Transfers are app-isolated, cancellable,
and constrained by accepted MIME types, destinations, concurrency, free-space
reserve, and an optional maximum file size. Live state contains only bounded
progress and sanitized result metadata; providers must never return native
paths or content URIs.

## Optional Media Playback

`MiniProgramMediaPlaybackProvider` supplies app-scoped foreground audio and
inline video sessions. The SDK resolves only artifact assets or relative
Publisher API routes, keeps URLs and authorization headers outside live state,
and releases every session when its mini-program closes.

Hosts decide audio and video independently through
`MiniProgramMediaPlaybackPolicy`. A `temporary` cache request also requires the
matching accepted audio/video cache policy. Providers receive app- and
kind-scoped byte and TTL limits. The generated Android Media3 adapter enforces
them with LRU range/HLS-segment cache directories, clears expired entries when
opening a cache, participates in audio focus, pauses when audio becomes noisy
or the host leaves the foreground, and supports native fullscreen video.
Permanent offline downloads and background playback are not part of this
release.

## Android gallery photos

Install optional native photo selection with
`miniprogram host capability init gallery --platform android`. Supply
`MiniProgramConfig.galleryProvider` and explicitly accept each app's
`MiniProgramEndpoint.galleryPolicy`. Generated adapters register capabilities
automatically; installation never accepts a mini-program permission.

Gallery metadata uses the existing opaque media registry for previews, uploads,
sharing, and release. Activity pauses and retained task switches keep selections;
app changes and disposal release owned copies. See the
[Android gallery guide](https://github.com/mehedi8603651/flutter-mini-program-platform/blob/main/docs/android_gallery_photo_picker.md).
