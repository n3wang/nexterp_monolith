#!/usr/bin/env bash
# Finish company setup + seed + API keys for an existing site.
# Usage inside erpnext container:
#   bash finish-branded-site.sh meilu.local Meilu ML 'MeiluAdmin!2026'
set -euo pipefail

SITE="${1:?site}"
COMPANY_NAME="${2:?company name}"
COMPANY_ABBR="${3:?abbr}"
ADMIN_PASS="${4:?admin password}"
ITEM_COUNT="${ITEM_COUNT:-40}"
BENCH_DIR="${BENCH_DIR:-/home/frappe/frappe-bench}"
cd "$BENCH_DIR"

mkdir -p \
  /home/frappe/logs \
  "$BENCH_DIR/logs" \
  "$BENCH_DIR/sites/$SITE/logs" \
  "$BENCH_DIR/$SITE/logs"

YEAR="$(date +%Y)"
CREDS_OUT="/tmp/site-credentials-${SITE}.json"

./env/bin/python - <<PY
import json, os
from datetime import datetime
import frappe

os.makedirs("/home/frappe/logs", exist_ok=True)
os.makedirs("${BENCH_DIR}/sites/${SITE}/logs", exist_ok=True)
os.makedirs("${BENCH_DIR}/${SITE}/logs", exist_ok=True)

frappe.init(site="${SITE}", sites_path="${BENCH_DIR}/sites")
# Patch logger path issues before connect
try:
    frappe.connect()
except FileNotFoundError:
    os.makedirs("${BENCH_DIR}/${SITE}/logs", exist_ok=True)
    os.makedirs("${BENCH_DIR}/sites/${SITE}/logs", exist_ok=True)
    frappe.connect()

frappe.set_user("Administrator")

# 1) Company / CoA
if not frappe.db.a_row_exists("Company"):
    from erpnext.setup.setup_wizard.setup_wizard import setup_complete
    from frappe import _dict
    setup_complete(_dict({
        "currency": "USD",
        "full_name": "Administrator",
        "company_name": "${COMPANY_NAME}",
        "timezone": "America/Argentina/Buenos_Aires",
        "company_abbr": "${COMPANY_ABBR}",
        "industry": "Retail",
        "country": "Argentina",
        "fy_start_date": "${YEAR}-01-01",
        "fy_end_date": "${YEAR}-12-31",
        "language": "english",
        "company_tagline": "${COMPANY_NAME}",
        "email": "admin@${SITE}",
        "password": "${ADMIN_PASS}",
        "chart_of_accounts": "Standard",
    }))
    frappe.db.commit()
    print("setup_complete: created company ${COMPANY_NAME}")
else:
    print("setup_complete: company already exists:", frappe.db.get_value("Company", {}, "name"))

# 2) Staff groups
from erpnext.erpnext_integrations.ecommerce_api.employee_api import ensure_starter_staff_groups
print("staff_groups:", ensure_starter_staff_groups())
frappe.db.commit()

# 3) Seed demo catalog
from erpnext.erpnext_integrations.ecommerce_api.seed_full_erpnext_test_data import run as seed_run
seed_result = seed_run(item_count=${ITEM_COUNT}, disabled_count=3, stock_item_ratio=0.75)
frappe.db.commit()
print("seed:", json.dumps({k: seed_result.get(k) for k in ("status", "company") if k in seed_result}, default=str))
print("items:", frappe.db.count("Item"), "companies:", frappe.db.count("Company"))

# 4) API keys + password
from frappe.core.doctype.user.user import generate_keys
from frappe.utils.password import update_password
keys = generate_keys("Administrator")
update_password("Administrator", "${ADMIN_PASS}")
frappe.db.commit()

out = {
    "site": "${SITE}",
    "desk_user": "Administrator",
    "desk_password": "${ADMIN_PASS}",
    "company": frappe.db.get_value("Company", {}, "name"),
    "item_count": frappe.db.count("Item"),
    "api_key": keys.get("api_key"),
    "api_secret": keys.get("api_secret"),
}
open("${CREDS_OUT}", "w").write(json.dumps(out, indent=2) + "\n")
print(json.dumps(out, indent=2))
print("DONE ${SITE}")
PY
