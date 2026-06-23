#!/usr/bin/env bash
# Bring an isolated REDCap stack up or down for a single test shard.
#
#   ./shard-stack.sh up   <k>   # start cctc-shard-<k> on offset ports, wait until ready
#   ./shard-stack.sh down <k>   # stop it and remove its volumes
#
# Each shard is its own Compose project (cctc-shard-<k>) with offset ports
# (shard-env.sh) and the multi-instance override (docker-compose.ci-shard.yml),
# so several can run at once without colliding. `down` uses `-v`: a shard's data
# is disposable per run, matching CI's fresh-stack-per-job semantics.
#
# This NEVER touches the developer's primary stack: it only ever acts on Compose
# projects named cctc-shard-*.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CMD="${1:-}"
K="${2:-}"

usage() { echo "usage: $0 up|down <shard-index>" >&2; exit 2; }
[ -n "$CMD" ] && [ -n "$K" ] || usage
case "$K" in ''|*[!0-9]*) usage ;; esac

# shellcheck source=shard-env.sh
source "$HERE/shard-env.sh" "$K"

ENVFILE="$HERE/.env.shard-$K"
COMPOSE=(docker compose -p "$SHARD_PROJECT" --env-file "$ENVFILE"
         -f "$HERE/docker-compose.yml" -f "$HERE/docker-compose.ci-shard.yml")

build_envfile() {
  # Keep every non-port setting from .env.example, then append this shard's
  # offset ports + project name so Compose interpolation picks them up.
  grep -vE '^(REDCAP_HTTP_PORT|REDCAP_HTTPS_PORT|MYSQL_PORT|MAILHOG_SMTP_PORT|MAILHOG_UI_PORT)=' \
    "$HERE/.env.example" > "$ENVFILE"
  {
    echo "REDCAP_HTTP_PORT=$REDCAP_HTTP_PORT"
    echo "REDCAP_HTTPS_PORT=$REDCAP_HTTPS_PORT"
    echo "MYSQL_PORT=$MYSQL_PORT"
    echo "MAILHOG_SMTP_PORT=$MAILHOG_SMTP_PORT"
    echo "MAILHOG_UI_PORT=$MAILHOG_UI_PORT"
    echo "SHARD_PROJECT=$SHARD_PROJECT"
  } >> "$ENVFILE"
}

case "$CMD" in
  up)
    build_envfile
    echo "== $SHARD_PROJECT up (HTTPS :$REDCAP_HTTPS_PORT, MYSQL :$MYSQL_PORT) =="
    "${COMPOSE[@]}" up -d
    echo "== waiting for REDCap on https://localhost:$REDCAP_HTTPS_PORT =="
    for _ in $(seq 1 80); do
      code=$(curl -k -s -o /dev/null -w '%{http_code}' "https://localhost:$REDCAP_HTTPS_PORT" 2>/dev/null || true)
      if [ "$code" = "200" ] || [ "$code" = "302" ]; then
        echo "== $SHARD_PROJECT ready (HTTP $code) =="
        exit 0
      fi
      sleep 3
    done
    echo "ERROR: $SHARD_PROJECT not ready on :$REDCAP_HTTPS_PORT after ~240s" >&2
    exit 1
    ;;
  down)
    [ -f "$ENVFILE" ] || build_envfile
    echo "== $SHARD_PROJECT down -v =="
    "${COMPOSE[@]}" down -v
    rm -f "$ENVFILE"
    ;;
  *)
    usage
    ;;
esac
