-- PostgreSQL initialization script for A.R.C. Platform
-- This script runs automatically when the container is first created

-- Create default database if not exists (already created via POSTGRES_DB)
-- CREATE DATABASE IF NOT EXISTS arc_db;

-- You can add additional initialization here:
-- - Create additional databases
-- - Create users
-- - Set up schemas
-- - Install extensions (if available in the image)

-- Example: Create a schema
-- CREATE SCHEMA IF NOT EXISTS app;

-- Example: Create a user (if needed beyond POSTGRES_USER)
-- CREATE USER app_user WITH PASSWORD 'change_me';
-- GRANT ALL PRIVILEGES ON DATABASE arc_db TO app_user;

SELECT 'PostgreSQL initialization complete' AS status;

