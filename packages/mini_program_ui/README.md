# mini_program_ui

Pure-Dart authoring helpers for the future Mp JSON mini-program engine.

This package intentionally does not depend on Flutter, Stac, analyzer,
build_runner, Material, or Cupertino. Mini-program authors use `Mp.*` helpers
to produce versioned JSON that the SDK will parse and render in a later
milestone.

```dart
import 'package:mini_program_ui/mini_program_ui.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    'coupon_home': () => Mp.column(
      children: <MpNode>[
        Mp.heading('Publisher account'),
        Mp.text('Sign in to continue'),
        Mp.primaryButton(
          label: 'Sign in',
          action: Mp.auth.showEmailAuth(),
        ),
      ],
    ),
  },
);
```
