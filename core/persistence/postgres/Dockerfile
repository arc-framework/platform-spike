# ==============================================================================
# A.R.C. Framework - PostgreSQL with pgvector
# ==============================================================================
# Service: arc-oracle-sql
# Role: The Knowledge Keeper
# Base: Official pgvector image with PostgreSQL 16
# ==============================================================================

FROM pgvector/pgvector:pg16

LABEL org.opencontainers.image.title="arc-oracle-sql"
LABEL org.opencontainers.image.description="PostgreSQL 16 with pgvector extension for A.R.C. Framework"
LABEL org.opencontainers.image.vendor="A.R.C. Framework"
LABEL arc.service.codename="oracle"
LABEL arc.service.role="The Knowledge Keeper"
LABEL arc.service.layer="core"

# Install additional tools for health checks and debugging (Debian-based)
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Copy initialization scripts
# These will run automatically on first container startup
COPY init.sql /docker-entrypoint-initdb.d/01-init.sql

# Expose PostgreSQL port
EXPOSE 5432

# Use the default postgres entrypoint
# No need to override - the base image handles everything
