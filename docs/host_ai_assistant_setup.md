# Optional host-owned AI assistant setup

Initialize a Flutter Android host with one assistant across its main app and
separate mini-program tasks:

```powershell
miniprogram embed init --project-root . --android-separate-tasks --ai-assistant
```

For an existing integration, add `--force`. An installed assistant is retained
by later force refreshes, including when the flags are omitted. Standard
embedding and task-only embedding continue to omit the assistant.

Requires tooling `0.7.22`, SDK `0.7.4`, and contracts `0.3.21` or newer compatible
versions. For a source checkout, run it from `packages/mini_program_tooling`:

```powershell
dart run bin/miniprogram.dart embed init --project-root D:\my_host --android-separate-tasks --ai-assistant --force
```

## What is installed

The command connects the host's `MaterialApp.builder` and generated mini-program
task builders to a draggable assistant bubble, text-goal panel, status, Stop and
Continue controls. It preserves an existing builder, Navigator key, Router and
host layout. One coordinator/model loop lives in the main host engine. Other
tasks have presentation clients sharing its goal draft, progress and cancellation.

The native session relay is process-local and observes Activity focus without
adding custom lifecycle overrides to the host Activity. SDK interaction remains
limited to the current mini-program's visible controls and owned popup routes.
The assistant itself is outside that observation boundary.

Generated files include:

- `lib/mini_program/mini_program_ai.dart`: assistant public import.
- `lib/mini_program/ai/`: managed presentation, runner, model interface and session.
- `lib/mini_program/app_ai_setup.dart`: created-once host configuration.
- `HostAiSessionRelay.kt`: managed native session transport alongside task code.

The generated host runtime supplies one interaction controller per engine, and
the task root binds it automatically. Keep the normal embedding setup, including
`MiniProgramScope(navigationDelegate: openMiniProgramInAndroidTask, ...)`, so
launches use those tasks. A host replacing the generated runtime configuration
must supply a `MiniProgramInteractionController` in its own `MiniProgramConfig`.

No model provider, provider key, extra host package, Android overlay permission
or Gradle dependency is installed. Without AI configuration, starting a goal
shows a setup message and makes no model request.

## Connect the host's AI service

Edit `lib/mini_program/app_ai_setup.dart`. This file is never overwritten,
including with `--force`. For the optional provider-neutral server adapter:

```dart
import 'ai/host_ai.dart';

HostAiSettings buildHostAiSettings() => HostAiSettings(
  modelFactory: () => HostAiHttpModel(
    endpoint: Uri.parse('https://your-host-server.example/ai/decide'),
    headers: () async => {
      'Authorization': await yourHostSession.authorizationHeader(),
    },
  ),
  bubbleStyle: const HostAiBubbleStyle(label: 'My assistant'),
  limits: const HostAiLimits(maxDecisions: 16),
);
```

`yourHostSession` is the host's own authenticated service. Alternatively,
implement `HostAiModel` with the host's existing AI integration. Its `decide`
method receives the current snapshot and short progress trail. Its `close`
method must cancel pending I/O; the runner independently rejects late replies.
Each new run creates a client, and only the owner creates model clients.

`HostAiHttpModel` sends `HostAiModelContext.build(...)` as JSON to the configured
absolute HTTPS endpoint. It disables redirects, bounds the response at 32 KiB,
and exposes public errors without raw response bodies. The request includes
`goal`, the current `screen` and up to eight short `progress` entries. Local
session/revision tokens, raw actions, state, credentials and protected values
are excluded. The host server supplies prompts, authentication, its selected
model and provider credentials. `HostAiModelContext.instructions` describes the
decision protocol for a host server to adapt.

The response format is:

```json
{
  "decision": {"action": "tap", "targetId": "current-visible-node-id"},
  "tokens": 123,
  "costUsd": 0.0001
}
```

