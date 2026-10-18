# Android shop location and directions

Requires `mini_program_contracts >=0.3.17`, `mini_program_ui >=0.2.13`,
`mini_program_sdk >=0.6.15`, and `mini_program_tooling >=0.7.14`.
Install or update the CLI with `dart pub global activate mini_program_tooling`.

For local development, replace `miniprogram` in the commands below with
`dart run <checkout>/packages/mini_program_tooling/bin/miniprogram.dart` and
use local path dependencies or overrides for the matching SDK and contracts.

The flow is: open a shop mini-program, tap **Shop location** or **Get
directions**, use an installed supported map app, then press Back to resume
the existing mini-program. Both standard embedding and optional separate
Android tasks are supported. Opening maps does not replace or dispose the
mini-program. Process death, closing its task, or host eviction can still
lose in-memory state; publishers should persist important booking drafts
using accepted state cache or their Publisher API.

## Host setup

```powershell
# Choose standard embedding, or add --android-separate-tasks.
miniprogram embed init --project-root .
miniprogram host capability init maps --platform android --project-root .
flutter pub get
```

For an existing host, upgrade to SDK `^0.6.15` and contracts `^0.3.17`, then
refresh the scaffold with `embed init --force` when needed. The maps installer creates
`lib/mini_program/app_android_maps_provider.dart` and generated Kotlin under
`mini_program/generated/maps/`. It registers the adapter on each Flutter
engine, including separate mini-program tasks, through
`MiniProgramNativeSetup`. Reruns preserve host-owned Dart adapter edits;
unrecognized conflicts fail before writing host files.

No extra Android permissions, Gradle dependencies, embedded map SDK, or map
API key are added. The host does not request device location for this flow.
The external map app owns its own permissions, origin selection, routing,
network access and service availability.

Installing the adapter does **not** accept any mini-program permission. In
`lib/mini_program/mini_program_policies.json`, review the app's
`accepted.permissions`:

```json
{
  "maps": {
    "enabled": true,
    "allowOpenLocation": true,
    "allowDirections": true
  }
}
```

Regenerate endpoints and policy resolution through the normal host endpoint
import workflow. Missing maps policy defaults to disabled. Once enabled,
both operations default to allowed; hosts can independently deny either.

A publisher handoff may request `maps` with `enabled`, a 1–256 character
`reason`, `openLocation` and `directions`. The two operation flags default
to true. Requests are advisory. Normal import denies new requests and
preserves host decisions; explicit `--accept-requested-policy` accepts the
requested operations, and force import resets access to denied. Unknown
host-owned accepted fields are preserved.

Manual integrations pass a `MiniProgramMapsProvider` as `mapsProvider` in
`MiniProgramConfig`, then set `mapsPolicy` on each `MiniProgramEndpoint`.
Custom sources implement `MiniProgramMapsPolicyProvider`. Without that
interface the runtime denies maps. Installed providers advertise
`maps.open_location` and `maps.open_directions`; manifests can require them,
but declaring a capability cannot grant policy.

## Mini-program authoring

```dart
Mp.primaryButton(
  label: 'Shop location',
  action: Mp.maps.openLocation(
    latitude: 23.8103,
    longitude: 90.4125,
    name: 'Demo food shop',
    address: 'Dhaka',
    errorState: 'shop.map_error',
  ),
);

Mp.primaryButton(
  label: 'Get directions',
  action: Mp.maps.openDirections(
    latitude: '{{state.shop.latitude}}',
    longitude: '{{state.shop.longitude}}',
    name: '{{state.shop.name}}',
    coordinateSystem: MpMapCoordinateSystem.wgs84,
    mode: MpMapTravelMode.walking,
    targetState: 'shop.map_result',
    statusState: 'shop.map_status',
    errorState: 'shop.map_error',
  ),
);
```

The coordinates above are illustrative, not a real shop listing. Publishers
must supply their actual shop entrance coordinates. Latitude is first and
must be between -90 and 90; longitude between -180 and 180. Values must be
finite numbers. Full bindings must resolve to numbers, not numeric strings.
The name is required (1–120 UTF-16 code units); the optional address has a
512-unit limit. Control characters and unknown action properties are rejected.
Coordinates, name and address support full bindings. Coordinate system and
travel mode are explicit enums; arbitrary URLs, package names, Intents and
current-location requests are unavailable in these actions.

Both actions require an explicit user gesture, foreground visibility, an
active Flutter route, a host-installed provider and accepted policy. They
cannot open maps from initialization, timers or background mini-programs.
Directions supports `driving` (default) and `walking` and opens route planning,
not automatic journey completion. Map providers may prompt for an origin or
their own location permission.

