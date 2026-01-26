# CapRover Template for ERPNext with Custom Apps

This directory contains the deployment template for ERPNext with custom apps on CapRover.

## Files

- `Dockerfile` - Docker image definition
- `entrypoint.sh` - Container startup script that handles initialization and app installation
- `captain-definition` - CapRover deployment configuration
- `.env` - Database configuration (PostgreSQL)
- `update-custom-apps.sh` - Helper script for updating custom apps (run inside container)

## Quick Start

1. **Set Environment Variables in CapRover** (use values from `.env`):
   ```env
   DB_HOST=134.199.185.35
   DB_PORT=5433
   DB_NAME=postgres
   DB_USER=directus
   DB_PASSWORD=f19eb7c1e52c49e4
   SITE_NAME=site.local
   ADMIN_PASSWORD=your-admin-password
   ERPNEXT_BRANCH=version-15
   CUSTOM_APPS_SOURCE=local
   CUSTOM_APPS_LOCAL="ecommerce_integrations rentals payments webshop airplane_mode_2"
   ```

2. **Deploy**:
   - If using Git: Push to repository, CapRover auto-deploys
   - If using tarball: Upload in CapRover dashboard

## Custom Apps Configuration

### Method 1: Local Apps (Recommended)

Apps are included in your repository's `apps/` directory:

```env
CUSTOM_APPS_SOURCE=local
CUSTOM_APPS_LOCAL="ecommerce_integrations rentals payments webshop airplane_mode_2"
```

**To Update**:
1. Make changes in `apps/your-app/`
2. Commit and push
3. CapRover auto-deploys

### Method 2: Git-based Apps

Apps are pulled from Git repositories:

```env
CUSTOM_APPS_SOURCE=git
CUSTOM_APPS_GIT="ecommerce_integrations|https://github.com/frappe/ecommerce_integrations|develop;payments|https://github.com/frappe/payments|develop"
```

**Format**: `APP_NAME|REPO_URL|BRANCH` (separated by semicolons)

**To Update**:
1. Change branch/commit in environment variables
2. Redeploy in CapRover

## Development Workflow: Creating & Deploying Custom Apps

This section covers the complete workflow for developing custom apps locally and deploying them to CapRover.

### Step 1: Create a New Custom App (Local Development)

```bash
# Navigate to your local bench
cd /path/to/your/frappe-bench

# Create a new app
bench new-app my_custom_app

# The app will be created in apps/my_custom_app/
```

### Step 2: Create DocTypes/Models

You can create DocTypes in two ways:

#### Option A: Via UI (Recommended for beginners)
1. Start your local bench: `bench start`
2. Open http://localhost:8000
3. Go to **Customize** → **DocType** → **New**
4. Create your DocType with fields
5. Save and commit

#### Option B: Via Command Line
```bash
# Create a new DocType
bench --site your-site-name make-doctype "My Custom DocType"

# This creates the DocType structure in your app
```

### Step 3: Develop Your App Locally

```bash
# Navigate to your app
cd apps/my_custom_app

# Make your changes:
# - Edit Python files in doctype/ folders
# - Edit JavaScript files for client-side logic
# - Edit JSON files for DocType definitions
# - Add custom scripts, reports, etc.
```

### Step 4: Run Migrations Locally

After creating or modifying DocTypes, run migrations:

```bash
# Run migrations for your site
bench --site your-site-name migrate

# Or migrate specific app
bench --site your-site-name migrate --app my_custom_app

# Build assets (if you changed JS/CSS)
bench build

# Restart bench to see changes
bench restart
```

### Step 5: Test Locally

```bash
# Start bench if not running
bench start

# Test your changes:
# - Access http://localhost:8000
# - Test your DocTypes, forms, reports
# - Verify functionality
```

### Step 6: Add App to Repository

Once your app is working locally:

```bash
# Make sure your app is in the apps/ directory of your repository
# The structure should be:
# your-repo/
#   apps/
#     my_custom_app/
#       my_custom_app/
#         ...

# Add app to apps.txt (if not already there)
echo "my_custom_app" >> sites/apps.txt

# Verify app structure
ls -la apps/my_custom_app/
```

### Step 7: Commit and Push to Git

```bash
# Navigate to your repository root
cd /path/to/your/repository

# Stage your changes
git add apps/my_custom_app/
git add sites/apps.txt  # If you added the app

# Commit with descriptive message
git commit -m "Add custom app: my_custom_app with DocTypes"

# Push to your repository
git push origin main  # or your branch name
```

### Step 8: Update CapRover Environment Variables

If this is a **new app**, add it to CapRover:

1. Go to CapRover dashboard
2. Select your ERPNext app
3. Go to **App Configs** tab
4. Update `CUSTOM_APPS_LOCAL` environment variable:
   ```env
   CUSTOM_APPS_LOCAL="ecommerce_integrations rentals payments webshop airplane_mode_2 my_custom_app"
   ```
5. Click **Save & Update**

### Step 9: CapRover Auto-Deployment

After pushing to Git:

1. **CapRover detects the push** (if webhook is configured)
2. **Or manually trigger**: Go to **Deployment** → **Save & Update**
3. **CapRover will**:
   - Pull latest code from Git
   - Rebuild Docker image
   - Run entrypoint.sh which will:
     - Copy your app from `apps/` directory
     - Install the app (if new)
     - Run migrations automatically
     - Build assets
     - Restart services

