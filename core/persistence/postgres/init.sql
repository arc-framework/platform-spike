-- PostgreSQL initialization script for A.R.C. Platform
-- This script runs automatically when the container is first created.
-- The default database specified by POSTGRES_DB is created automatically.
-- This script is for any additional setup.

-- Create separate database for Infisical (secrets management)
-- This avoids table name conflicts with other services.
CREATE DATABASE infisical_db;

-- Example: Create an extension in the default database
-- \c arc_db;
-- CREATE EXTENSION IF NOT EXISTS vector;

SELECT 'PostgreSQL initialization complete' AS status;
