# NotOnDeck

NotOnDeck is a desktop Steam plugin loader for macOS, with Windows support planned next.

It is a fork of [SteamDeckHomebrew/decky-loader](https://github.com/SteamDeckHomebrew/decky-loader). The original Decky Loader project, code history, GPLv2 license, and upstream contributor credit remain with SteamDeckHomebrew. This fork focuses on adapting that loader architecture for desktop Steam clients instead of SteamOS.

## Status

- macOS: working local install, LaunchAgent autostart, Steam CEF injection, and plugin crash quarantine.
- Windows: planned. The upstream codebase already has partial Windows runtime/build support; NotOnDeck still needs a first-class installer, autostart flow, path handling, and test pass.
- SteamOS/Linux: use upstream [Decky Loader](https://github.com/SteamDeckHomebrew/decky-loader). NotOnDeck is not trying to replace the Steam Deck version.

## What Works On macOS

- Runs the loader as the current macOS user.
- Stores loader data under `~/Library/Application Support/decky-loader`.
- Starts automatically through `~/Library/LaunchAgents/xyz.decky.loader.plist`.
- Injects into desktop Steam through the CEF remote debugger.
- Loads Decky-compatible frontend plugins.
- Automatically disables plugins that crash during frontend import, frontend render, or backend task execution.

Some Decky-compatible plugins still assume SteamOS, Linux paths, systemd, Gamescope, root access, or Steam Deck hardware. Those plugins may be disabled automatically when they crash.

## macOS Install

Build the frontend:

```bash
cd frontend
pnpm i
pnpm run build
cd ..
```

Build the macOS backend binary:

```bash
cd backend
uv run --no-project --python 3.11 --with-editable . --with pyinstaller==6.8.0 pyinstaller pyinstaller.spec
cd ..
```

Install or update the local LaunchAgent install:

```bash
./scripts/macos-install.sh install
```

Check status:

```bash
./scripts/macos-install.sh status
```

Restart NotOnDeck:

```bash
./scripts/macos-install.sh restart
```

Uninstall the local macOS install:

```bash
./scripts/macos-install.sh uninstall
```

More macOS notes are in [docs/macos.md](docs/macos.md).

## Steam Setup On macOS

The installer creates the Steam CEF debugging marker next to the detected `steam_osx` binary. Steam needs that marker so NotOnDeck can inject the frontend.

If Steam was already open before installation, restart Steam or run:

```bash
./scripts/macos-install.sh restart
```

The status command should report:

```text
LaunchAgent: loaded
NotOnDeck loader: running
NotOnDeck backend: reachable
Steam CEF debugger: reachable
```

## Plugins

NotOnDeck can load existing Decky-compatible plugins, but plugin compatibility is currently best-effort on macOS.

Known problem categories:

- Linux-only filesystem paths, such as `~/.local/share/Steam`.
- Steam Deck hardware assumptions.
- systemd or root-only commands.
- UI plugins that import icons or Steam modules that are unavailable on desktop Steam.

When a plugin crashes, NotOnDeck disables it and shows a Steam notification naming the plugin.

## Development

Frontend:

```bash
cd frontend
pnpm i
pnpm run typecheck
pnpm run lint
pnpm run build
```

Backend:

```bash
python3.11 -m compileall -q backend/decky_loader
```

macOS binary:

```bash
cd backend
uv run --no-project --python 3.11 --with-editable . --with pyinstaller==6.8.0 pyinstaller pyinstaller.spec
```

## Credits

NotOnDeck is forked from [SteamDeckHomebrew/decky-loader](https://github.com/SteamDeckHomebrew/decky-loader).

The original plugin loader concept also builds on [marios8543's Steam Deck UI Inject project](https://github.com/marios8543/steamdeck-ui-inject).

Upstream Decky Loader remains the correct project for Steam Deck and SteamOS users.
