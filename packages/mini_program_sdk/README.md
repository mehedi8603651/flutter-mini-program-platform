# mini_program_sdk

Flutter runtime SDK for rendering mini-program UI from static Mp JSON artifacts.

Host applications should use the supported package barrel:

```dart
import 'package:mini_program_sdk/mini_program_sdk.dart';
```

Version `0.6.0` promotes the feature-oriented runtime internals to the stable
baseline without changing public APIs, historical public import paths, or wire
formats.

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