Optional `targetState`, `statusState`, `errorState` and `requestId` work like
other device actions. Success returns only
`{"mapOpened":true,"operation":"location"}` or `"directions"`. It confirms
that Android accepted the launch, not that the user started navigation,
received a route, arrived, or came back. Status moves from `loading` to
`success` or `error`; failure preserves the previous target and stops an
action sequence. Async completions cannot write to a disposed or replaced
app/provider/policy. The expected pause caused by opening maps is not an error.

## Supported map apps and coordinate systems

The host-owned `AppAndroidMapsProvider.preferredApps` is an ordered list of
`AppAndroidMapApp.googleMaps`, `amap`, and `baiduMaps`. The adapter tries the
first compatible installed app in that order by default. A host can change
the order or allow only a subset. Mini-program JSON cannot change it.

Hosts serving China can prefer Amap or Baidu. Fallback occurs when Android
cannot launch a configured compatible app. The SDK cannot detect network or
route-calculation failures after the external app opens.

Known provider behavior from emulator testing: Google Maps 26.41 on Android
16 displayed driving mode after a walking request when location access was
denied and an origin was entered manually. The adapter sends the documented
`travelmode=walking` parameter; this does not guarantee the external app keeps
that selection. Users should confirm the travel mode in Maps. Do not present
`mapOpened` as confirmation that a walking route is ready. Recheck this case
with the provider versions used by the host's target devices.

| App | WGS84 | GCJ-02 | BD-09 | Pin | Directions |
| --- | --- | --- | --- | --- | --- |
| Google Maps | Yes | Rejected | Rejected | `geo:` with bounded label | Maps directions URL pinned to Maps package |
| Amap | `dev=1` | `dev=0` | Rejected | Native map marker | Native route planning |
| Baidu Maps | `coord_type=wgs84` | `coord_type=gcj02` | `coord_type=bd09ll` | Native marker | Native directions |

WGS84 is the authoring default. Set `gcj02` for coordinates supplied in that
format by Amap or another GCJ-02 source; set `bd09` for Baidu BD-09 coordinates.
The SDK does not guess or convert coordinates. Native adapters explicitly
tell the compatible provider which format was supplied, skipping incompatible
providers instead of silently changing the shop's position.

Only supported installed apps are launched. There is no browser fallback and
no fallback from directions to a pin. Disabled/unavailable providers are
skipped. Missing apps return `maps_unavailable`; a host app list with no
compatible coordinate system returns `maps_coordinate_system_unsupported`.
Other stable errors are `maps_not_accepted`, `maps_user_gesture_required`,
`maps_foreground_required`, `maps_invalid_request`, `maps_operation_failed`
and `maps_request_cancelled`. Error state does not expose native exceptions,
paths, Intent URLs or installed-package inventories.

The native caller keeps its Activity and does not set task-clearing flags.
Back behavior inside each provider remains provider-owned and may take more
than one press to leave its route screens. Device process reclamation still
applies. Embedded interactive maps, location picking, geocoding, nearby-shop
search, arbitrary map links and additional travel modes are future work.

## Validation coverage and deployment checks

Automated tests cover contracts, authoring, strict runtime validation, policy,
state ownership, native URI generation, and host regeneration. Emulator tests
with the real Google Maps app confirmed shop pins, driving directions and Back
with retained booking state. Walking mode has the limitation described above.
Amap/Baidu protocol parameters and fallback were tested with native Intent
handlers; real Amap/Baidu route calculation has not yet been validated.

Test shop pins and both travel modes in the real supported map apps, with the
publisher's actual coordinate system. Confirm the destination position and
mode rather than only checking that Android accepted an Intent. Native Intent
test handlers can verify encoding and fallback behavior but cannot verify a
provider's coordinate conversion, search results or route calculation.

Check Back with a filled booking form and a host draft in both embedding modes.
Also exercise missing/disabled map apps, denied operation policy, invalid bound
coordinates, and process recreation on physical Android devices. In-memory
retention applies while the host process and mini-program session remain alive.

## Protocol references

- [Android common map intents](https://developer.android.com/guide/components/intents-common#Maps)
- [Google Maps Android intents](https://developer.android.com/guide/components/google-maps-intents)
- [Google Maps directions URLs](https://developers.google.com/maps/documentation/urls/get-started)
- [Amap native markers](https://lbs.amap.com/api/amap-mobile/guide/android/marker)
- [Amap native route planning](https://lbs.amap.com/api/amap-mobile/guide/android/route)
- [Baidu Android URI API](https://lbsyun.baidu.com/docs/webapi?title=mapadjustment/uri/andriod)
