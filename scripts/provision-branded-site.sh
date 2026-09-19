#!/usr/bin/env bash
# Provision a branded Frappe site from zero on the shared erpnext bench.
#
# Usage (host):
#   docker compose exec -T erpnext bash -s -- meilu.local erpnext_meilu 'Pass!' \
#     < scripts/provision-branded-site.sh
#
# Or copy into the container and run.
set -euo pipefail

SITE_NAME="${1:?site name required (e.g. meilu.local)}"
DB_NAME="${2:?db name required (e.g. erpnext_meilu)}"
ADMIN_PASSWORD="${3:-BrandAdmin!2026}"
ITEM_COUNT="${ITEM_COUNT:-40}"

BENCH_DIR="${BENCH_DIR:-/home/frappe/frappe-bench}"
cd "$BENCH_DIR"
mkdir -p /home/frappe/logs "$BENCH_DIR/logs" "sites/${SITE_NAME}/logs" || true

# Prefer absolute sites path for raw python (avoids wrong ./SITE/logs)
SITES_PATH="${BENCH_DIR}/sites"

DB_HOST="${DB_HOST:-mariadb}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:?DB_ROOT_PASSWORD required}"
DB_PASSWORD="${DB_PASSWORD:-frappe123}"
CREDS_OUT="${CREDS_OUT:-/tmp/site-credentials-${SITE_NAME}.json}"

echo "==> Provisioning site=${SITE_NAME} db=${DB_NAME}"

if [ -d "sites/${SITE_NAME}" ]; then
  echo "    Site folder exists — skipping new-site"
else
  echo "==> bench new-site ${SITE_NAME}"
  mysql -h"$DB_HOST" -uroot -p"$DB_ROOT_PASSWORD" \
    -e "ALTER USER IF EXISTS '${DB_NAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';" \
    2>/dev/null || true

  bench new-site "$SITE_NAME" \
    --force \
    --admin-password "$ADMIN_PASSWORD" \
    --db-host "$DB_HOST" \
    --db-name "$DB_NAME" \
    --db-password "$DB_PASSWORD" \
    --mariadb-root-username root \
    --mariadb-root-password "$DB_ROOT_PASSWORD" \
    --no-mariadb-socket
fi

install_if_missing() {
  local app="$1"
  if bench --site "$SITE_NAME" list-apps 2>/dev/null | awk '{print $1}' | grep -qx "$app"; then
    echo "    App already installed: $app"
  else
    echo "==> Installing app: $app"
    bench --site "$SITE_NAME" install-app "$app"
  fi
}

install_if_missing erpnext
install_if_missing payments || echo "    WARN: payments install failed (continuing)"
install_if_missing webshop || echo "    WARN: webshop install failed (continuing)"
install_if_missing ecommerce_integrations || echo "    WARN: ecommerce_integrations install failed (continuing)"

echo "==> Migrating (Tier 1 defaults)"
bench --site "$SITE_NAME" migrate

echo "==> Completing ERPNext setup wizard (company + chart of accounts)"
COMPANY_NAME="${COMPANY_NAME:-${SITE_NAME%%.*}}"
COMPANY_ABBR="$(echo "$COMPANY_NAME" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z' | head -c 3)"
COMPANY_ABBR="${COMPANY_ABBR:-BR}"
./env/bin/python - <<PY
import frappe
from datetime import datetime
from frappe.desk.page.setup_wizard.setup_wizard import setup_complete

frappe.init(site="${SITE_NAME}", sites_path="sites")
frappe.connect()
frappe.set_user("Administrator")
if frappe.db.a_row_exists("Company"):
    print("Company already exists — skipping setup_complete")
else:
    year = datetime.now().year
    setup_complete({
        "currency": "USD",
        "full_name": "Administrator",
        "company_name": "${COMPANY_NAME}".title(),
        "timezone": "America/Argentina/Buenos_Aires",
        "company_abbr": "${COMPANY_ABBR}",
        "industry": "Retail",
        "country": "Argentina",
        "fy_start_date": f"{year}-01-01",
        "fy_end_date": f"{year}-12-31",
        "language": "english",
        "company_tagline": "${COMPANY_NAME}",
        "email": "admin@${SITE_NAME}",
        "password": "${ADMIN_PASSWORD}",
        "chart_of_accounts": "Standard",
    })
    frappe.db.commit()
    print("setup_complete finished for ${COMPANY_NAME}")
PY

echo "==> Ensuring starter staff groups (Tier 3)"
./env/bin/python - <<PY
import frappe
frappe.init(site="${SITE_NAME}", sites_path="sites")
frappe.connect()
frappe.set_user("Administrator")
from erpnext.erpnext_integrations.ecommerce_api.employee_api import ensure_starter_staff_groups
print(ensure_starter_staff_groups())
frappe.db.commit()
PY

echo "==> Seeding initial demo dataset"
./env/bin/python - <<PY
import frappe, json
frappe.init(site="${SITE_NAME}", sites_path="sites")
frappe.connect()
frappe.set_user("Administrator")
from erpnext.erpnext_integrations.ecommerce_api.seed_full_erpnext_test_data import run
result = run(item_count=${ITEM_COUNT}, disabled_count=3, stock_item_ratio=0.75)
frappe.db.commit()
print(json.dumps(result, default=str)[:2000])
PY

echo "==> Generating Administrator API keys"
./env/bin/python - <<PY
import json
import frappe
from frappe.core.doctype.user.user import generate_keys

frappe.init(site="${SITE_NAME}", sites_path="sites")
frappe.connect()
keys = generate_keys("Administrator")
# Also ensure password is the one we expect (idempotent for re-runs)
from frappe.utils.password import update_password
update_password("Administrator", "${ADMIN_PASSWORD}")
frappe.db.commit()
out = {
    "site": "${SITE_NAME}",
    "db_name": "${DB_NAME}",
    "desk_user": "Administrator",
    "desk_password": "${ADMIN_PASSWORD}",
    "api_key": keys.get("api_key"),
    "api_secret": keys.get("api_secret"),
}
open("${CREDS_OUT}", "w").write(json.dumps(out, indent=2) + "\n")
print(json.dumps(out, indent=2))
PY

echo "==> Credentials: ${CREDS_OUT}"
echo "==> Done provisioning ${SITE_NAME}"
