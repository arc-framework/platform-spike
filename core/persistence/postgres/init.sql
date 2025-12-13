-- PostgreSQL initialization script for A.R.C. Platform
-- This script runs automatically when the container is first created.
-- The default database specified by POSTGRES_DB is created automatically.
-- This script is for any additional setup.

-- Create a default database matching the username (Postgres convention)
-- This prevents "database arc does not exist" errors when connecting without -d flag
CREATE DATABASE arc;
GRANT ALL PRIVILEGES ON DATABASE arc TO arc;

-- Create separate database for Infisical (secrets management)
-- This avoids table name conflicts with other services.
CREATE DATABASE infisical_db;
GRANT ALL PRIVILEGES ON DATABASE infisical_db TO arc;

-- Create separate database for Unleash (feature flags)
-- Keeps feature flag data isolated from application data.
CREATE DATABASE unleash_db;
GRANT ALL PRIVILEGES ON DATABASE unleash_db TO arc;

-- Example: Create an extension in the default database
-- \c arc_db;
-- CREATE EXTENSION IF NOT EXISTS vector;

SELECT 'PostgreSQL initialization complete' AS status;
