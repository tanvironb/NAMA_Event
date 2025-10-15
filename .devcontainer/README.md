# Flutter Dev Container Usage

## Running with CLI

Install Dev Containers CLI:

```bash
npm install -g @devcontainers/cli
```

Build and run:

```bash
devcontainer build --workspace-folder .
devcontainer run --workspace-folder .
```

## Flutter Commands

- Web: `flutter run -d chrome`
- Emulator: `flutter run -d emulator`
- Device: `flutter run -d <device-id>` (use `flutter devices` to list)
