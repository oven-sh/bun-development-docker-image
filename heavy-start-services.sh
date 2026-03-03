#!/bin/bash
# Shared service startup for :heavy-based agent containers.
#
# Source this from your entrypoint:
#   source /opt/start-services.sh
#
# Or call it:
#   /opt/start-services.sh && exec your-thing
#
# Env knobs:
#   SKIP_DBS    — if set, skip database startup
#   GH_TOKEN    — if set, configure git + gh CLI auth
#   GIT_USER    — git user.name  (default: robobun)
#   GIT_EMAIL   — git user.email (default: robobun@oven.sh)

set -uo pipefail

_log() { echo "[start-services] $*" >&2; }

# --- databases ---------------------------------------------------------------

if [[ -z "${SKIP_DBS:-}" ]]; then
  _log "starting postgres"
  PG_VERSION=$(ls -1 /usr/lib/postgresql | sort -V | tail -1)
  su postgres -c "/usr/lib/postgresql/$PG_VERSION/bin/pg_ctl -D /var/lib/postgresql/data -l /tmp/pg.log start" \
    || _log "postgres start failed (continuing)"

  _log "starting mariadb"
  mysqld_safe --user=mysql --datadir=/var/lib/mysql > /tmp/mysql.log 2>&1 &

  _log "starting redis"
  redis-server --daemonize yes --logfile /tmp/redis.log \
    || _log "redis start failed (continuing)"
else
  _log "SKIP_DBS set — skipping database startup"
fi

# --- git auth ----------------------------------------------------------------

if [[ -n "${GH_TOKEN:-}" ]]; then
  _log "configuring git auth"
  git config --global user.name "${GIT_USER:-robobun}"
  git config --global user.email "${GIT_EMAIL:-robobun@oven.sh}"
  git config --global url."https://x-access-token:${GH_TOKEN}@github.com/".insteadOf "https://github.com/"
  echo "$GH_TOKEN" | gh auth login --with-token 2>/dev/null || _log "gh auth login failed (continuing)"
else
  _log "no GH_TOKEN — git auth skipped"
fi

_log "services ready"
