# MiniProgram Tools

Native VS Code sidebar for MiniProgram CLI workflows.

This extension is a thin UI over the installed `miniprogram` CLI. It does not
reimplement create, build, validate, publish, preview, AWS, access-key, partner
package, host endpoint, or backend logic.

## Local install

Requires `mini_program_tooling` 0.3.9 or newer, because the sidebar reads
`miniprogram workflow status --json`.

```bash
dart pub global activate mini_program_tooling
cd packages/mini_program_vscode
npm install
npm run compile
npm run package:vsix
code --install-extension mini-program-tools-0.1.0.vsix
```

## Features

- Activity Bar view named `MiniProgram`.
- Local workflow status from `miniprogram workflow status --json`.
- Manual remote status from `miniprogram workflow status --remote --json`.
- Core workflow commands:
  - `MiniProgram: Create MiniProgram`
  - `MiniProgram: Build`
  - `MiniProgram: Validate`
  - `MiniProgram: Preview`
  - `MiniProgram: Publish`
  - `MiniProgram: Refresh Status`
  - `MiniProgram: Refresh Remote Status`

## Settings

- `miniProgram.cliPath`: command or path for the installed CLI. Defaults to
  `miniprogram`.
- `miniProgram.defaultPreviewDevice`: default preview device. Defaults to
  `emulator-5554`.
- `miniProgram.status.autoRefresh`: refresh local status on activation and
  workspace changes. Defaults to `true`.

Remote status checks are never automatic. Use `MiniProgram: Refresh Remote
Status` when you want cloud/backend checks.

## Secret handling

The sidebar renders only the redacted workflow status fields. It does not show
raw MiniProgram access-key values from endpoint maps or partner packages.
