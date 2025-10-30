#!/bin/bash
set -e

# Set default database type to postgres if not specified
DB_TYPE=${DB_TYPE:-postgres}

if [ "$DB_TYPE" = "postgres" ]; then
    # Wait for PostgreSQL to be ready
    echo "⏳ Waiting for PostgreSQL at $DB_HOST..."
    until PGPASSWORD="$DB_ROOT_PASSWORD" psql -h "$DB_HOST" -U "$DB_ROOT_USER" -d postgres -c "SELECT 1;" &>/dev/null; do
        echo "⏳ Still waiting for PostgreSQL..."
        sleep 2
    done
    echo "✅ PostgreSQL is ready"
else
    # Wait for MariaDB to be ready
    echo "⏳ Waiting for MariaDB at $DB_HOST..."
    until mysql -h"$DB_HOST" -uroot -p"$DB_ROOT_PASSWORD" -e "SELECT 1;" &>/dev/null; do
        echo "⏳ Still waiting for MariaDB..."
        sleep 2
    done

    # Create frappe user if it doesn't exist
    echo "🔧 Creating MariaDB user 'frappe'... at $DB_HOST"
    mysql -h"$DB_HOST" -uroot -p"$DB_ROOT_PASSWORD" <<-EOSQL
        CREATE USER IF NOT EXISTS 'frappe'@'%' IDENTIFIED BY 'frappe';
        GRANT ALL PRIVILEGES ON *.* TO 'frappe'@'%' WITH GRANT OPTION;
        FLUSH PRIVILEGES;
EOSQL
fi

# Continue with ERPNext setup
cd /home/frappe

if [ ! -d "frappe-bench" ]; then
  bench init frappe-bench --frappe-branch version-15 --python python3.11
  cd frappe-bench

  if [ "$DB_TYPE" = "postgres" ]; then
    bench new-site site.local \
      --admin-password admin \
      --db-type postgres \
      --db-host "$DB_HOST" \
      --db-port "${DB_PORT:-5432}" \
      --db-name "${DB_NAME:-erpnext}" \
      --db-password "$DB_ROOT_PASSWORD" \
      --db-root-username "${DB_ROOT_USER:-postgres}" \
      --db-root-password "$DB_ROOT_PASSWORD"
  else
    bench new-site site.local \
      --admin-password admin \
      --mariadb-root-password "$DB_ROOT_PASSWORD" \
      --db-host "$DB_HOST" \
      --mariadb-root-username root
  fi

  bench get-app erpnext --branch version-15
  bench --site site.local install-app erpnext
  bench build
else
  cd frappe-bench
fi

bench use site.local
bench serve --port 8080 --host 0.0.0.0
