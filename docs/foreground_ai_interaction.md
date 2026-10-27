# Foreground AI interaction

The host can opt into a provider-neutral controller that observes and operates
the **current rendered mini-program screen**. Existing pure-Dart mini-programs
need no AI descriptions, action catalog, Flutter imports, or provider dependency.
The host or mini-program developer's server owns the model, goal, API key,
authorization, decision loop, cancellation, and spending limits.

Requires contracts `0.3.21`, SDK `0.7.4`, and tooling `0.7.22` or newer compatible
versions for generated Android task routing.

For automatic installation of a shared host-owned assistant bubble, controls,
and model adapter across the host and Android tasks, see
[optional host AI assistant setup](host_ai_assistant_setup.md). The controller
below also supports hosts building their own assistant UI.

## Embedded host setup

Create one host-owned controller and pass it to `MiniProgramConfig`, or directly
to `MiniProgramHost` when using that widget. Dispose it with its host owner.

```dart
final interactions = MiniProgramInteractionController();

final config = MiniProgramConfig(
  sdkVersion: '1.0.0',
  source: source,
  hostBridge: bridge,
  capabilityRegistry: capabilities,
  interactionController: interactions,
);

final snapshot = await interactions.observe();
// Send snapshot.toJson() and the user's goal to your own authenticated server.
// The server returns ONE UI decision from the snapshot's allowed actions.
final result = await interactions.interact(MiniProgramInteractionRequest(
  requestId: 'unique-request-1',
  sessionId: snapshot.sessionId,
  revision: snapshot.revision,
  targetId: chosenNode.id,
  action: MiniProgramInteractionAction.tap,
));
// Replace the previous screen details with result.snapshot.toJson().
```

`handleRequest` offers a strict JSON transport boundary for host-owned code:

```json
{"method":"observe"}
```

```json
{"method":"interact","request":{"requestId":"r1","sessionId":"observed-session","revision":3,"action":"enterText","targetId":"n42","text":"No onions"}}
```

Only the host installs a transport. The SDK starts no server and provides no
network endpoint to mini-program artifacts. Authenticate your server and send
only the snapshot needed for the active user task. Visible screen text is
untrusted model input, not authority to change the user's goal.

## Automatic screen metadata and UI operations

The controller reads Flutter's live semantics tree inside an owned mini-program
boundary, including SDK drawers, sheets, dialogs, dropdowns, and date/time pickers.
Labels, resolved text, editable values, roles, enabled/checked/selected state,
parent IDs, and allowed UI operations describe what is rendered now.

Supported operations are `tap`, `enterText`, `scrollUp`, `scrollDown`,
`scrollLeft`, `scrollRight`, `increase`, `decrease`, and `back`.
Choose a dropdown option or calendar date by tapping its currently visible node.
Scrolling moves the content in the named direction: `scrollUp` reveals lower rows.
Text entry replaces the field's text through its normal editing callback and
formatters. Validation, form submission, navigation, and Publisher API work use
the existing UI handlers. No raw `MpAction` execution or arbitrary state write
endpoint is exposed.

Host screens, hidden/offscreen semantic nodes, raw state, action payloads,
backend configuration, native platform-view internals, and password values are
excluded. Protected fields offer no AI editing operation. Metadata is bounded
to 160 nodes, about 28 KB of node JSON, and 512 characters per text field;
`truncated: true` indicates incomplete details. Request text is limited to 4096
characters and transport envelopes to 20 KB. Scroll to inspect later content.
This is semantic interaction, not screenshot vision: unlabeled custom painting,
image contents, drag-only controls, maps, and native app UI need another design.

Each mounted session has an ID; each changed view has a new revision. Node IDs
are temporary and must be taken from the latest snapshot. Stale or replayed
commands are rejected. Requests are serialized, pending work blocks overlapping
commands, and an open owned panel can accept its next UI interaction. Manual
pointer input/text edits and leaving the foreground interrupt subsequent steps
of AI-origin action sequences. Replacing the controller or changing the boundary's
app identity also interrupts old work while a subtree stays mounted. Already-sent
server requests cannot be undone.

Snapshots report `ready`, `pending`, `hidden`, `blocked`, `unavailable`, or
`disposed`. Results report `completed`, `pending`, `failed`, `interrupted`, or
`rejected`. A completed UI event does not prove business success: inspect the
fresh screen and visible validation/error status. Poll while work is pending.
After an uncertain response, observe before choosing another command; do not
blindly repeat a payment or submission. The request history is in-memory and
bounded; server-side idempotency remains the publisher's responsibility.

