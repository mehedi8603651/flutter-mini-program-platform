# mini_program_legacy_stac

Optional legacy Stac screen compatibility for `mini_program_sdk`.

New Mp-only hosts do not need this package. Hosts that still consume older
mini-programs with missing `screenFormat` or `screenFormat: "stac"` register
the adapter explicitly:

```dart
import 'package:mini_program_legacy_stac/mini_program_legacy_stac.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

final config = MiniProgramConfig(
  // Existing runtime configuration...
  renderers: legacyStacRenderers,
);
```

The adapter keeps Stac and its transitive dependencies outside the lightweight
base SDK.

Tooling can generate the registration automatically:

```powershell
miniprogram embed init --with-legacy-stac
```

The public demo remains a legacy Stac fixture, so
`miniprogram embed init --with-demo` also enables this adapter. New Mp-only
hosts should not add this package.
