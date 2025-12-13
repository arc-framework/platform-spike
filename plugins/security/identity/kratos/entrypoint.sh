#!/bin/sh
set -e

echo "🔧 A.R.C. Kratos - Starting initialization..."

# Wait for config file to be available (volume mount)
echo "⏳ Waiting for configuration file..."
while [ ! -f /etc/config/kratos/kratos.yml ]; do
  echo "   Config file not found, retrying in 1s..."
  sleep 1
done

echo "✅ Configuration found"

# Extract database connection details from DSN for health check
# DSN format: postgres://user:pass@host:port/dbname?params
DB_HOST=$(echo "$DSN" | sed -n 's/.*@\([^:]*\):.*/\1/p')
DB_PORT=$(echo "$DSN" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')

echo "⏳ Waiting for database connection ($DB_HOST:$DB_PORT)..."
MAX_RETRIES=30
RETRY_COUNT=0

# Use nc (netcat) to test if PostgreSQL port is open
while ! nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "❌ Failed to connect to database after $MAX_RETRIES attempts"
    exit 1
  fi
  echo "   Database not ready (attempt $RETRY_COUNT/$MAX_RETRIES), retrying in 2s..."
  sleep 2
done

echo "✅ Database is reachable!"
echo "🔄 Running database migrations..."
kratos migrate sql -e --yes -c /etc/config/kratos/kratos.yml

echo "✅ Migrations complete!"

echo "✅ Migrations complete. Starting Kratos..."
exec "$@"