Host permission policy remains authoritative. AI taps do not manufacture an
explicit native user gesture, so gesture-gated operations such as clipboard,
camera, gallery, microphone, sharing, maps, BLE scan, and NFC read still require
the existing human interaction. System authentication and permission dialogs
are outside the mini-program boundary. Business buttons are not filtered into
a hand-authored allowlist; the controller operates their existing UI callbacks.

## Separate Android tasks

Refresh generated integration:

```powershell
miniprogram embed init --project-root . --android-separate-tasks --force
```

In the host-owned `app_android_task_setup.dart` / configuration factory, create
a controller **in each mini-program engine** and supply it on that engine's
`MiniProgramConfig`. Generated `AndroidMiniProgramTaskApp` binds it to
`MiniProgramInteractionChannel` automatically. To support root Back returning
to the retained host, give the controller an `onExit` callback:

```dart
final interactions = MiniProgramInteractionController(
  onExit: () => const MethodChannel('mini_program/android_tasks')
      .invokeMethod<void>('showHost'),
);
```

The main engine can send the same JSON envelopes through the process-local relay:

```dart
final relay = MiniProgramInteractionChannel();
final snapshotJson = await relay.dispatch({'method': 'observe'});
```

The native relay chooses exactly one enabled Activity with window focus, rejects
background/ambiguous targets, serializes requests, and bounds request size and
response time. It adds no native dependencies or permissions. The host must
arrange its server connection/decision loop while the mini-program is visible;
background Android execution is not provided. A timeout is an uncertain outcome,
not permission to replay. Retained UI state remains subject to Android process
death and host eviction limits, as before.

Task identity is recovered from the owned `miniprogram://<package>/active/<appId>`
URI when Android restores a task without its original launch extras. This keeps
the restored slot associated with its mini-program and supplies a valid app ID
for a fresh load. In-memory drafts still require the original process to remain alive.

## Validation and optional live-model test

`hosts/mp_only_host/tool/build_ai_food_fixture.dart` builds a normal pure-Dart
food fixture with no special AI metadata. Its integration test covers embedded
rendering, separate tasks, stale commands, wrong-session rejection, keyboard/
screen/root Back, and retaining a cart/draft across task and host switches.

```powershell
cd hosts/mp_only_host
flutter pub get
dart run tool/build_ai_food_fixture.dart
flutter drive --no-dds --no-start-paused --driver=test_driver/integration_test.dart --target=integration_test/foreground_interaction_test.dart -d emulator-5554
```

Use the provided driver: its root library forwards the secondary Activity's
entrypoint, and `--no-start-paused` lets additional engines run without a
debugger resuming each isolate. The production Activity startup is unchanged.
When switching from integration tests to a release APK, use the normal
`flutter build apk --release` command so Flutter refreshes generated test-only
plugin registration; a cached `--no-pub` build can retain the test registrant.

For a live OpenRouter test, keep the key in the repository's ignored `.env`
(raw key or `OPENROUTER_API_KEY=...`). From the repository root:

```powershell
$env:MINI_PROGRAM_AI_TEST_TOKEN = 'choose-a-local-test-token'
python tools/test_foreground_ai.py --env-file .env --report "$env:TEMP\mini_program_ai_report.json"
```

In another terminal, forward the loopback port and run the same test:

```powershell
adb -s emulator-5554 reverse tcp:8767 tcp:8767
cd hosts/mp_only_host
flutter drive --no-dds --no-start-paused --driver=test_driver/integration_test.dart --target=integration_test/foreground_interaction_test.dart -d emulator-5554 --dart-define=MINI_PROGRAM_AI_TEST_SERVER=http://127.0.0.1:8767 --dart-define=MINI_PROGRAM_AI_TEST_TOKEN=choose-a-local-test-token
```

The loopback harness accepts only the food fixture and defaults to `openai/gpt-6-luna`,
replaces detailed snapshots each turn, and caps decisions at 16 and reserved
spending at USD 0.25. It records fixture decisions and usage, never the key.
It is test infrastructure; production developer servers own their own security,
budgeting, retry strategy, and model integration. Stop the server and remove the
ADB reverse rule after testing. Never bundle `.env` in host assets.

