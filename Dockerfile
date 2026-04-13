# Wrapper around the official AudioMuse-AI image: adds Tailscale for tailnet connectivity.
# Build: docker build -t audiomuse-worker-tailscale .
# Upstream: https://github.com/NeptuneHub/AudioMuse-AI

ARG AUDIOUSE_IMAGE=ghcr.io/neptunehub/audiomuse-ai:latest
FROM ${AUDIOUSE_IMAGE}

USER root

# Ubuntu 24.04 (noble) — matches upstream AudioMuse Dockerfile
RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends curl ca-certificates; \
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg; \
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list; \
  apt-get update; \
  apt-get install -y --no-install-recommends tailscale; \
  apt-get purge -y curl; \
  apt-get autoremove -y; \
  rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# Same CMD as upstream: timezone setup, then worker (supervisord) or flask (gunicorn)
CMD ["bash", "-c", "if [ -n \"$TZ\" ] && [ -f \"/usr/share/zoneinfo/$TZ\" ]; then ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone; elif [ -n \"$TZ\" ]; then echo \"Warning: timezone '$TZ' not found in /usr/share/zoneinfo\" >&2; fi; if [ \"$SERVICE_TYPE\" = \"worker\" ]; then echo 'Starting worker processes via supervisord...' && /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf; else echo 'Starting web service...' && gunicorn --bind 0.0.0.0:8000 --workers 1 --timeout 300 app:app; fi"]
