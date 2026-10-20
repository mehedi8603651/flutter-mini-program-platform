# Date and time selection fields

`Mp.dateTime` provides three pure-Dart authoring helpers. The SDK renders their
JSON with Flutter's built-in Material calendar and clock dialogs. There is no
third-party picker dependency, native bridge, Android permission, or calendar
application integration. Standard embedding and separate Android tasks use the
same fields.

Requires contracts `0.3.18`, UI `0.2.14`, SDK `0.6.16`, and tooling `0.7.16` or
newer compatible releases. Existing artifacts and form controls remain supported.

## Authoring

```dart
import 'package:mini_program_ui/mini_program_ui.dart';

MpNode buildBookingForm() => Mp.form(
  id: 'booking',
  children: [
    Mp.dateTime.dateField(
      stateKey: 'booking.date',
      label: 'Booking date',
      name: 'date',
      hint: 'Choose a day',
      minDate: '2026-10-01',
      maxDate: '2027-12-31',
      required: true,
      onChanged: Mp.state.set('booking.date_changed', true),
    ),
    Mp.dateTime.timeField(
      stateKey: 'booking.time',
      label: 'Booking time',
      initialValue: '14:30',
      required: true,
    ),
    Mp.dateTime.dateRangeField(
      stateKey: 'booking.stay',
      label: 'Check-in and check-out',
      initialValue: {'start': '2026-10-25', 'end': '2026-10-28'},
      minDate: '2026-10-01',
      maxDate: '2027-12-31',
    ),
    Mp.formSubmit(label: 'Book', endpoint: '/bookings'),
  ],
);
```

The submit action uses the existing accepted Publisher API integration. A picker
does not authorize backend access or guarantee a date/slot is available.

All fields require a `stateKey` and `label`. They also accept an optional `name`,
`hint`, `initialValue`, `onChanged`, and the booleans `required` (default false)
and `enabled` (default true). Date and range fields accept inclusive `minDate`
and `maxDate`, defaulting to `1900-01-01` and `2100-12-31`. Time fields select an
hour/minute, without time bounds or a timezone setting.

Bounds and initial selections are literal canonical strings, not bindings or
`DateTime` objects. Date limits are explicit artifact configuration; they do not
automatically move to tomorrow. Update the bound state through existing
`Mp.state.*` actions to change or clear a selection at runtime.

## Values and forms

| Field | State value | Example |
| --- | --- | --- |
| `dateField` | Gregorian civil date | `"2026-10-25"` |
| `timeField` | 24-hour clock time | `"14:30"` |
| `dateRangeField` | Inclusive ordered dates | `{"start":"2026-10-25","end":"2026-10-28"}` |

Same-day ranges are valid. Dates are strictly checked: `2026-02-30` and
`1900-02-29` are rejected rather than normalized. Times reject values such as
`24:00`, `9:30`, or `2:30 PM` in stored state. Picker labels and displayed values
use the host's Material localizations and 12/24-hour preference; stored values
keep the formats above. Hosts configure their supported locales as usual.

Existing state takes precedence over `initialValue`. An initial value seeds only
an absent key. Without an initial selection the key remains absent until the
user confirms. Setting state to null or an empty string, or removing the key,
clears the displayed selection. Invalid external state is shown as a field error
and cannot be submitted through the form until corrected.

Within `Mp.form`, `name` defaults to the last segment of `stateKey` (`date`,
`time`, and `stay` above). Give fields unique names in that form. The form body
contains those names and the selected values; `{{form.date}}` and
`{{state.booking.date}}` work with existing bindings. Required-field validation
uses the current state-backed selection, including when a field is disabled.
Disabled fields preserve their values and cannot open a picker.

Fields can also be used outside a form as state-bound controls. Direct custom
renderer integrations must supply the usual `MiniProgramSdkScope.stateManager`;
normal SDK host/page integration already does so.

## Ownership and lifecycle

- Confirmation writes to the quota-enforced live-state store first, then updates
  the form and runs `onChanged`. A rejected write preserves prior state/form
  values, shows a save error, and does not run the action.
- Cancelling, pressing Back, or confirming an unchanged value does not run
  `onChanged`. Unconfirmed calendar/clock edits do not enter mini-program state.
- Backgrounding cancels the open picker. Confirmed selections remain available
  when the existing mini-program session resumes. A pending dialog is removed
  when Flutter next renders; its result is invalidated immediately.
- Hidden/disposed fields, app/store/key changes, changed field configuration,
  and external selection edits invalidate the owned picker and stale results.
  Covering it with a newer host route removes only that picker, preserving the
  newer route.
- In-memory retention depends on the mini-program session/process remaining
  alive. Persist durable booking drafts through the existing accepted cache or
  Publisher API integration.

Android Back follows the host's navigation integration. In generated separate
tasks it returns to the host and cancels a pending picker on backgrounding;
reopening the mini-program keeps its last confirmed selection. Use the picker's
Cancel or Close control to stay in that mini-program. With standard embedded
navigation, Back dismisses the picker.

The publisher decides the business timezone, slot availability, opening hours,
and reservation rules. These civil selections are not UTC instants and do not
create calendar events or perform timezone conversion.

## Validation

Contract tests cover exact civil formats, leap years, invalid normalized dates,
and ordered immutable ranges. Authoring tests cover deterministic JSON and
configuration errors. SDK tests exercise real picker interactions, form bodies,
required fields, cancellation/Back, external state changes, quotas, hidden and
background lifecycle, disposal, and dialog ownership when host routes change.

Android API 36 release-APK checks cover calendar, clock, and range gestures;
required/disabled fields; Cancel/Back; embedded navigation; cancellation of a
pending picker on backgrounding; host draft retention; and independent confirmed
selections across two retained mini-program tasks.
