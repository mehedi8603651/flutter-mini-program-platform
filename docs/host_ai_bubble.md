# Host-owned AI bubble

The reference host has one optional floating assistant across its host catalog
and foreground mini-program tasks. The host owns its
appearance, text panel, runner, model connection and credentials. Mini-programs
continue to use their ordinary pure-Dart widgets and actions.

The reusable presentation helper is
`hosts/mp_only_host/lib/phone_ai/host_ai_bubble.dart`. It has no SDK or AI-provider
imports. It is host example source, not an exported SDK widget or an `Mp` node.
Hosts can adopt it or build their own UI around the existing interaction controller.

Other Android hosts can now install the provider-neutral generated version with
`embed init --android-separate-tasks --ai-assistant`. It includes shared session
transport, presentation, an AI-service adapter and explicit host action wrappers.
See [host AI assistant setup](host_ai_assistant_setup.md). The personal reference
host below still keeps its separate test-model implementation.

## Behavior

- Drag the circle to move it; releasing docks it at the nearer horizontal edge.
- Tap it to open the text-goal panel. The panel shows the current result, recent
  actions and reported usage.
- **Minimize**, system Back or dismissing the panel keeps the edited goal draft.
- **Start AI** or **Continue AI** dismisses the panel before reading the screen.
  The assistant waits for actual route removal, including its dismissal animation.
- While running, a button with a stop icon and visible **Stop** text remains beside the circle, including
  above mini-program dialogs, drawers and sheets. Moving the circle does not stop
  a run. Opening its panel pauses it before the panel can cover the observed UI.
- Paused, blocked, failed and input-waiting tasks also keep **Stop AI** available.
  Stop ends the task and cancels outstanding model work. The panel has a matching
  **Cancel task** button. Changes already applied remain on screen and the draft
  goal stays editable; a later **Start AI** begins a fresh task.
- A short visible label distinguishes working, done, paused, input-needed,
  failed and cancelled states. Tap the circle or label for the full explanation.
- The panel's close button returns to the mini-program. The task toolbar's
  **Back** arrow follows the same SDK screen/popup navigation as Android Back,
  then returns to the host at the root. Its **Return to host** action switches
  directly to the host. The controls demo also pins **Back to preferences** above
  its independently scrolling catalog.
- Continue always reads the current screen again. No action is replayed automatically.
- Manual host/mini-program input, leaving the foreground or replacing the session owner
  interrupts the runner. Replacing the owner also removes its exact goal-panel route.

The bubble uses a Flutter overlay inside each host-owned Activity. The shared
session uses a small process-local native relay in the reference host; it needs
no Android overlay permission or extra package. It leaves the Navigator's
constraints and identity intact, so opening the assistant or changing its status
does not shift the mini-program, reset its controls or discard in-memory state.
Safe areas, the keyboard and viewport changes reposition only the floating controls.
The circle and Stop button expose accessibility labels; custom accessibility
actions can move the circle without dragging. Stop has an explicit semantic
container and tap action so it remains accessible above modal routes.

## Customize in the host

The personal reference build composes the bubble with `PhoneAiTestWorkspace`:

```dart
builder: (context, child) => PhoneAiTestWorkspace(
  appId: appId,
  dispatch: interactionChannel.dispatch,
  session: taskSessionClient, // HostAiSessionClient in a separate task.
  navigatorKey: navigatorKey,
  bubbleStyle: const HostAiBubbleStyle(
    label: 'My assistant',
    icon: Icon(Icons.smart_toy_outlined), // Or the host's own logo widget.
    diameter: 56, // 48–88 logical pixels.
    edgeMargin: 12,
    initialAlignment: Alignment.centerRight,
    backgroundColor: Color(0xFF006B5E),
    foregroundColor: Colors.white,
  ),
  onBubbleDocked: (alignment) {
    // Optionally persist this normalized position in host preferences.
  },
  child: child!,
),
```

`initialAlignment` is used when the bubble mounts; subsequent rebuilds preserve
the user's position. Omitted colors follow the host theme. `initialGoal`,
`modelFactory` and `limits` can also be injected into the reference workspace.
`HostAiBubble` itself accepts `visible`, `status`, `statusLabel`, `running`,
`canStop`, `badge`, `onPressed` and `onStop`, so a host can connect it to a different
assistant panel and service. `canStop` keeps a paused task's Stop control visible.
Only the floating controls intercept input; the rest of the host stays usable.

## Super-app and separate-task ownership

The reference host uses one `HostAiCoordinator` and one `PhoneAiRunner` in its
main Flutter engine. Each mini-program task mounts a `HostAiSessionClient` and
the same bubble presentation. Android's host-local `HostAiSessionRelay` routes
controls to that owner and broadcasts bounded status, the editable draft and
recent progress. Task clients create no model clients. Cancelling in any visible
task cancels the same pending host model request and rejects late replies.