`tokens` and `costUsd` are optional reported usage. A terminal decision uses
`action: "done"`, `"needsInput"` or `"blocked"` plus a bounded `message`, without
a target. UI operations must be advertised by the current node; the host runner
validates them and attaches the local session/revision when dispatching. Reported
usage limits do not replace server-side billing enforcement.

## Register host actions

Ordinary mini-program controls require no extra AI authoring. The host registers
its own buttons explicitly with `HostAiAction`; the SDK does not inspect host UI.

```dart
Future<void> openFood() async {
  await MiniProgramScope.of(context).openMiniProgram<void>(
    appId: 'food_shop',
    title: 'Food shop',
  );
}

HostAiAction(
  id: 'open-food-shop',
  label: 'Open Food shop',
  opensMiniProgramId: 'food_shop',
  onTap: openFood,
  child: FilledButton(
    onPressed: openFood,
    child: const Text('Food shop'),
  ),
)
```

Import the host's generated `mini_program.dart` for these types. Set `enabled`
to match the actual control. Use unique bounded IDs and visible labels. Hidden,
disabled, duplicate and clipped controls cannot be selected; stale requests and
replayed taps are rejected. Only declare `opensMiniProgramId` when that callback
successfully opens the named native task. That trusted launch authorizes the
same goal to continue in the new mini-program. Unrelated session changes pause it.

Chat, Wallet, nearby-shop discovery and real orders remain host/publisher
services. Register the host actions appropriate to those screens. The initial
host adapter supports registered taps; it does not automatically expose the
host's text fields, chat contents or arbitrary application state.

## Lifecycle and supported source layouts

Stop ends the shared task and closes pending model I/O from either screen.
Applied changes and the editable goal draft remain. Manual input pauses work;
leaving the app pauses it without automatically resuming on return. A bounded
focus-handoff wait permits a trusted native launch without operating hidden UI.
Process death starts a new assistant session. If only a mini-program task is
restored, its panel asks the user to return to the host once.

Automatic installation currently targets Android/Kotlin hosts with one
`MaterialApp` or `MaterialApp.router` root under `lib/`, including a root in a
separate Dart library. It requires separate-task setup. Multiple app roots,
part-of app libraries, malformed syntax, import-prefix conflicts and unrecognized
managed-file collisions fail before any writes. For multiple roots, import
`mini_program_ai.dart` as `mini_program_ai` and explicitly select the intended
root with `builder: mini_program_ai.buildHostAiOverlay`, then retry.

Keep custom code in `app_ai_setup.dart` or other host-owned files. Tooling manages
the `ai/` directory. The installer uses the existing transactional write plan;
capability registrations, accepted policies, endpoints and host configuration
remain intact across regeneration.

Generated Dart can be checked without a model account in a disposable host:

```powershell
python tools/test_generated_ai_assistant.py --project-root D:\temporary_test_host
```

The helper installs only marked validation tests, analyzes the generated host
and runs its assistant widget/runner tests. Android task transport also needs
release-APK device/emulator testing. Separate tasks remain subject to the
[documented OEM Recent apps behavior](android_native_windows_compatibility.md).

## Verification

The development integration passes all 332 tooling tests, including installer
transactionality, source-layout handling and regeneration. The emitted assistant
source also passes Flutter analysis and 15 Flutter tests covering shared-runner
handoff, cancellation and late replies, current-screen context, host-control
visibility, retained input/drafts, and bubble layout and accessibility. Tooling
analysis reports no issues.

On 2026-10-27, a generated host release APK (`1.0.0-tooling-ai+9`, Android API 36,
x64 emulator) passed the native-task end-to-end checks with a local deterministic
test model. The checks verified bubbles in both engines, a host goal launching
and continuing inside a mini-program, Stop shared back to the host, restarting
through an order review, manual takeover, background pause without automatic
resume, and retained cart quantity and delivery text after switching tasks.
Android reported distinct host and mini-program task records; Flutter error and
Android crash logs were empty. No provider key or paid model request was used.

This generated integration has not yet been tested on a physical Vivo or other
OEM device, and the emulator run does not validate an external AI server.
