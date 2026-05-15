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
code --install-extension mini-program-tools-0.1.4.vsix
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
  - `MiniProgram: Embed Init`
  - `MiniProgram: Configure Host Cloud`
  - `MiniProgram: Import Host Endpoint`
  - `MiniProgram: Add Host Endpoint`
  - `MiniProgram: Run Host App`
  - `MiniProgram: Env Init`
  - `MiniProgram: Configure AWS Environment`
  - `MiniProgram: Use Environment`
  - `MiniProgram: Environment Status`
  - `MiniProgram: Cloud Deploy`
  - `MiniProgram: Cloud Status`
  - `MiniProgram: Cloud Outputs`
  - `MiniProgram: Backend Init`
  - `MiniProgram: Backend Start`
  - `MiniProgram: Backend Stop`
  - `MiniProgram: Backend Status`
  - `MiniProgram: Create Access Key`
  - `MiniProgram: List Access Keys`
  - `MiniProgram: Revoke Access Key`
  - `MiniProgram: Rotate Access Key`
  - `MiniProgram: Create Partner Package`
  - `MiniProgram: Validate Partner Package`
  - `MiniProgram: Open Partner Package`
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

## Environment and backend workflow

Use `MiniProgram: Env Init` in a mini-program or host workspace before
configuring cloud delivery. `MiniProgram: Configure AWS Environment` prompts for
the environment name, S3 bucket, region, optional AWS profile, stack/stage names,
and access-key enforcement. `MiniProgram: Cloud Deploy` deploys the AWS backend,
and `MiniProgram: Cloud Outputs` prints the backend API URL or a Flutter
`--dart-define` snippet.

Local backend commands are also available for development: initialize the backend
workspace, start/stop the local backend, and inspect backend status without
leaving VS Code.

## Partner handoff workflow

Mini-program publishers can create the host handoff file from VS Code:

1. Run `MiniProgram: Create Access Key` and copy the generated key.
2. Run `MiniProgram: Create Partner Package`.
3. Enter the appId, title, access key, and either a configured env or direct API
   base URL.
4. Send the generated `.partner.json` file to the host app developer.

The host developer then runs `MiniProgram: Import Host Endpoint` and selects the
partner package. Partner packages contain an access key, so treat them as secret
files and do not commit them.

## Secret handling

The sidebar renders only the redacted workflow status fields. It does not show
raw MiniProgram access-key values from endpoint maps or partner packages.
Commands that accept secret command-line inputs redact those values in the
MiniProgram output channel. Create/rotate access-key commands still show the
newly generated key returned by the CLI so you can copy it into a partner
package or host endpoint.
Endpoint setup prompts stay open when you switch windows, so you can copy API
URLs or access keys and paste them without restarting the command.
