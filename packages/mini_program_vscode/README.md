# MiniProgram VS Code Extension

VS Code helper commands for the current mini-program MVP:

- create, build, validate, and preview mini-programs
- publish public static artifact folders
- create and import static artifact partner packages
- initialize Flutter host integration
- run local mock Publisher API servers for optional runtime API testing
- validate and smoke Publisher API Contract V1 runtime endpoints

The extension follows the platform boundary:

- host opening uses only `appId + artifactBaseUrl`
- runtime middle-server API config is optional
- business data, auth, payments, storage, secrets, and admin logic belong behind the publisher middle-server

## Useful Commands

- `MiniProgram: Create MiniProgram`
- `MiniProgram: Build`
- `MiniProgram: Validate`
- `MiniProgram: Preview`
- `MiniProgram: Publish Public Static MiniProgram`
- `MiniProgram: Create Partner Package`
- `MiniProgram: Import Host Endpoint`
- `MiniProgram: Add Host Endpoint`
- `MiniProgram: Run Host App`
- `MiniProgram: Setup Mock Publisher API`
- `MiniProgram: Run Mock Publisher API`
- `MiniProgram: Publisher API Contract Init`
- `MiniProgram: Publisher API Contract Validate`
- `MiniProgram: Publisher API Contract Smoke`

Publisher API Contract V1 is a runtime API standard only. It is not required for static artifact opening.
