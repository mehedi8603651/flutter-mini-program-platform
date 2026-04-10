# Mini-Program Authoring

This repo currently supports **developer-authored** and **partner-authored**
mini-programs. Authors create a repo-backed package under `mini_programs/`,
write portable UI in Stac DSL, validate it, then publish the generated JSON
into the local backend sample.

## Quick start

Generate a new scaffold anywhere:

```powershell
cd D:\
miniprogram create first_miniprogram
```

Optional scaffold inputs:

```powershell
miniprogram create claim_center `
  --title "Claim Center" `
  --description "Portable claim intake starter flow." `
  --capabilities analytics,secure_api `
  --force
```

The scaffold creates:

- `mini_programs/<id>/manifest.json`
- `mini_programs/<id>/README.md`
- `mini_programs/<id>/pubspec.yaml`
- `mini_programs/<id>/lib/default_stac_options.dart`
- `mini_programs/<id>/lib/host_action_helpers.dart`
- `mini_programs/<id>/stac/screens/<id>_home.dart`
- `mini_programs/<id>/stac/screens/<id>_details.dart`
- `mini_programs/<id>/stac/components/`
- `mini_programs/<id>/stac/theme/`
- `mini_programs/<id>/assets/`

## Authoring rules

- Write portable UI in `stac/screens/` and `stac/components/`.
- Do not author normal host Flutter pages for mini-program UI.
- Use the generated `lib/host_action_helpers.dart` wrappers instead of hand-writing raw `StacAction(jsonData: ...)` maps when possible.
- Keep native work behind approved `hostAction` payloads.
- Only use declared manifest capabilities.
- Replace starter demo route aliases and secure endpoints before shipping.
- Prefer internal mini-program routing by `screenId` for portable page-to-page flows.

Current scaffold behavior:

- `Continue to second screen` uses internal mini-program routing through `openMiniProgramScreenAction(...)`
- `Track starter event (logs only)` writes to the host analytics log only
- `Back to first screen` uses internal mini-program routing through `popMiniProgramScreenAction(...)`
- `Open sample native screen` stays available for real host-owned pages and uses the shared demo route alias `profile_editor`
- the sample native route works in both current hosts, but it is only a starter demo and should be replaced in real flows
- the generated helper wrappers still serialize the same JSON shape for backend delivery; authors just no longer need to hand-write it

## Current supported capability values

- `auth`
- `analytics`
- `secure_api`
- `native_navigation`

The scaffold only accepts these current contract wire values.

## Starter action helper style

The scaffolded screen now uses helper functions instead of raw action maps:

```dart
StacFilledButton(
  onPressed: openMiniProgramScreenAction(
    requestId: 'coupon_center-open-details',
    screenId: 'coupon_center_details',
  ),
  child: StacText(data: 'Continue to second screen'),
)
```

The second generated screen includes:

- `popMiniProgramScreenAction(...)` for portable back navigation
- `hostOpenNativeScreenAction(...)` only when the scaffold requested `native_navigation`
- `hostCallSecureApiAction(...)` only when the scaffold requested `secure_api`

Current internal routing helper set:

- `openMiniProgramScreenAction(...)`
- `replaceMiniProgramScreenAction(...)`
- `popMiniProgramScreenAction(...)`
- `resetMiniProgramStackAction(...)`
- `popToMiniProgramRootAction(...)`
- `popToMiniProgramScreenAction(...)`

Those helpers still compile down to serializable JSON actions when you run the
Stac build step.

## Build

Preferred standalone local flow:

```powershell
miniprogram doctor
miniprogram backend init
miniprogram env init
miniprogram build <id>
```

Expected screen output:

```text
stac/.build/screens/<id>_home.json
```

Build resolution order:

1. explicit `-StacCliScript`
2. managed pinned Stac builder bundled inside `mini_program_tooling`
3. vendored `stac-dev/packages/stac_cli/bin/stac_cli.dart`
4. global `stac` command

Standalone external-developer flow should normally rely on the managed pinned
Stac builder. If you need to point at a specific CLI script:

```powershell
miniprogram build <id> --stac-cli-script D:\path\to\bin\stac_cli.dart
```

## Validate

Run validation before publish:

```powershell
miniprogram validate <id>
```

## Publish the local backend sample

Preferred command:

```powershell
miniprogram publish <id>
```

This command:

1. builds the mini-program
2. runs pre-publish validation
3. copies manifest and screens into the initialized local backend workspace
4. runs post-publish validation

## Test in a host

For a local proof:

1. Publish the new mini-program into the initialized local backend workspace.
2. Run `miniprogram backend start --port 8080`.
3. Run a Flutter host app.
3. Open the generated entry screen and verify:
   - first screen -> second screen internal routing
   - back to first screen internal routing
   - any declared host capability path such as analytics or native navigation

## Practical guidance

- Use `analytics,native_navigation` for a low-risk starter flow.
- Use `secure_api` only when the flow truly needs a host-owned secure endpoint.
- If the mini-program depends on `secure_api`, keep caching conservative.
- Prefer page-to-page portable routing first, and only leave the mini-program
  through `openNativeScreen` when the flow genuinely needs a host-owned page.
- Add reusable components after the entry screen, second screen, and backend
  publish path are working.
