# NotOnDeck macOS Development

NotOnDeck can run on macOS as a local development target. This is still
experimental: some Decky-compatible plugins may assume systemd, Gamescope, Linux
paths, root access, or Steam Deck hardware.

## Layout

By default, the macOS backend stores NotOnDeck data under:

```text
~/Library/Application Support/decky-loader/homebrew
```

Override it with `UNPRIVILEGED_PATH` and `PRIVILEGED_PATH` when needed.

## Running Locally

Build the frontend first:

```sh
cd frontend
pnpm i
pnpm run build
```

Start Steam with CEF debugging and Gamepad UI:

```sh
./scripts/macos-dev.sh launch-steam
```

Steam must be fully quit before running that command so the debug flags are used.
The expected debugger endpoint is:

```text
http://localhost:8080/json
```

Start the NotOnDeck backend:

```sh
./scripts/macos-dev.sh run-loader
```

If `uv` is installed, the script runs the backend from an isolated environment
with the local package installed editable. Without `uv`, install the backend
dependencies first and the script will fall back to `python3 main.py`.

Check both local endpoints:

```sh
./scripts/macos-dev.sh doctor
```

## Installing Locally

Build the frontend and backend binary, then install the LaunchAgent:

```sh
npx --yes pnpm@10.20.0 --dir frontend i --frozen-lockfile --dangerously-allow-all-builds
npx --yes pnpm@10.20.0 --dir frontend run build
cd backend
uv run --no-project --python 3.11 --with-editable . --with pyinstaller==6.8.0 pyinstaller pyinstaller.spec
cd ..
./scripts/macos-install.sh install
```

The installer copies the built loader to:

```text
~/Library/Application Support/decky-loader/bin/PluginLoader
```

It also creates the Steam CEF debugging marker next to `steam_osx` and loads the
user LaunchAgent at:

```text
~/Library/LaunchAgents/xyz.decky.loader.plist
```

Useful commands:

```sh
./scripts/macos-install.sh status
./scripts/macos-install.sh restart
./scripts/macos-install.sh uninstall
```

## Current Limits

- The remote debugging and SSH settings are no-ops on macOS.
- Linux-only plugins need platform metadata before the store should expose them
  on macOS.
