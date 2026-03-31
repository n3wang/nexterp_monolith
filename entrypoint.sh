#!/bin/bash
set -e

# ─── Config ───────────────────────────────────────────────────────────────────
DB_HOST="${DB_HOST:-mariadb}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-frappe_root}"
DB_NAME="${DB_NAME:-erpnext}"
DB_PASSWORD="${DB_PASSWORD:-frappe123}"
SITE_NAME="${SITE_NAME:-site.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Admin123!}"
REDIS_URL="${REDIS_URL:-redis://redis:6379}"
ERPNEXT_REPO="${ERPNEXT_REPO:-https://github.com/quanteonlab/erp15.git}"
ERPNEXT_BRANCH="${ERPNEXT_BRANCH:-main}"

BENCH_DIR="/home/frappe/frappe-bench"
cd "$BENCH_DIR"

# ─── Wait for MariaDB ─────────────────────────────────────────────────────────
echo "Waiting for MariaDB..."
until mysql -h"$DB_HOST" -uroot -p"$DB_ROOT_PASSWORD" -e "SELECT 1;" &>/dev/null; do
    sleep 3
done
echo "MariaDB ready."

# ─── Wait for Redis ───────────────────────────────────────────────────────────
REDIS_HOST=$(echo "$REDIS_URL" | sed 's|redis://||;s|:.*||')
REDIS_PORT=$(echo "$REDIS_URL" | sed 's|.*:||')
echo "Waiting for Redis at $REDIS_HOST:$REDIS_PORT..."
until redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping &>/dev/null; do sleep 2; done
echo "Redis ready."

# ─── Fix sites/ volume ownership (Docker creates it as root) ─────────────────
sudo chown -R frappe:frappe sites/ 2>/dev/null || true

# ─── Configure external Redis in common_site_config.json (idempotent) ────────
COMMON_CFG="sites/common_site_config.json"
[ -f "$COMMON_CFG" ] || echo '{}' > "$COMMON_CFG"
python3 - <<PYEOF
import json
with open("$COMMON_CFG") as f: cfg = json.load(f)
cfg.update({"redis_cache": "$REDIS_URL", "redis_queue": "$REDIS_URL", "redis_socketio": "$REDIS_URL"})
with open("$COMMON_CFG", "w") as f: json.dump(cfg, f, indent=2)
PYEOF

# ─── Create site if DB schema is not ready ────────────────────────────────────
# Check for tabDocType — created early in frappe's schema migration
DB_READY=false
mysql -h"$DB_HOST" -uroot -p"$DB_ROOT_PASSWORD" \
    -e "SELECT 1 FROM information_schema.tables \
        WHERE table_schema='${DB_NAME}' AND table_name='tabDocType' LIMIT 1;" \
    2>/dev/null | grep -q 1 && DB_READY=true

if [ "$DB_READY" = false ]; then
    echo "Creating site $SITE_NAME..."
    # If DB user exists from a previous run with a different password, reset it
    mysql -h"$DB_HOST" -uroot -p"$DB_ROOT_PASSWORD" \
        -e "ALTER USER IF EXISTS '${DB_NAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';" \
        2>/dev/null || true
    # --force drops any stale DB/user before recreating
    rm -rf "sites/$SITE_NAME"
    bench new-site "$SITE_NAME" \
        --force \
        --admin-password  "$ADMIN_PASSWORD" \
        --db-host         "$DB_HOST" \
        --db-name         "$DB_NAME" \
        --db-password     "$DB_PASSWORD" \
        --mariadb-root-username root \
        --mariadb-root-password "$DB_ROOT_PASSWORD"
fi

bench use "$SITE_NAME"

# Ensure apps required by installed sites are importable before migrate.
ensure_shim_app() {
    local app="$1"
    if [ -d "apps/${app}" ]; then
        return
    fi

    echo "${app} app missing - creating local shim..."
    mkdir -p "apps/${app}/${app}"
    cat > "apps/${app}/setup.py" <<PYEOF
from setuptools import setup, find_packages

setup(
    name="${app}",
    version="0.0.1",
    description="Compatibility shim for installed app ${app}",
    packages=find_packages(),
    include_package_data=True,
)
PYEOF
    echo "__version__ = \"0.0.1\"" > "apps/${app}/${app}/__init__.py"
    cat > "apps/${app}/${app}/hooks.py" <<PYEOF
app_name = "${app}"
app_title = "${app}"
app_publisher = "local"
app_description = "Compatibility shim for installed app"
app_email = "noreply@example.com"
app_license = "MIT"
PYEOF
    /home/frappe/frappe-bench/env/bin/pip install -e "apps/${app}" -q
}

if [ ! -d "apps/ecommerce_integrations" ]; then
    echo "ecommerce_integrations app missing - installing..."
    bench get-app ecommerce_integrations https://github.com/frappe/ecommerce_integrations.git --branch develop
fi

if [ ! -d "apps/payments" ]; then
    echo "payments app missing - installing..."
    bench get-app payments https://github.com/frappe/payments.git --branch develop
fi

if [ ! -d "apps/webshop" ]; then
    echo "webshop app missing - installing..."
    bench get-app webshop https://github.com/frappe/webshop.git --branch develop
fi

ensure_shim_app "airplane_mode_2"
ensure_shim_app "rentals"

# ─── Install or update the ERPNext app ───────────────────────────────────────
if bench --site "$SITE_NAME" list-apps 2>/dev/null | grep -q erpnext; then
    echo "ERPNext already installed — pulling latest + migrating..."
    git -C apps/erpnext fetch "$ERPNEXT_REPO" "$ERPNEXT_BRANCH" 2>/dev/null || true
    git -C apps/erpnext reset --hard FETCH_HEAD 2>/dev/null || true
    bench --site "$SITE_NAME" migrate
else
    echo "Installing ERPNext..."
    bench --site "$SITE_NAME" install-app erpnext
fi

exec bench start