Initial Sol validation on 2026-10-26 passed 99 contracts tests, 637 SDK tests, 317 tooling
tests, and 16 reference-host tests. Android API 36 emulator runs passed
both embedded interaction and separate-task switching/draft retention, with
deterministic decisions and with the live model. The final live run reached the
two-portion order review with “No onions” in seven model decisions, using 3,169
tokens and reporting USD 0.007346. Total reported model cost across validation
attempts was USD 0.023402. These are fixture results, not a guarantee of model
accuracy on other apps or of native Recent apps behavior on every OEM launcher.

A normal Android x64 release APK also passed a separate native-UI smoke test.
Android reported distinct host, food-demo, and orders tasks. Returning through
the host and the orders mini-program, then reopening the food task, preserved
both the two-portion cart and the entered delivery note. This release smoke
used the normal app entrypoint without the model test harness.

## Personal Android phone-test APK

The reference host includes an optional host-owned floating AI bubble with an
editable goal panel, Start/Stop/Continue controls, decision/token/cost counters,
and recent operation history. Dragging docks the circle at either edge; minimizing
the panel preserves its draft. Its appearance and callbacks are host-configurable;
see [host-owned AI bubble](host_ai_bubble.md).
It calls OpenRouter over HTTPS directly from the phone. No laptop gateway or ADB
connection is needed after installation. Android Internet permission is declared
in the reference host. The phone must be able to reach `openrouter.ai` through
its own Internet connection (including a phone VPN when required).

For this explicitly opted-in personal build, the authorized test key is compiled
into the APK. Keep that APK for personal testing. Ordinary host builds omit this
test UI and key; the SDK and static mini-program artifacts remain provider-neutral.
The build helper reads the ignored `.env`, uses a temporary Dart-define JSON file,
redacts raw/base64 credentials from build output, and removes the temporary file.

```powershell
python tools/build_phone_ai_apk.py
```

This builds one release APK with ARM64 and x64 libraries at
`hosts/mp_only_host/build/app/outputs/flutter-apk/app-release.apk`. Optional
`--project-root`, `--env-file`, `--flutter`, and `--output` arguments support an
isolated build directory or another output location. The default model is
`openai/gpt-6-luna`; use `--model provider/model-id` to change it. Voice is deferred:
this runner sends text metadata and receives text decisions. Each run permits up
to 16 model decisions. The model/key configuration stays entirely in the reference
host's `lib/phone_ai/`; no AI package dependency is added.

Install the APK, tap the host's floating **AI assistant** circle, and tap
**Start AI**. One host-owned coordinator opens **AI Food Demo** in its native
task and continues from its current UI. Each task has a view of that same bot,
goal and draft; it does not create another model runner.
The initial goal prepares two portions with the note `No onions` and opens order
review without placing an order. You can edit the goal before starting. Keep the
mini-program visible while the AI acts; Stop, touching its UI, backgrounding,
or an uncertain/stale result interrupts the run. Stop/Cancel ends a goal; a
paused goal can instead Continue after observing the current screen again. The
host's bubble shows a status and keeps Stop available over SDK popup routes and
for paused tasks. Host controls are excluded from mini-program snapshots.
The SDK's existing native permissions and human-gesture checks still apply.

The host catalog adapter and cross-task assistant session live entirely in the
reference host. The SDK still observes only mini-program surfaces. Host developers
register their own visible host actions with their bot service; this SDK does not
inspect their Chat, Wallet or other application screens. The local Food fixture
has no nearby-shop backend or live checkout. See the bubble guide for the shared
session architecture, lifecycle and process-recreation limits.

**AI Controls Demo** exercises search text, a dropdown, a checkbox, the calendar
date picker, and a preference-review dialog. Set the shared goal to select Green
tea, Pickup, a reusable cup, and October 28, 2026. The separate catalog screen contains
24 items for scrolling tests. Both fixtures use ordinary pure-Dart authoring;
neither contains AI-specific button descriptions or an action catalog. Rebuild
the controls fixture with `dart run tool/build_ai_controls_fixture.dart` from the
reference host directory.

The runner waits for matching current-screen revisions before asking the model,
so keyboard and layout animations can settle. It applies the decision only to
that observed revision; a changed screen still stops the run without replaying
the action.

The initial Sol personal ARM64/x64 release APK passed a direct-HTTPS live test on the Android
API 36 emulator on 2026-10-26. It reached the two-portion order review with
`No onions` in seven decisions, using 2,874 tokens and reporting about USD 0.0068.
The Stop control remained available above the review dialog. Switching to the
host, opening Orders, and returning to Food preserved the cart and delivery
note, with distinct host/Food/Orders task records. Host analysis was clean and
all 16 host tests passed. Phone connectivity and model decisions can vary.

