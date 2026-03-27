#!/bin/bash
# Update custom apps inside the running erpnext container and rebuild React.
# Run from the host: bash update-custom-apps.sh
# Or schedule via cron on the server.

set -e

COMPOSE_FILE="$(dirname "$0")/docker-compose.yml"
SITE_NAME="${SITE_NAME:-site.local}"

echo "Updating ERPNext custom app (quanteonlab/erp15)..."
docker compose -f "$COMPOSE_FILE" exec erpnext bash -c "
    set -e
    cd /home/frappe/frappe-bench

    # Pull latest from the custom ERPNext repo
    cd apps/erpnext
    git fetch origin
    git reset --hard origin/\${ERPNEXT_BRANCH:-main}
    cd ../..

    # Run migrations
    bench --site ${SITE_NAME} migrate

    # Rebuild JS/CSS assets
    bench build --app erpnext

    # Clear cache
    bench --site ${SITE_NAME} clear-cache

    echo 'ERPNext update complete.'
    bench --site ${SITE_NAME} list-apps
"

echo ""
echo "Rebuilding React frontend with latest source..."
docker compose -f "$COMPOSE_FILE" build --no-cache react
docker compose -f "$COMPOSE_FILE" up -d react

echo ""
echo "Done. All services restarted with latest code."
