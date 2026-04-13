#!/bin/bash
set -euo pipefail

TS_STATE_DIR="${TS_STATE_DIR:-/var/lib/tailscale}"
mkdir -p "$TS_STATE_DIR"

if [[ "${TS_SKIP:-false}" == "true" ]]; then
  exec "$@"
fi

if [[ -z "${TS_AUTHKEY:-}" ]]; then
  echo "ERROR: TS_AUTHKEY is not set. Create a pre-auth key in the Tailscale admin console (Settings → Keys), set TS_AUTHKEY, or set TS_SKIP=true to run without Tailscale." >&2
  exit 1
fi

echo "Starting tailscaled (userspace networking)..."
tailscaled --tun=userspace-networking --state="${TS_STATE_DIR}/tailscaled.state" &
# shellcheck disable=SC2034
TAILSCALED_PID=$!

# Wait for local API socket (tailscale status fails until after login)
SOCKET="${TAILSCALE_SOCKET:-/var/run/tailscale/tailscaled.sock}"
for _ in $(seq 1 120); do
  if [[ -S "$SOCKET" ]]; then
    break
  fi
  sleep 0.25
done

if [[ ! -S "$SOCKET" ]]; then
  echo "ERROR: tailscaled did not create ${SOCKET} in time." >&2
  exit 1
fi

HOSTNAME_ARGS=()
if [[ -n "${TS_HOSTNAME:-}" ]]; then
  HOSTNAME_ARGS=(--hostname="$TS_HOSTNAME")
fi

# TS_EXTRA_ARGS: optional extra flags for tailscale up (e.g. --advertise-tags=tag:worker)
echo "Connecting to Tailscale..."
# shellcheck disable=SC2086
tailscale up --authkey="$TS_AUTHKEY" "${HOSTNAME_ARGS[@]}" ${TS_EXTRA_ARGS:-}

tailscale status

# exec replaces this shell with the app; tailscaled remains a child of PID 1
exec "$@"
