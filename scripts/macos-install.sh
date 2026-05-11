#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_ROOT="${DECKY_INSTALL_ROOT:-"${HOME}/Library/Application Support/decky-loader"}"
BIN_DIR="${INSTALL_ROOT}/bin"
HOMEBREW_DIR="${UNPRIVILEGED_PATH:-"${INSTALL_ROOT}/homebrew"}"
LOG_DIR="${INSTALL_ROOT}/logs"
STEAM_ROOT="${STEAM_ROOT:-"${HOME}/Library/Application Support/Steam"}"
STEAM_EXE="${STEAM_EXECUTABLE:-}"
LABEL="xyz.decky.loader"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
LAUNCHD_TARGET="gui/$(id -u)"

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

enable_steam_cef() {
  local steam_exe steam_dir
  steam_exe="$(find_steam_exe)"
  steam_dir="$(dirname "${steam_exe}")"

  if [[ ! -d "${steam_dir}" ]]; then
    printf 'Steam executable directory does not exist: %s\n' "${steam_dir}" >&2
    return 1
  fi

  touch "${steam_dir}/.cef-enable-remote-debugging"
}

install_files() {
  local source_binary="${ROOT_DIR}/backend/dist/PluginLoader"

  if [[ ! -x "${source_binary}" ]]; then
    printf 'missing built loader: %s\n' "${source_binary}" >&2
    printf 'build it first with: cd backend && uv run --no-project --python 3.11 --with-editable . --with pyinstaller==6.8.0 pyinstaller pyinstaller.spec\n' >&2
    return 1
  fi

  mkdir -p \
    "${BIN_DIR}" \
    "${HOMEBREW_DIR}/plugins" \
    "${HOMEBREW_DIR}/settings" \
    "${HOMEBREW_DIR}/data" \
    "${HOMEBREW_DIR}/logs" \
    "${LOG_DIR}" \
    "${HOME}/Library/LaunchAgents"

  cp "${source_binary}" "${BIN_DIR}/PluginLoader"
  chmod 755 "${BIN_DIR}/PluginLoader"

  cat > "${BIN_DIR}/decky-loader-env.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail

export UNPRIVILEGED_PATH="${HOMEBREW_DIR}"
export PRIVILEGED_PATH="${HOMEBREW_DIR}"
export CHOWN_PLUGIN_PATH="0"
export SERVER_HOST="127.0.0.1"
export SERVER_PORT="1337"
export LIVE_RELOAD="0"

cd "${BIN_DIR}"
exec "${BIN_DIR}/PluginLoader"
EOF
  chmod 755 "${BIN_DIR}/decky-loader-env.sh"
}

install_launch_agent() {
  cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${BIN_DIR}/decky-loader-env.sh</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${BIN_DIR}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/loader.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/loader.stderr.log</string>
</dict>
</plist>
EOF

  plutil -lint "${PLIST_PATH}" >/dev/null
}

load_launch_agent() {
  launchctl bootout "${LAUNCHD_TARGET}" "${PLIST_PATH}" >/dev/null 2>&1 || true
  launchctl bootstrap "${LAUNCHD_TARGET}" "${PLIST_PATH}"
  launchctl enable "${LAUNCHD_TARGET}/${LABEL}"
  launchctl kickstart -k "${LAUNCHD_TARGET}/${LABEL}"
}

wait_for_backend() {
  local i
  for i in {1..30}; do
    if curl -fsS http://127.0.0.1:1337/auth/token >/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

uninstall() {
  launchctl bootout "${LAUNCHD_TARGET}" "${PLIST_PATH}" >/dev/null 2>&1 || true
  rm -f "${PLIST_PATH}"
  rm -rf "${BIN_DIR}"
}

status() {
  printf 'install root: %s\n' "${INSTALL_ROOT}"
  printf 'homebrew dir: %s\n' "${HOMEBREW_DIR}"
  printf 'steam exe: %s\n' "$(find_steam_exe)"
  printf 'launch agent: %s\n' "${PLIST_PATH}"

  if launchctl print "${LAUNCHD_TARGET}/${LABEL}" >/dev/null 2>&1; then
    printf 'LaunchAgent: loaded\n'
  else
    printf 'LaunchAgent: not loaded\n'
  fi

  if pgrep -f "${BIN_DIR}/PluginLoader" >/dev/null; then
    printf 'Decky loader: running\n'
  else
    printf 'Decky loader: not running\n'
  fi

  if curl -fsS http://127.0.0.1:1337/auth/token >/dev/null; then
    printf 'Decky backend: reachable\n'
  else
    printf 'Decky backend: not reachable\n'
  fi

  if curl -fsS http://127.0.0.1:8080/json >/dev/null; then
    printf 'Steam CEF debugger: reachable\n'
  else
    printf 'Steam CEF debugger: not reachable\n'
  fi
}

install() {
  install_files
  enable_steam_cef
  install_launch_agent
  load_launch_agent
  wait_for_backend || true
  status
}

case "${1:-install}" in
  install)
    install
    ;;
  uninstall)
    uninstall
    ;;
  restart)
    load_launch_agent
    ;;
  status)
    status
    ;;
  *)
    printf 'usage: %s [install|uninstall|restart|status]\n' "$0" >&2
    exit 2
    ;;
esac
