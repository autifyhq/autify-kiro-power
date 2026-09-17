#!/bin/bash
# Bring the testbox up: mirror the host's dev ports onto this container's own
# localhost, start a virtual screen a human can watch over noVNC, launch one
# Chrome, and install aximo-cli so `aximo device connect` can run in here.
set -euo pipefail

PORTS="${AXIMO_TESTBOX_PORTS:-3000}"
HOST_TARGET="${AXIMO_TESTBOX_HOST:-host.docker.internal}"
SCREEN="${AXIMO_TESTBOX_SCREEN:-1920x1080x24}"
NETWORK="${AXIMO_TESTBOX_NETWORK:-bridge}"
VNC_PORT="${AXIMO_TESTBOX_VNC_PORT:-5900}"
NOVNC_PORT="${AXIMO_TESTBOX_NOVNC_PORT:-6080}"
PROFILE=/profile
AXIMO_HOME_DIR="${AXIMO_HOME:-/root/.aximo}"
BLOCK_HOSTS="${AXIMO_TESTBOX_BLOCK_HOSTS:-}"

log() { echo "[aximo-testbox] $*"; }

supervise() {
  local label="$1"; shift
  while :; do
    "$@" || log "$label exited ($?), restarting"
    sleep 1
  done
}

expand_ports() {
  local spec=() item lo hi p
  IFS=',' read -ra spec <<< "$1"
  for item in "${spec[@]}"; do
    item="${item//[[:space:]]/}"
    [ -n "$item" ] || continue
    if [[ "$item" == *-* ]]; then
      lo="${item%%-*}"; hi="${item##*-}"
      for ((p = lo; p <= hi; p++)); do echo "$p"; done
    else
      echo "$item"
    fi
  done
}

if [ "$NETWORK" = bridge ] && ! getent hosts "$HOST_TARGET" >/dev/null; then
  log "FATAL: cannot resolve $HOST_TARGET (run with --add-host=host.docker.internal:host-gateway)"
  exit 1
fi

# aximo-cli is installed at start, not baked in, so the box always runs the
# current release. It goes into the npm cache volume, so it is fast after once.
install_aximo() {
  local spec="@autifyhq/aximo-cli@${AXIMO_VERSION:-latest}"
  log "installing $spec"
  if (cd /tmp && npm install -g --no-fund --no-audit "$spec") > /tmp/aximo-install.log 2>&1; then
    log "aximo $(aximo --version 2>/dev/null || true) ready"; echo ok > /tmp/aximo.status
  else
    log "WARNING: installing $spec failed, see /tmp/aximo-install.log"; echo failed > /tmp/aximo.status
  fi
}
rm -f /tmp/aximo.status
install_aximo &

# Production stays out of reach. The skill's "never test production" rule becomes
# something the browser refuses, not a sentence in a prompt.
if [ -n "$BLOCK_HOSTS" ]; then
  node -e 'const hosts=process.argv[1].split(",").map(s=>s.trim()).filter(Boolean);
    require("fs").writeFileSync("/etc/chromium/policies/managed/aximo-testbox-blocklist.json",
    JSON.stringify({URLBlocklist: hosts}))' "$BLOCK_HOSTS"
  log "blocked in the browser: $BLOCK_HOSTS"
fi

if [ "$NETWORK" = host ]; then
  log "host network: localhost here is the host's own, nothing to mirror"
else
  mapfile -t PORT_LIST < <(expand_ports "$PORTS")
  for p in "${PORT_LIST[@]}"; do
    # Same number on both sides so http://localhost:$p is the same origin the host
    # serves. Sign-in redirects registered for localhost keep matching.
    supervise "socat/$p" socat "TCP4-LISTEN:$p,fork,reuseaddr,bind=127.0.0.1" "TCP:$HOST_TARGET:$p" &
  done
  log "mirroring ${#PORT_LIST[@]} port(s) from the host: ${PORT_LIST[*]}"
fi

export DISPLAY=:99
export XAUTHORITY=/root/.Xauthority
: > "$XAUTHORITY"
xauth -f "$XAUTHORITY" add :99 MIT-MAGIC-COOKIE-1 "$(od -An -tx1 -N16 /dev/urandom | tr -dc 0-9a-f)"

supervise Xvfb Xvfb :99 -screen 0 "$SCREEN" &
for _ in $(seq 1 100); do xdpyinfo -display :99 >/dev/null 2>&1 && break; sleep 0.1; done
supervise fluxbox fluxbox &

# The live view always has a password. `aximo-testbox up` generates one and keeps it
# in the profile volume, so the link stays the same across restarts.
if [ ! -s "$PROFILE/.vncpass" ]; then
  mkdir -p "$PROFILE"; od -An -tx1 -N8 /dev/urandom | tr -dc 0-9a-f > "$PROFILE/.vncpass"
fi
x11vnc -storepasswd "$(cat "$PROFILE/.vncpass")" /root/.vncpasswd >/dev/null 2>&1
supervise x11vnc x11vnc -display :99 -forever -shared -rfbauth /root/.vncpasswd -rfbport "$VNC_PORT" -quiet &
supervise websockify websockify --web=/usr/share/novnc "0.0.0.0:$NOVNC_PORT" "localhost:$VNC_PORT" &

CHROME="$(ls -d /ms-playwright/chromium-*/chrome-linux/chrome 2>/dev/null | head -1 || true)"
[ -n "$CHROME" ] || { log "FATAL: no chromium under /ms-playwright"; exit 1; }
GEOMETRY="${SCREEN%x*}"; WINDOW_SIZE="${GEOMETRY%x*},${GEOMETRY#*x}"

mkdir -p "$PROFILE"
rm -f "$PROFILE"/SingletonLock "$PROFILE"/SingletonSocket "$PROFILE"/SingletonCookie
node -e 'const fs=require("fs"),p=process.argv[1];try{const j=JSON.parse(fs.readFileSync(p,"utf8"));if(j.profile){j.profile.exit_type="Normal";j.profile.exited_cleanly=true;fs.writeFileSync(p,JSON.stringify(j))}}catch{}' \
  "$PROFILE/Default/Preferences" 2>/dev/null || true

# No remote-debugging port on purpose: nothing but Aximo and the human drive this Chrome.
supervise chrome "$CHROME" \
  --user-data-dir="$PROFILE" --no-sandbox --no-first-run --no-default-browser-check \
  --password-store=basic --disable-background-networking \
  --window-position=0,0 --window-size="$WINDOW_SIZE" \
  "${AXIMO_TESTBOX_START_URL:-about:blank}" >> /tmp/chrome.log 2>&1 &

log "ready: noVNC on :$NOVNC_PORT"
exec "$@"
