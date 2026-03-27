#!/bin/bash
set -e

# ─── Config from environment ───────────────────────────────────────────────────────
DB_HOST="${DB_HOST:-mariadb}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-root}"
DB_NAME="${DB_NAME:-erpnext}"
DB_USER="${DB_USER:-frappe}"
DB_PASSWORD="${DB_PASSWORD:-frappe123}"
SITE_NAME="${SITE_NAME:-site.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Admin123!}"
REDIS_URL="${REDIS_URL:-redis://redis:6379}"

# Custom ERPNext app repo (quanteonlab/erp15)
ERPNEXT_REPO="${ERPNEXT_REPO:-https://github.com/quanteonlab/erp15.git}"
ERPNEXT_BRANCH="${ERPNEXT_BRANCH:-main}"

cd /home/frappe

# ─── Wait for MariaDB ─────────────────────────────────────────────────────────────
echo "Waiting for MariaDB at $DB_HOST..."
until mysql -h"$DB_HOST" -uroot -p"$DB_ROOT_PASSWORD" -e "SELECT 1;" &>/dev/null; do
    echo "  Still waiting for MariaDB..."
    sleep 3
done
echo "MariaDB is ready."

# ─── Wait for Redis ───────────────────────────────────────────────────────────────
REDIS_HOST=$(echo "$REDIS_URL" | sed 's|redis://||' | cut -d: -f1)
REDIS_PORT=$(echo "$REDIS_URL" | sed 's|redis://||' | cut -d: -f2)
echo "Waiting for Redis at $REDIS_HOST:$REDIS_PORT..."
until redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping &>/dev/null 2>&1; do
    echo "  Still waiting for Redis..."
    sleep 2
done
echo "Redis is ready."

# ─── Ensure MariaDB user exists ──────────────────────────────────────────────────────
mysql -h"$DB_HOST" -uroot -p"$DB_ROOT_PASSWORD" <<-EOSQL
    CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
EOSQL

# ─── First-time bench initialisation ───────────────────────────────────────────────────
if [ ! -d "frappe-bench" ]; then
    echo "Initialising bench (first run)..."

    bench init frappe-bench \
        --frappe-branch version-15 \
        --python python3.11

    cd frappe-bench

    # Configure Redis
    bench set-config -g redis_cache      "$REDIS_URL"
    bench set-config -g redis_queue      "$REDIS_URL"
    bench set-config -g redis_socketio   "$REDIS_URL"

    # Create site
    bench new-site "$SITE_NAME" \
        --admin-password  "$ADMIN_PASSWORD" \
        --db-host         "$DB_HOST" \
        --db-name         "$DB_NAME" \
        --db-password     "$DB_PASSWORD" \
        --mariadb-root-username root \
        --mariadb-root-password "$DB_ROOT_PASSWORD"

    bench use "$SITE_NAME"

    # Install custom ERPNext app (latest commit on the branch)
    echo "Installing ERPNext custom app from $ERPNEXT_REPO @ $ERPNEXT_BRANCH..."
    bench get-app erpnext "$ERPNEXT_REPO" --branch "$ERPNEXT_BRANCH"
    bench --site "$SITE_NAME" install-app erpnext

    bench build

else
    # ─── Update on every restart ────────────────────────────────────────────────────────
    cd frappe-bench

    echo "Pulling latest ERPNext custom app from $ERPNEXT_BRANCH..."
    cd apps/erpnext
    git fetch origin
    git reset --hard origin/"$ERPNEXT_BRANCH"
    cd ../..

    echo "Running migrations..."
    bench --site "$SITE_NAME" migrate

    bench build --app erpnext
fi

bench use "$SITE_NAME"
exec bench start