### Step 10: Verify Deployment

```bash
# Access CapRover App Terminal
# Check if app is installed
bench --site site.local list-apps

# Should show: my_custom_app

# Check migrations ran
bench --site site.local migrate

# View logs if needed
tail -f logs/web.log
```

## Complete Workflow Summary

**For New App:**
1. ✅ Create app locally: `bench new-app my_custom_app`
2. ✅ Develop DocTypes/models
3. ✅ Test locally: `bench migrate && bench build && bench restart`
4. ✅ Add to repository: `git add apps/my_custom_app/`
5. ✅ Commit: `git commit -m "Add my_custom_app"`
6. ✅ Push: `git push origin main`
7. ✅ Update CapRover env: Add app to `CUSTOM_APPS_LOCAL`
8. ✅ Deploy: CapRover auto-deploys or manual trigger
9. ✅ Verify: Check app is installed and working

**For Updating Existing App:**
1. ✅ Make changes locally in `apps/your-app/`
2. ✅ Test locally: `bench migrate && bench build && bench restart`
3. ✅ Commit: `git commit -m "Update your-app: description"`
4. ✅ Push: `git push origin main`
5. ✅ CapRover auto-deploys
6. ✅ Migrations run automatically on deployment

## Important Notes

- **Always test locally first** before pushing to production
- **Migrations run automatically** on CapRover deployment via entrypoint.sh
- **No need to manually run migrations** in CapRover if you push via Git
- **Build assets** are automatically rebuilt on deployment
- **App must be in `apps/` directory** of your repository for local apps method

## Updating Custom Apps

### Option 1: Automatic (via Git push)

1. Make changes to apps
2. Commit and push
3. CapRover detects changes and redeploys
4. Apps are automatically updated

### Option 2: Manual (inside container)

1. Access container terminal in CapRover
2. Run:
   ```bash
   /usr/local/bin/update-custom-apps.sh
   ```
   Or manually:
   ```bash
   cd /home/frappe/frappe-bench
   bench --site site.local migrate
   bench build
   bench restart
   ```

### Option 3: Via CapRover Redeploy

1. Update environment variables (if using Git-based apps)
2. Go to **Deployment** tab
3. Click **Save & Update**

## Environment Variables Reference

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DB_HOST` | PostgreSQL hostname | From `.env` | Yes |
| `DB_PORT` | PostgreSQL port | `5433` | No |
| `DB_NAME` | Database name | `postgres` | No |
| `DB_USER` | Database user | From `.env` | Yes |
| `DB_PASSWORD` | Database password | From `.env` | Yes |
| `SITE_NAME` | ERPNext site name | `site.local` | No |
| `ADMIN_PASSWORD` | ERPNext admin password | `admin` | No |
| `ERPNEXT_BRANCH` | ERPNext Git branch | `version-15` | No |
| `CUSTOM_APPS_SOURCE` | App source: `local` or `git` | `local` | No |
| `CUSTOM_APPS_LOCAL` | Space-separated list of local apps | See entrypoint.sh | No |
| `CUSTOM_APPS_GIT` | Git apps config (see format above) | - | No |

## Troubleshooting

### Apps Not Installing

1. Check **App Logs** in CapRover
2. Verify app names match actual app directories
3. For local apps: Ensure apps exist in repository's `apps/` directory
4. For Git apps: Verify repository URLs and branches

### Container Keeps Restarting

1. Check database connection:
   - Verify `DB_HOST`, `DB_USER`, and `DB_PASSWORD` from `.env`
   - Check PostgreSQL is accessible
   - Verify network connectivity

2. Check logs:
   ```bash
   # In CapRover App Terminal
   tail -f /home/frappe/frappe-bench/logs/web.log
   ```

### Build Failures

1. Increase memory limit (minimum 4GB)
2. Check Node.js compatibility
3. Review build logs for specific errors

## Manual Commands

Access container terminal in CapRover, then:

```bash
# Navigate to bench
cd /home/frappe/frappe-bench

# List apps
bench --site site.local list-apps

# Run migrations
bench --site site.local migrate

# Build assets
bench build

# Restart
bench restart

# Clear cache
bench --site site.local clear-cache

# Backup
bench --site site.local backup --with-files
```

## Quick Reference: Development Commands

### Local Development

```bash
# Create new app
bench new-app my_custom_app

# Create DocType
bench --site your-site-name make-doctype "My DocType"

# Run migrations
bench --site your-site-name migrate

# Build assets
bench build

# Restart services
bench restart

# Start development server
bench start
```

### Git Workflow

```bash
# After making changes locally
git add apps/my_custom_app/
git commit -m "Add/Update: description"
git push origin main

# CapRover will auto-deploy
```

### CapRover Deployment

```bash
# Check app is installed (in CapRover container)
bench --site site.local list-apps

# Run migrations manually (if needed)
bench --site site.local migrate

# Rebuild assets (if needed)
bench build

# Restart (if needed)
bench restart
```

## Support

For detailed deployment instructions, see: `../CAPROVER_DEPLOYMENT_GUIDE.md`
