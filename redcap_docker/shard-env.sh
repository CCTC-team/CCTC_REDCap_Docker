#!/usr/bin/env bash
# Source this with a shard index to get that shard's project name and an isolated
# set of host ports:  source shard-env.sh <k>
#
# All five host ports are offset by (k-1)*100 from the defaults so up to ~40
# shards never collide. The port math lives ONLY here — both the stack-up helper
# and the runner-env builder source this so the two can never drift.
#
#   shard 1: HTTPS 8443  HTTP 8080  MYSQL 3400  SMTP 1025  UI 8025
#   shard 2: HTTPS 8543  HTTP 8180  MYSQL 3500  SMTP 1125  UI 8125
#   shard 3: HTTPS 8643  ...
k="${1:?shard index required (e.g. source shard-env.sh 2)}"
case "$k" in
  ''|*[!0-9]*) echo "shard-env.sh: shard index must be a positive integer, got '$k'" >&2; return 1 2>/dev/null || exit 1 ;;
esac

_off=$(( (k - 1) * 100 ))
export SHARD_INDEX="$k"
export SHARD_PROJECT="cctc-shard-$k"
export REDCAP_HTTP_PORT=$(( 8080 + _off ))
export REDCAP_HTTPS_PORT=$(( 8443 + _off ))
export MYSQL_PORT=$(( 3400 + _off ))
export MAILHOG_SMTP_PORT=$(( 1025 + _off ))
export MAILHOG_UI_PORT=$(( 8025 + _off ))
