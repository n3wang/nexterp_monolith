#!/usr/bin/env bash
# Run inside the erpnext container (or via: docker compose exec -T erpnext ...).
# Ensures legacy app shims exist, then migrates the site.
set -euo pipefail

SITE_NAME="${1:-${SITE_NAME:-site.local}}"
BENCH_DIR="/home/frappe/frappe-bench"
cd "$BENCH_DIR"

ensure_shim() {
	local app="$1"
	if ./env/bin/python -c "import ${app}" 2>/dev/null; then
		return 0
	fi

	echo "Creating/repairing shim for ${app}..."
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
	echo '__version__ = "0.0.1"' > "apps/${app}/${app}/__init__.py"
	cat > "apps/${app}/${app}/hooks.py" <<PYEOF
app_name = "${app}"
app_title = "${app}"
app_publisher = "local"
app_description = "Compatibility shim for installed app"
app_email = "noreply@example.com"
app_license = "MIT"
PYEOF
	./env/bin/pip install -e "apps/${app}" -q
}

ensure_shim rentals
ensure_shim airplane_mode_2

echo "Running bench migrate for ${SITE_NAME}..."
bench --site "$SITE_NAME" migrate
echo "bench migrate finished for ${SITE_NAME}."