## Luna runner behavior

The host requests one structured decision per turn and sends only the current
screen's visible metadata plus up to eight short recent-operation entries.
Session IDs and revisions remain local. Each reply is validated against the
observed controls before dispatch. The terminal decisions are distinct:

- `done`: the model reports visible evidence that the goal was satisfied.
- `needsInput`: the model asks for missing information rather than inventing it.
- `blocked`: the model explains why the available UI cannot advance the goal.

The model's completion report still needs human review. A changed terminal view
invalidates that report, and an accepted UI action is not proof of business success.
The runner detects unchanged screens and repeated navigation cycles without
treating changing revision or node IDs as progress. Stop closes the model client
and ends the run promptly. Delayed replies cannot act on a newer run. Continue
always observes again; it preserves short history only for the same goal and
mounted session, and never automatically retries an uncertain action.

Reference-host defaults are 16 decisions, 20,000 reported tokens, USD 0.05 in
reported cost, five minutes total, 90 seconds per model reply, 25 seconds for a
settling screen, and 10 seconds per dispatch. Three actions without visible
progress stop the run. Hosts can inject `PhoneAiLimits` for their own runner.
Reported tokens/cost are feedback limits, not a hard provider billing cap;
production servers must enforce their own budgets. SDK interaction behavior
and host-accepted native permissions remain independent of these host-only limits.

The Luna polish passed all 50 reference-host tests and clean host analysis on
2026-10-26. Tests cover strict current-only model context, outcome validation,
limits, unchanged/cycling screens, pending and uncertain operations, prompt Stop,
late replies, fresh continuation, owner changes, narrow-screen goal editing,
real search/dropdown/checkbox/calendar controls, and offscreen catalog scrolling.
Three additional regressions cover restored task titles. Tooling analysis was
also clean. Its full suite passed 316 tests with one artifact test exceeding the
default 30-second timeout; the complete 10-test artifact file then passed with
`--timeout 2m --concurrency 1` on the same laptop.

The final `1.0.0-ai-luna+3` ARM64/x64 release APK passed direct-HTTPS Luna tests
on the Android API 36 emulator:

| Goal | Decisions | Reported tokens | Displayed cost (USD, rounded) |
| --- | ---: | ---: | ---: |
| Two portions, `No onions`, open order review | 7 | 3,841 | 0.0005 |
| Green tea, Pickup, reusable cup, October 28, open preference review | 9 | 8,298 | 0.0011 |
| Find catalog item 18 by scrolling and open its details | 5 | 3,737 | 0.0005 |

Stop/Continue worked from the APK. An existing task restored without extras
reopened with the correct app ID, and Android reported distinct host, Food,
Orders and Controls task records. Food retained both portions and its note
after switching through the host, Orders, Controls and the catalog test. Final
screenshots were inspected and the Flutter/Android crash log was empty. These
are bounded fixture results; they do not guarantee model accuracy for every UI
or preservation after Android kills the process. The build inspection confirmed
Internet permission, both ABIs, matching fixture assets/source, redacted build
logs, and deletion of the temporary define file.

The subsequent `1.0.0-ai-bubble+4` build replaces the fixed test strip with the
host-owned floating assistant. All 57 host tests and the live Food/Controls
release-APK flows passed. See [host-owned AI bubble](host_ai_bubble.md#validation)
for customization and the bubble-specific validation results.

The `1.0.0-ai-bubble-fix+5` follow-up fixes stale goal submission after a quick
edit, keeps Stop available for paused tasks, adds explicit task cancellation and
visible outcome labels, and follows mini-program Back navigation in the host
toolbar. All 63 host tests and two consecutive live Controls goals passed, along
with release-APK Stop/Cancel, catalog Back and task-return checks. See the bubble
guide's validation section for the scope of those results.

The `1.0.0-shared-ai+6` follow-up adds one main-host runner shared by the host
catalog and mini-program tasks. Its visible Stop button has an explicit accessible
action above modal routes. All 68 host tests and analysis passed. The final API 36
release-APK checks covered host-to-Food launch, shared cancellation and restart,
two consecutive goals, manual takeover, background pause without automatic
resumption, and retained cart state. See the
[bubble guide's validation results](host_ai_bubble.md#validation) for the exact
scope and reported usage. Host catalog automation remains reference-host code;
the SDK's observation boundary still covers mini-program UI only.
