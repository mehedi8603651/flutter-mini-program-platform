String buildStaticPublishInstructions({
  required String miniProgramId,
  required String version,
}) =>
    '''# MiniProgram Static Artifacts

This directory contains the portable artifact bundle for `$miniProgramId`
version `$version` under `artifacts/$miniProgramId/$version/`.

Upload the `artifacts/` directory to any public static file host. Upload the
immutable version directory first and `artifacts/$miniProgramId/latest.json`
last. GitHub Pages users should retain the generated `.nojekyll` marker.

Public artifacts must never contain secrets, private user data, authentication
state, payment data, or server-side business rules.
''';
