#!/bin/bash
set -e

# Configuration
SITE_NAME="${SITE_NAME:-site.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
ERPNEXT_BRANCH="${ERPNEXT_BRANCH:-version-15}"
CUSTOM_APPS_SOURCE="${CUSTOM_APPS_SOURCE:-local}"  # "local" or "git"

# Database configuration (from .env)
DB_HOST="${DB_HOST:-134.199.185.35}"
DB_PORT="${DB_PORT:-5433}"
DB_NAME="${DB_NAME:-postgres}"
DB_USER="${DB_USER:-directus}"
DB_PASSWORD="${DB_PASSWORD:-f19eb7c1e52c49e4}"

# Custom apps configuration (Git-based)
# Format: APP_NAME|REPO_URL|BRANCH (separated by semicolons)
# Example: "ecommerce_integrations|https://github.com/frappe/ecommerce_integrations|develop;payments|https://github.com/frappe/payments|develop"
CUSTOM_APPS_GIT="${CUSTOM_APPS_GIT:-}"

# Custom apps list (for local installation)
# Apps in this list will be installed from /apps directory if they exist
# Format: space-separated list
CUSTOM_APPS_LOCAL="${CUSTOM_APPS_LOCAL:-ecommerce_integrations rentals payments webshop airplane_mode_2}"

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL at $DB_HOST:$DB_PORT..."
export PGPASSWORD="$DB_PASSWORD"
until psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; do
    echo "⏳ Still waiting for PostgreSQL..."
    sleep 2
done
echo "✅ PostgreSQL is ready"

# Function to install custom app from Git
install_app_from_git() {
    local app_name=$1
    local repo_url=$2
    local branch=$3
    
    echo "📦 Installing $app_name from Git ($repo_url, branch: $branch)..."
    
    if [ -d "apps/$app_name" ]; then
        echo "⚠️  App $app_name already exists, updating..."
        cd apps/$app_name
        git fetch origin
        git checkout "$branch" || git checkout -b "$branch" origin/"$branch"
        git pull origin "$branch" || true
        cd ../..
    else
        bench get-app "$app_name" "$repo_url" --branch "$branch" || {
            echo "❌ Failed to get app $app_name from $repo_url"
            return 1
        }
    fi
    
    if ! bench --site "$SITE_NAME" list-apps | grep -q "^$app_name$"; then
        echo "🔧 Installing $app_name on site..."
        bench --site "$SITE_NAME" install-app "$app_name" || {
            echo "⚠️  Failed to install $app_name, continuing..."
        }
    else
        echo "✅ $app_name already installed, running migrations..."
        bench --site "$SITE_NAME" migrate || true
    fi
}

# Function to install custom app from local directory
install_app_from_local() {
    local app_name=$1
    
    echo "📦 Installing $app_name from local apps directory..."
    
    # Check if app exists in /apps directory (mounted volume or copied during build)
    if [ -d "/apps/$app_name" ]; then
        echo "📂 Found $app_name in /apps directory, copying..."
        cp -r "/apps/$app_name" "apps/"
    elif [ -d "../apps/$app_name" ]; then
        echo "📂 Found $app_name in ../apps directory, copying..."
        cp -r "../apps/$app_name" "apps/"
    elif [ -d "apps/$app_name" ]; then
        echo "✅ $app_name already in apps directory"
    else
        echo "⚠️  App $app_name not found in local directories, skipping..."
        return 1
    fi
    
    # Add to apps.txt if not already present
    if ! grep -q "^$app_name$" sites/apps.txt; then
        echo "$app_name" >> sites/apps.txt
    fi
    
    if ! bench --site "$SITE_NAME" list-apps | grep -q "^$app_name$"; then
        echo "🔧 Installing $app_name on site..."
        bench --site "$SITE_NAME" install-app "$app_name" || {
            echo "⚠️  Failed to install $app_name, continuing..."
        }
    else
        echo "✅ $app_name already installed, running migrations..."
        bench --site "$SITE_NAME" migrate || true
    fi
}

# Continue with ERPNext setup
cd /home/frappe

if [ ! -d "frappe-bench" ]; then
  echo "🚀 Initializing Frappe bench..."
  bench init frappe-bench --frappe-branch version-15 --python python3.11
  cd frappe-bench
  
  echo "🌐 Creating site $SITE_NAME..."
  bench new-site "$SITE_NAME" \
    --admin-password "$ADMIN_PASSWORD" \
    --db-host "$DB_HOST" \
    --db-port "$DB_PORT" \
    --db-name "$DB_NAME" \
    --db-username "$DB_USER" \
    --db-password "$DB_PASSWORD"
  
  echo "📦 Installing ERPNext..."
  bench get-app erpnext --branch "$ERPNEXT_BRANCH"
  bench --site "$SITE_NAME" install-app erpnext
  
  # Install custom apps
  echo "🔧 Installing custom apps..."
  
  if [ "$CUSTOM_APPS_SOURCE" = "git" ] && [ -n "$CUSTOM_APPS_GIT" ]; then
    # Install from Git repositories
    IFS=';' read -ra APPS <<< "$CUSTOM_APPS_GIT"
    for app_config in "${APPS[@]}"; do
      IFS='|' read -ra APP_PARTS <<< "$app_config"
      if [ ${#APP_PARTS[@]} -eq 3 ]; then
        install_app_from_git "${APP_PARTS[0]}" "${APP_PARTS[1]}" "${APP_PARTS[2]}"
      fi
    done
  else
    # Install from local apps directory
    for app_name in $CUSTOM_APPS_LOCAL; do
      install_app_from_local "$app_name"
    done
  fi
  
  echo "🏗️  Building assets..."
  bench build
else
  echo "✅ Frappe bench already exists, updating..."
  cd frappe-bench
  
  # Update existing installation
  echo "🔄 Updating ERPNext..."
  if [ -d "apps/erpnext" ]; then
    cd apps/erpnext
    git fetch origin
    git checkout "$ERPNEXT_BRANCH" || true
    git pull origin "$ERPNEXT_BRANCH" || true
    cd ../..
  fi
  
  # Update custom apps
  echo "🔄 Updating custom apps..."
  
  if [ "$CUSTOM_APPS_SOURCE" = "git" ] && [ -n "$CUSTOM_APPS_GIT" ]; then
    # Update from Git repositories
    IFS=';' read -ra APPS <<< "$CUSTOM_APPS_GIT"
    for app_config in "${APPS[@]}"; do
      IFS='|' read -ra APP_PARTS <<< "$app_config"
      if [ ${#APP_PARTS[@]} -eq 3 ]; then
        install_app_from_git "${APP_PARTS[0]}" "${APP_PARTS[1]}" "${APP_PARTS[2]}"
      fi
    done
  else
    # Update from local apps directory
    for app_name in $CUSTOM_APPS_LOCAL; do
      install_app_from_local "$app_name"
    done
  fi
  
  echo "🔄 Running migrations..."
  bench --site "$SITE_NAME" migrate || true
  
  echo "🏗️  Rebuilding assets..."
  bench build || true
fi

echo "✅ Setup complete! Starting ERPNext..."
bench use "$SITE_NAME"
bench start
