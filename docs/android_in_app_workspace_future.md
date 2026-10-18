# Future one-window mini-program workspace

Status: deferred design. The current Android integration focuses on one host
task plus separate native mini-program tasks. The SDK does not currently ship
a running-app tab strip, workspace controller, or native-to-workspace transfer
API. Existing page embedding and route-based APIs remain available.

This document preserves the optional one-window direction for future work.
It is not an integration guide for an available SDK feature. Native behavior
and confirmed launcher restrictions are documented in
[Android native windows compatibility](android_native_windows_compatibility.md).

## Proposed host experience

A host developer may eventually opt into a workspace inside the host app:

1. Opening the first mini-program reveals a horizontal running-app strip below
   the host app bar and reserves space above the host's content.
2. A fixed Host button stays accessible. Running mini-programs show trusted
   host catalog names or logos in horizontally scrollable tabs.
3. The host's own catalog opens new mini-programs. The strip remains available
   across the host's Chat, Wallet, and other screens.
4. Selecting Host or another mini-program keeps each page mounted, preserving
   entered form data, local state, and internal navigation while the process
   remains alive.
5. System Back from a selected mini-program returns to Host without popping
   that mini-program's internal screen stack.
6. Explicitly closing a tab releases only that mini-program. Closing the final
   tab removes the strip and restores the host content area.

The host owns the choice to enable this presentation and the number of retained
apps. This mode must be optional and must not alter native-window integrations
or require a change to mini-program artifacts. It does not require a system
overlay or picture-in-picture permission.

## Runtime and lifecycle requirements

Retain stable host and mini-program subtree identities when selecting or
removing tabs. A hidden page must lose input focus and pause animation tickers
and foreground-only capabilities. Existing visibility and Android lifecycle
handling should remain the runtime boundary for those capability decisions.

System Back needs one owner: hidden mini-programs and the selected page must
not also pop their internal navigation when the workspace selects Host. Keep
ordinary standalone page Back navigation working.

Keep the host's nested Navigator inside the retained host subtree. Reuse stable
runtime dependencies; changing source/configuration may deliberately reload
an app. Test short landscape layouts, large text, horizontal tab scrolling,
keyboard dismissal, app backgrounding, and removing earlier tabs. Isolate
surface painting so hiding the final strip does not invalidate the outer host
app bar on Android renderers.

Retained memory is not durable recovery. Process death, force stop, and explicit
closing can discard state; resumable drafts need accepted persistence policy.

## Choosing a mode and transferring a live app

Choosing a presentation before opening mini-programs is separate from moving
an already-running mini-program between presentations. Native windows use
separate Flutter engines, whereas an in-app workspace would retain pages in
the host's engine. A Flutter widget tree cannot simply move between them.

A future live-transfer feature needs a defined state handover for supported
runtime data, navigation, and form values; cancellation of outstanding work;
cleanup of source-window resources; and a way to recover from failed transfers
without losing the source session. Arbitrary widget state and native resources
must not be assumed transferable. Such an API requires separate design and
verification before promising lossless switching.

Do not infer launcher card visibility from successful task creation or device
brand. The host developer should explicitly choose this optional presentation.

## Future verification

Before introducing the workspace as a supported feature, verify independent
drafts and navigation across multiple mini-programs, host Chat/Wallet routes,
foreground capability cleanup, background/resume, Android Back, explicit
closing and reopening, and memory limits. Validate the final release APK on
an emulator and representative physical devices. Native-window behavior must
continue to pass its own task and state-retention checks.
