# ==============================================================================
# A.R.C. Framework - Identity & Authentication (Kratos)
# ==============================================================================
# Service: arc-deckard-identity
# Role: The Authenticator
# Base: Ory Kratos
# ==============================================================================

FROM oryd/kratos:v1.3.0-alpine

LABEL org.opencontainers.image.title="arc-deckard-identity" \
      org.opencontainers.image.description="Ory Kratos identity and authentication service for A.R.C. Framework" \
      org.opencontainers.image.vendor="A.R.C. Framework" \
      arc.service.codename="deckard" \
      arc.service.role="The Authenticator" \
      arc.service.layer="plugin" \
      arc.service.category="security"

# Switch to root to copy and set permissions
USER root

# Copy entrypoint script for auto-migrations
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Switch back to ory user (uid 1000)
USER ory

# Configuration is mounted at runtime via volume
# See: deployments/docker/docker-compose.security.yml

# Expose Kratos ports
EXPOSE 4433 4434

# Use custom entrypoint for auto-migrations
ENTRYPOINT ["/entrypoint.sh"]

# Default command (can be overridden in docker-compose)
CMD ["kratos", "serve", "-c", "/etc/config/kratos/kratos.yml", "--dev", "--watch-courier"]
