#!/bin/bash
# Entrypoint for the on-demand erpnext-dev service (erp.test / localhost:1271).
#
# Unlike entrypoint.sh (production), this does NOT git-fetch/reset apps/erpnext —
# that directory is bind-mounted from the host checkout here, so a git reset
# would blow away whatever you're currently editing. It also uses its own site
# ("dev.local") and DB name on the same shared MariaDB server, and a separate
# Redis logical DB, so it never touches production data or queues.
set -e

DB_HOST="${DB_HOST:-mariadb}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-frappe_root}"
DB_NAME="${DB_NAME:-erpnext_dev}"
DB_PASSWORD="${DB_PASSWORD:-frappe123dev}"
SITE_NAME="${SITE_NAME:-dev.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Admin123!}"
REDIS_URL="${REDIS_URL:-redis://redis:6379/1}"

BENCH_DIR="/home/frappe/frappe-bench"
cd "$BENCH_DIR"

echo "Waiting for MariaDB..."
until mysql -h"$DB_HOST" -uroot -p"$DB_ROOT_PASSWORD" -e "SELECT 1;" &>/dev/null; do
    sleep 3
done
echo "MariaDB ready."

REDIS_HOST=$(echo "$REDIS_URL" | sed 's|redis://||;s|:.*||')
REDIS_PORT=$(echo "$REDIS_URL" | sed 's|redis://[^:]*:||;s|/.*||')
echo "Waiting for Redis at $REDIS_HOST:$REDIS_PORT..."
until redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping &>/dev/null; do sleep 2; done
echo "Redis ready."

sudo chown -R frappe:frappe sites/ 2>/dev/null || true
# apps/erpnext is bind-mounted from the host (owned by host root) — chown so
# the frappe user can write __pycache__/build output without failing.
sudo chown -R frappe:frappe apps/erpnext 2>/dev/null || true

COMMON_CFG="sites/common_site_config.json"
[ -f "$COMMON_CFG" ] || echo '{}' > "$COMMON_CFG"
python3 - <<PYEOF
import json
with open("$COMMON_CFG") as f: cfg = json.load(f)
cfg.update({"redis_cache": "$REDIS_URL", "redis_queue": "$REDIS_URL", "redis_socketio": "$REDIS_URL"})
with open("$COMMON_CFG", "w") as f: json.dump(cfg, f, indent=2)
PYEOF

if [ ! -d "sites/$SITE_NAME" ]; then
    echo "Creating dev site $SITE_NAME (DB '$DB_NAME' on the shared MariaDB server, separate from production)..."
    bench new-site "$SITE_NAME" \
        --admin-password "$ADMIN_PASSWORD" \
        --db-host "$DB_HOST" \
        --db-name "$DB_NAME" \
        --db-password "$DB_PASSWORD" \
        --mariadb-root-username root \
        --mariadb-root-password "$DB_ROOT_PASSWORD" \
        --install-app erpnext
fi

bench use "$SITE_NAME"
bench --site "$SITE_NAME" migrate

exec bench start
