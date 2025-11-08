# Gateway
API Gateway and reverse proxy services for the A.R.C. Framework.
---
## Overview
The gateway layer provides:
- Unified entry point for all services
- Dynamic service discovery
- Load balancing
- SSL/TLS termination
- Request routing
---
## Implementations
### [Traefik](./traefik/)
**Status:** ✅ Active  
**Type:** Cloud-native API Gateway
- Automatic service discovery via Docker labels
- Dynamic configuration
- Let's Encrypt support
- Dashboard for monitoring
---
## Alternatives
The gateway is **swappable**. Alternative implementations:
- **Kong** - Plugin-based API gateway
- **Envoy** - CNCF service proxy
- **NGINX** - Traditional reverse proxy
- **Caddy** - Modern web server with auto-HTTPS
---
## See Also
- [Core Services](../README.md)
- [Operations Guide](../../docs/OPERATIONS.md)
