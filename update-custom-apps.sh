#!/bin/bash
# Helper script to update custom apps in CapRover deployment
# This script can be run inside the container or used as a reference

set -e

SITE_NAME="${SITE_NAME:-site.local}"
CUSTOM_APPS="${CUSTOM_APPS:-ecommerce_integrations rentals payments webshop airplane_mode_2}"

echo "🔄 Updating custom apps for site: $SITE_NAME"

cd /home/frappe/frappe-bench

for app_name in $CUSTOM_APPS; do
    echo ""
    echo "📦 Processing $app_name..."
    
    if [ -d "apps/$app_name" ]; then
        echo "  ✅ App found in apps directory"
        
        # Check if it's a git repository
        if [ -d "apps/$app_name/.git" ]; then
            echo "  🔄 Updating from Git..."
            cd apps/$app_name
            git fetch origin
            CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
            echo "  📍 Current branch: $CURRENT_BRANCH"
            git pull origin "$CURRENT_BRANCH" || echo "  ⚠️  Git pull failed, continuing..."
            cd ../..
        else
            echo "  ℹ️  App is not a Git repository (local copy)"
        fi
        
        # Run migrations for the app
        echo "  🔄 Running migrations..."
        bench --site "$SITE_NAME" migrate --app "$app_name" || echo "  ⚠️  Migration failed, continuing..."
        
        # Check if app is installed
        if bench --site "$SITE_NAME" list-apps | grep -q "^$app_name$"; then
            echo "  ✅ App is installed"
        else
            echo "  🔧 Installing app..."
            bench --site "$SITE_NAME" install-app "$app_name" || echo "  ⚠️  Installation failed, continuing..."
        fi
    else
        echo "  ⚠️  App not found in apps directory, skipping..."
    fi
done

echo ""
echo "🏗️  Rebuilding assets..."
bench build || echo "⚠️  Build failed, continuing..."

echo ""
echo "🧹 Clearing cache..."
bench --site "$SITE_NAME" clear-cache

echo ""
echo "✅ Custom apps update complete!"
echo ""
echo "📋 Installed apps:"
bench --site "$SITE_NAME" list-apps
