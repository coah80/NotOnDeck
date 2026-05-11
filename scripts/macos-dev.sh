#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STEAM_ROOT="${STEAM_ROOT:-"${HOME}/Library/Application Support/Steam"}"
HOMEBREW_DIR="${UNPRIVILEGED_PATH:-"${HOME}/Library/Application Support/decky-loader/homebrew"}"
STEAM_EXE="${STEAM_EXECUTABLE:-}"

find_steam_exe() {
  if [[ -n "${STEAM_EXE}" && -x "${STEAM_EXE}" ]]; then
    printf '%s\n' "${STEAM_EXE}"
    return
  fi

  local steam_appbundle="${STEAM_ROOT}/Steam.AppBundle/Steam/Contents/MacOS/steam_osx"
  if [[ -x "${steam_appbundle}" ]]; then
    printf '%s\n' "${steam_appbundle}"
    return
  fi

  printf '%s\n' "/Applications/Steam.app/Contents/MacOS/steam_osx"
}

setup_dirs() {
  mkdir -p \
    "${HOMEBREW_DIR}/plugins" \
    "${HOMEBREW_DIR}/settings" \
    "${HOMEBREW_DIR}/data" \
    "${HOMEBREW_DIR}/logs"
}

enable_cef_debug_file() {
  local steam_exe steam_dir
  steam_exe="$(find_steam_exe)"
  steam_dir="$(dirname "${steam_exe}")"
  touch "${steam_dir}/.cef-enable-remote-debugging"
  printf 'enabled Steam CEF debugging marker at %s\n' "${steam_dir}/.cef-enable-remote-debugging"
}

launch_steam() {
  local steam_exe
  steam_exe="$(find_steam_exe)"

  if pgrep -x steam_osx >/dev/null; then
    printf 'Steam is already running. Quit Steam first, then rerun this command so debug flags are applied.\n' >&2
    return 1
  fi

  enable_cef_debug_file
  exec "${steam_exe}" -cef-enable-debugging -devtools-port 8080 -skipinitialbootstrap -gamepadui "$@"
}

run_loader() {
  setup_dirs
  if [[ ! -f "${ROOT_DIR}/backend/decky_loader/static/index.js" ]]; then
    printf 'missing backend/decky_loader/static/index.js; build the frontend first with `cd frontend && pnpm i && pnpm run build`.\n' >&2
    return 1
  fi

  export UNPRIVILEGED_PATH="${HOMEBREW_DIR}"
  export PRIVILEGED_PATH="${HOMEBREW_DIR}"
  export CHOWN_PLUGIN_PATH="${CHOWN_PLUGIN_PATH:-0}"
  export SERVER_HOST="${SERVER_HOST:-127.0.0.1}"
  export SERVER_PORT="${SERVER_PORT:-1337}"
  export LIVE_RELOAD="${LIVE_RELOAD:-1}"

  if command -v uv >/dev/null; then
    exec uv run --no-project --python 3.11 --with-editable "${ROOT_DIR}/backend" python "${ROOT_DIR}/backend/main.py"
  fi

  cd "${ROOT_DIR}/backend"
  exec python3 main.py
}

doctor() {
  setup_dirs
  enable_cef_debug_file
  printf 'homebrew dir: %s\n' "${HOMEBREW_DIR}"
  printf 'steam exe: %s\n' "$(find_steam_exe)"

  if curl -fsS http://localhost:8080/json >/dev/null; then
    printf 'Steam CEF debugger: reachable\n'
  else
    printf 'Steam CEF debugger: not reachable on http://localhost:8080/json\n'
  fi

  if curl -fsS http://localhost:1337/auth/token >/dev/null; then
    printf 'NotOnDeck backend: reachable\n'
  else
    printf 'NotOnDeck backend: not reachable on http://localhost:1337/auth/token\n'
  fi
}

case "${1:-doctor}" in
  doctor)
    doctor
    ;;
  launch-steam)
    shift
    launch_steam "$@"
    ;;
  run-loader)
    run_loader
    ;;
  setup)
    setup_dirs
    enable_cef_debug_file
    ;;
  *)
    printf 'usage: %s [doctor|setup|launch-steam|run-loader]\n' "$0" >&2
    exit 2
    ;;
esac
