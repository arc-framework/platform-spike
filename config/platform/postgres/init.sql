-- Create the pgvector extension for Postgres (used by A.R.C. memory/RAG features)
-- This script will run on first container start when mounted into /docker-entrypoint-initdb.d/

CREATE EXTENSION IF NOT EXISTS vector;

