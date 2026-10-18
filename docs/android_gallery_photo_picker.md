# Android gallery photo picker

Requires contracts **0.3.14**, UI **0.2.10**, SDK **0.6.12**, and tooling
**0.7.11** or later in their compatible release lines.

This optional capability selects **photos** using Android's native Photo
Picker. AndroidX uses an available system or backported picker and falls back
to the document picker on older devices. No broad photo-library or storage
permission is needed. A host without the adapter continues to work; a gallery
action returns `gallery_unavailable` when accepted but not installed.

## Host installation

Update existing host dependencies to SDK `^0.6.12` and contracts `^0.3.14`,
then install the adapter:

```powershell
dart pub global activate mini_program_tooling 0.7.11
miniprogram embed init --project-root .
miniprogram host capability init gallery --platform android --project-root .
flutter pub get
```

For an existing embedding, run the capability command directly. Use
`embed init --force` only when you intend to refresh scaffold-managed files.
For separate Android tasks, opt in with
`embed init --project-root . --android-separate-tasks`; gallery installation
works before or after task setup. Each task engine uses its own generated
host configuration. The native selection guard is shared across engines.

Installation creates `app_android_gallery_provider.dart`, the Kotlin gallery
channel, a private FileProvider/cache path, and shared native registrations
and AndroidX dependencies. It upgrades a supported Kotlin `MainActivity` to
`FlutterFragmentActivity` and preserves host code. The Dart provider is
host-owned after creation. Conflicts fail before any files are changed.

**Installation does not accept any mini-program permission.** Review the
app's accepted `permissions.gallery` in `mini_program_policies.json`, then
regenerate endpoint policies with the normal endpoint-import workflow:

```json
{
  "enabled": true,
  "maxImages": 3,
  "maxImageBytes": 20971520,
  "maxTotalBytes": 52428800
}
```

For manual host composition, install a `MiniProgramGalleryProvider` in
`MiniProgramConfig.galleryProvider` and set the endpoint's `galleryPolicy`:

```dart
MiniProgramEndpoint.public(
  apiBaseUri: Uri.parse('https://static.example.com/photos/'),
  galleryPolicy: const MiniProgramGalleryPolicy(
    enabled: true,
    maxImages: 3,
    maxImageBytes: 20 * 1024 * 1024,
    maxTotalBytes: 50 * 1024 * 1024,
  ),
)
```

Register `CapabilityIds.galleryImages` and `CapabilityIds.mediaPreview` when
the provider is available. The generated setup does this automatically.
Gallery supplies media previews when no explicit media provider is supplied.
If you supply another media provider, it must resolve the same app-owned
gallery references; the generated Android file provider already uses the
shared native media registry.

## Mini-program authoring

Start selection from a button or another explicit user gesture:

```dart
Mp.primaryButton(
  label: 'Choose photos',
  action: Mp.gallery.pickImages(
    maxImages: 3,
    maxWidth: 2048,
    maxHeight: 2048,
    quality: 90,
    targetState: 'photos.selection',
    statusState: 'photos.status',
    errorState: 'photos.error',
  ),
)
```

On success, `photos.selection` contains a selection ID, UTC timestamp, and an
`images` list. Each image contains `mediaRef`, `fileName`, `mimeType`, `bytes`
(a byte count), `width`, `height`, and `source: gallery`. Native paths,
content URIs, original image metadata, and image bytes never enter state.

```dart
Mp.stateBuilder(
  keys: const ['photos.selection'],
  child: Mp.image(
    src: '{{state.photos.selection.images.0.mediaRef}}',
    source: MpImageSource.hostMedia,
    height: 180,
    fit: MpImageFit.contain,
  ),
)

Mp.file.upload(
  endpoint: 'photos/upload',
  mimeTypes: const ['image/jpeg'],
  mediaRefs: const ['{{state.photos.selection.images.0.mediaRef}}'],
  progressState: 'upload.progress',
  targetState: 'upload.result',
)

Mp.media.release(
  mediaRef: '{{state.photos.selection.images.0.mediaRef}}',
)
```

Uploads independently require the file adapter, accepted upload policy, and
an accepted artifact-declared Publisher API. Sharing independently requires
the share adapter and accepted sharing policy. Gallery selection grants
neither permission.

Publishers may include this request in partner handoff:

```json
{
  "requestedPermissions": {
    "gallery": {
      "enabled": true,
      "reason": "Choose photos to attach to the booking.",
      "recommendedMaxImages": 3,
      "recommendedMaxImageBytes": 20971520,
      "recommendedMaxTotalBytes": 52428800
    }
  }
}
```

The host accepts or denies this request. Requests never grant runtime
authority. Apps may declare `gallery.images` as required in their manifest
when the whole app depends on this capability.

## Behavior and limits

- Default policy denies selection. Enabled policy defaults to 9 images,
  20 MiB per image, and 50 MiB per selection. Policy limits may be 1–30 images,
  at most 100 MiB per image and 300 MiB total. The requested count is clamped
  by host policy and the Android picker's supported maximum.
- Requested width/height are 64–8192 pixels, quality is 1–100. Images preserve
  aspect ratio and are never enlarged. Decoding is sampled to bound memory;
  source EXIF orientation is applied and copies are encoded as JPEG without
  source EXIF/GPS. Transparency and animation are not preserved. Video and
  crop editing are outside this release.
- Byte limits apply to both selected input files and normalized output files.
  Selection is atomic: one unsupported or over-limit item fails the selection
  and releases all newly imported copies. Previous selections remain owned.
- `statusState` becomes `loading`, `success`, `cancelled`, or `error`.
  Cancellation preserves the previous `targetState` and clears the error.
  `Mp.gallery.cancel()` logically cancels a pending request; the user may
  still need to dismiss Android's picker. Only one picker may be open per
  host process across its engines.
- Opening the system picker pauses the parent activity. This pause does not
  cancel selection. Successfully imported photos survive backgrounding and
  retained task switches. Explicit release, app changes, or mini-program
  disposal release owned resources; a late result is discarded and cleaned.
  Replacing a selection does not release older references automatically:
  release photos when they are no longer needed.
- References are temporary and app-scoped. Process death or cache removal can
  invalidate them. Persist business identifiers after upload instead of
  treating a media reference as durable storage. A later selection cleans
  orphaned gallery copies left by a previous process.

## Verification

Package tests cover serialization, unsafe JSON, denied policy, missing user
gestures, cancellation, state quota rollback, stale completion, ownership,
installer idempotence, and separate-task installation order. Device testing
should include single/multiple selection, Back cancellation, previews,
orientation, upload, sharing, explicit release, and switching between the
host and retained mini-program tasks. Picker UI and fallback availability
depend on the Android version and installed system components.

The 0.6.12 SDK / 0.7.11 tooling release was verified with a release APK on
an Android 16 (API 36) emulator. Single and multiple selection, Back
cancellation, EXIF orientation, previews, multipart uploads, the native share
chooser, and explicit release passed. The host's Chat draft and the first
mini-program's booking draft and selected photo survived switching between
the host and two retained mini-program tasks. Uploaded images had the expected
dimensions and no source EXIF metadata. Older-device document-picker fallback
was not exercised in that emulator run.
