#!/usr/bin/env bash
# Migrate every Frappe site on the erpnext volume (site.local, meilu.local, …).
# Run from the host:
#   docker compose exec -T erpnext bash -s < scripts/migrate-all-sites.sh
# Or from inside the container:
#   bash /path/to/migrate-all-sites.sh
set -euo pipefail

BENCH_DIR="${BENCH_DIR:-/home/frappe/frappe-bench}"
cd "$BENCH_DIR"

# Prefer sibling script when piped from host; fall back to in-container copy.
MIGRATE_ONE="${MIGRATE_ONE:-}"
if [ -z "$MIGRATE_ONE" ]; then
	if [ -f "/usr/local/bin/bench-migrate.sh" ]; then
		MIGRATE_ONE="/usr/local/bin/bench-migrate.sh"
	elif [ -f "$(dirname "$0")/bench-migrate.sh" ]; then
		MIGRATE_ONE="$(dirname "$0")/bench-migrate.sh"
	else
		MIGRATE_ONE=""
	fi
fi

SITES=()
for d in sites/*/; do
	[ -d "$d" ] || continue
	name="$(basename "$d")"
	[ -f "sites/${name}/site_config.json" ] || continue
	SITES+=("$name")
done

if [ "${#SITES[@]}" -eq 0 ]; then
	echo "ERROR: no sites found under ${BENCH_DIR}/sites" >&2
	exit 1
fi

echo "==> Migrating ${#SITES[@]} site(s): ${SITES[*]}"
for site in "${SITES[@]}"; do
	echo ""
	echo "======== migrate ${site} ========"
	if [ -n "$MIGRATE_ONE" ] && [ -f "$MIGRATE_ONE" ]; then
		bash "$MIGRATE_ONE" "$site"
	else
		# Inline fallback (same shims as bench-migrate.sh)
		for app in rentals airplane_mode_2; do
			if ! ./env/bin/python -c "import ${app}" 2>/dev/null; then
				echo "Creating/repairing shim for ${app}..."
				mkdir -p "apps/${app}/${app}"
				cat > "apps/${app}/setup.py" <<PYEOF
from setuptools import setup, find_packages
setup(name="${app}", version="0.0.1", packages=find_packages(), include_package_data=True)
PYEOF
				echo '__version__ = "0.0.1"' > "apps/${app}/${app}/__init__.py"
				cat > "apps/${app}/${app}/hooks.py" <<PYEOF
app_name = "${app}"
app_title = "${app}"
app_publisher = "local"
app_description = "Compatibility shim"
app_email = "noreply@example.com"
app_license = "MIT"
PYEOF
				./env/bin/pip install -e "apps/${app}" -q
			fi
		done
		echo "Running bench migrate for ${site}..."
		bench --site "$site" migrate
		echo "bench migrate finished for ${site}."
	fi
done

echo ""
echo "==> All sites migrated: ${SITES[*]}"