`HostAiCatalog` registers this reference host's visible catalog buttons and scroll
actions. A goal can start on the host, open Food Demo in a separate native task,
and continue through that mini-program's existing SDK interaction controller.
Only a successful trusted host launch authorizes the runner's next app/session;
unrelated session changes still pause it. A short focus-loss grace allows the
Android Activity handoff. No hidden screen is observed or operated during it.
Leaving the app pauses work; returning does not automatically restart it.

This catalog adapter is HOST source, separate from SDK semantics. A super-app
developer can register their own current Chat/Wallet/search controls with their
assistant service. The SDK does not inspect those host screens or manage their
business logic. Real nearby-shop discovery, orders and payment depend on the
host/publisher's own services. The bundled Food Demo is a local UI test fixture.

The session exists while the host process/engine lives. Process death starts
fresh. If Android restores only a mini-program task without the host owner, its
panel asks the user to return to the host once. No model work resumes silently.

Keep this overlay outside `MiniProgramHost`, `MiniProgramPage` and the SDK's owned
interaction surface. The bubble and goal panel must never become model targets.
The reference runner pauses before its panel opens and ignores stale panel results
after owner replacement. A Start requested during dismissal is cancelled if the
Activity leaves the foreground before that route is removed.

The ordinary reference build omits the personal AI UI and key. For the opted-in
phone-test APK, use `python tools/build_phone_ai_apk.py` as described in
[foreground AI interaction](foreground_ai_interaction.md). That helper deliberately
embeds the authorized personal test key; production hosts should use their own
authenticated server. Text input is implemented; voice remains deferred.

Start reads the text controller at tap time, so a quick Start after an edit does
not submit a stale value captured by the previous button build.

## Validation

On 2026-10-26, host analysis was clean and all 57 host tests passed. Coverage
includes layout/state preservation, docking, keyboard and rotation bounds,
branding, accessibility movement, observation isolation, goal drafts, exact route
cleanup, cancellation and foreground loss during panel dismissal.

The `1.0.0-ai-bubble+4` ARM64/x64 release APK also passed Android API 36 emulator
checks with direct HTTPS Luna decisions:

| Goal | Decisions | Reported tokens | Reported cost (USD) |
| --- | ---: | ---: | ---: |
| Two portions, `No onions`, open order review | 7 | 3,780 | 0.00049 |
| Green tea, Pickup, reusable cup, October 28, open preference review | 9 | 7,938 | 0.00104 |

The device checks exercised dragging during a run, edited-draft retention on
minimize, Stop/Continue, controls above a review dialog and switching native tasks.
Food retained both portions, its note and the bubble's docked position after a
visit to the host and Orders. The final Flutter error and Android crash logs were
empty. Screenshots were inspected. These are bounded fixture results; phone ROMs,
network access and model decisions still require testing on target devices.

On 2026-10-27, `1.0.0-ai-bubble-fix+5` passed all 63 host tests and host analysis.
Regressions cover a quick edit followed by Start, sequential goals, cancellation
of paused/blocked/input-waiting work, late replies after cancellation, readable
status labels, and toolbar navigation. The ARM64/x64 release APK passed API 36
emulator checks using direct Luna requests for two goals in the same mounted
Controls session: configure and review tea preferences, then close that review,
scroll the catalog and open item 18. No manual continuation was needed for either.

The same APK passed active Stop, manual takeover followed by paused Stop/panel
Cancel, retained goal drafts, fresh Start, toolbar Back, pinned catalog Back and
switching to the host and reopening the existing mini-program. State-backed
query/date values and the cancelled assistant status survived the task switch.
Final Flutter error and Android crash logs were empty; screenshots were inspected.
The emulator was closed after validation. The exact reason for the earlier Vivo
pause remains unconfirmed without its panel message; the new status label and
controls make that outcome visible and cancellable.

On 2026-10-27, the final `1.0.0-shared-ai+6` ARM64/x64 release APK passed all
68 host tests and analysis with fatal infos. Its API 36 emulator checks used
direct HTTPS Luna decisions and exercised one shared host-owned runner:

- Start a goal on the host and open Food Demo in its separate Android task.
- Stop from the mini-program, then return to the host and see the same cancelled
  status and retained goal draft.
- Restart from the host and complete the two-portion order review with `No onions`.
- Stop and restart a second goal, then review the same cart with `Less salt`.
- Pause on manual takeover and use Stop while paused.
- Leave the app and return without automatic resumption; retain two portions and
  `Less salt` in the cart.

The completed flows used six decisions / 3,604 reported tokens / USD 0.00046
and four decisions / 2,375 reported tokens / USD 0.00032, respectively. Android
reported distinct host and Food tasks. Final Flutter error and Android crash
logs were empty, and screenshots were inspected. APK inspection verified the
Internet permission, both ABIs, matching build sources, absent `.env` assets,
redacted build logs and removal of temporary define files. The authorized
personal test key is embedded only in the host's compiled application libraries.

The reviewed APK is `hosts/mp_only_host/build/app/outputs/flutter-apk/app-ai-test.apk`.
This new build still needs physical-device validation on the Vivo. The checks
cover the reference catalog and local fixtures; a super-app must register its
own host controls and integrate real discovery, ordering and payment services.
