# Android native mini-program windows

The reference host creates separate Android tasks for the host and each open
mini-program. Native Android windows are the current integration focus, and
ordinary builds use that flow without a presentation-mode flag. Android's task
records and a manufacturer's Recent apps cards are separate things to verify.
A launcher can hide a task's card while the Activity, Flutter engine, and
in-memory mini-program state remain alive.

Native tasks belong to the host's Activity and manifest integration. The Dart
SDK supplies runtime rendering, state, navigation, and foreground capability
lifecycle handling. This integration cannot guarantee separate Recent apps
cards on every Android ROM through public Android APIs.

Existing Flutter hosts can generate this integration with
`miniprogram embed init --project-root . --android-separate-tasks`, then wire
the generated scope navigation delegate. Plain `embed init` retains standard
in-host navigation. See [separate Android task setup](android_separate_tasks_setup.md)
for setup, per-engine configuration, and verification.

## Confirmed Vivo behavior

On 2026-10-18, wireless ADB inspection reproduced the single-card behavior on:

| Item | Observed value |
| --- | --- |
| Phone | Vivo S10 Pro, model V2121A |
| Android | 13, API 33 |
| ROM display version | OriginOS 3 |
| Home and Recents provider | `com.bbk.launcher2`, version `13.5.1.280` |
| Host package | `dev.miniprogram.mp_only_host` |
| Installed host APK | Exact SHA-256 match with the built ARM64 release APK |

Opening Profile Center created host task `196` and mini-program task `197`,
with distinct components and affinities. Both were alive in process `29106`,
with `inRecents=true` and `autoRemoveRecents=false`. Vivo's visible Recent apps
list showed Profile Center and omitted the host card.

Further testing kept the host, Profile Center, Orders, and Wallet alive as four
native tasks (`196`, `197`, `200`, and `201`) while Vivo still displayed one
card for the package. Profile Center's details screen survived switching
through the host, Orders, and Wallet, then hardware Back and reopening. The
original host and Profile Center Activity tokens, task IDs, and process ID
were unchanged. This verifies that the missing cards in this test did not
represent disposal of those mini-programs.

Inspection of that phone's installed launcher APK identified the filtering
rule:

- `com.android.quickstep.recents.utils.VivoTaskRules.isLimited` counts ordinary
  tasks by package name and Android user ID. After the first task, it returns
  `LIMIT_IGNORE` (`2`). The default maximum count is `1`.
- `com.android.quickstep.recents.model.RecentTasksList.filterTasks` omits those
  ignored tasks from the visible card list.
- The launcher's `SPECIAL_APP_RULES` explicitly includes `com.tencent.mm`,
  matching WeChat mini-program affinities starting with `.AppBrandUI` or
  components starting with `com.tencent.mm.plugin.appbrand.ui.AppBrandUI`.
  These tasks receive separate counting rules, explaining why WeChat can show
  its host and mini-program cards on this phone.

The inspected launcher APK's SHA-256 is
`309053CE610D13B2DE6DFA91DF523B739BDA9CEF2AAAC34027AEDF2DCE0C9B6B`.
The finding applies to this launcher version; other Vivo and Android ROM
versions need their own verification. Proprietary launcher code is not part of
this repository.

WeChat also used a separate `com.tencent.mm:appbrand0` process. Process
separation alone cannot bypass this launcher's ordinary-package rule: that
rule counts package names and user IDs, without checking process names.
Additional Activity components, affinities, or launch flags do not change its
package key. ABI splitting and Gradle/Kotlin versions do not change this rule.

## Host integration decisions

Keep the standard native task implementation for devices whose Recent apps
provider displays those tasks independently. Test visible cards on target
phones in addition to inspecting task IDs.

For this Vivo launcher, separate cards require a change in the launcher's
compatibility rules or other vendor support. There is no public Android
permission or SDK option that grants the WeChat exception to another package.
Do not treat a package-name imitation, additional processes, or a new APK build
as a verified solution.

An optional host-owned horizontal strip of open mini-programs is deferred to
future implementation. The current SDK does not provide a running-app
workspace or a button that transfers a live native mini-program into the host
window. The proposed interaction and state requirements are preserved in the
[future one-window workspace design](android_in_app_workspace_future.md).
There is no automatic fallback: successful task creation does not reveal
whether an OEM launcher actually displays its card. There is no reliable
public Android API for confirming that presentation, and no verified global
affected-device percentage is available.

In-memory state still depends on Activity/process lifetime. Android process
death, force stop, or removal of a task can discard it. Durable drafts need an
explicit host-accepted persistence policy.

## Inspect a target phone

Connect with authorized USB debugging or Android 11+ Wireless debugging.
Wireless debugging uses a pairing-code dialog and pairing port first, then a
different connection port from the main Wireless debugging screen. When a VPN
address is not reachable, use the phone's reachable Wi-Fi address with the
displayed port. Successful pairing does not always connect automatically.

With the host and a mini-program open, run from the repository root:

```powershell
.\tools\inspect_android_windows.ps1 -DeviceSerial '<adb-device-serial>'
```

The script reports device and launcher versions, installed app metadata,
owned task identities, affinities, and running activities. Compare this output
with the phone's visible Recent apps cards:

1. One native task indicates a launch/integration issue to investigate.
2. Separate live tasks with missing cards indicate a presentation/filtering
   issue to investigate in the actual launcher.
3. Missing Activities or processes indicate a lifecycle or termination issue.

Keep diagnostic captures under ignored build output. Compare only structural
task/Activity information when using another app as a reference.

## Android references

- [Tasks and the back stack](https://developer.android.com/guide/components/activities/tasks-and-back-stack)
- [Recent apps](https://developer.android.com/guide/components/activities/recents)
- [Wireless ADB](https://developer.android.com/tools/adb#connect-to-a-device-over-wi-fi)

These Android documents explain standard task behavior. The Vivo-specific
filtering above was established by inspection of the connected phone's
launcher, rather than inferred from the standard Android behavior.
