# Future Work

Keep this file for unfinished work only. Completed cleanup and MVP boundary documentation should not be re-added here.

## Architecture Rules To Preserve

- Host opening uses only `appId + artifactBaseUrl`.
- Static mini-program artifacts are public UI bundles.
- Runtime API config is optional and belongs to mini-program runtime actions.
- Publisher middle-servers own auth, database access, payments, files, secrets, external APIs, admin logic, and business rules.
- Runtime APIs must call only the configured publisher middle-server URL.
- `mini_program_ui` stays pure Dart.
- SDK/runtime and tooling stay provider-neutral.

## Next Work

1. Add real runtime middle-server API examples for catalog search, profile update, file metadata, notification list, checkout draft, and form submit.
2. Add SDK/runtime tests for common middle-server error states: validation failure, 401 session expired, 403 forbidden, 429 rate limit, 500 server error, and 503 retryable outage.
3. Add a full sample mini-program that uses `Mp.backend.query`, `Mp.backend.call`, `Mp.lazy.chunk`, search/load-more, and form submit against one mock middle-server.
4. Improve static artifact diagnostics: validate manifest URL, entry screen URL, and common static server path mistakes.
5. Improve `Mp.lazy.chunk` examples for product lists, news feeds, chat history, order history, and search results.
6. Add a neutral static artifact host checklist: headers, cache control, immutable screen paths, latest manifest path, and local static server testing.
7. Add release automation that verifies current MVP docs present only static artifact opening plus optional runtime middle-server APIs.
