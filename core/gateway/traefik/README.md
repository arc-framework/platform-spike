# Traefik

**Status:** ✅ Active  
**Type:** Cloud-native API Gateway and Reverse Proxy

---

## Overview

Traefik serves as the API gateway and reverse proxy for the A.R.C. Framework, providing:

- **Dynamic Service Discovery** - Automatic configuration via Docker labels
- **Load Balancing** - Distribute traffic across service instances
- **SSL/TLS Termination** - Secure HTTPS endpoints
- **Request Routing** - Path-based and host-based routing
- **Middleware Support** - Authentication, rate limiting, compression
- **Dashboard** - Real-time monitoring and configuration visualization

---

## Configuration

### Static Configuration
The static configuration is defined in [`traefik.yml`](./traefik.yml):

- **Entry Points**: HTTP (`:80`) and HTTPS (`:443`)
- **API Dashboard**: Enabled for monitoring (insecure mode for local dev)
- **Docker Provider**: Watches Docker socket for automatic service discovery

### Dynamic Configuration
Services are configured using Docker labels in `docker-compose` files. Example:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myservice.rule=Host(`myservice.localhost`)"
  - "traefik.http.services.myservice.loadbalancer.server.port=8080"
```

### Environment Variables
Copy `.env.example` to `.env` and configure:

```bash
# Traefik configuration
TRAEFIK_LOG_LEVEL=INFO
TRAEFIK_API_DASHBOARD=true
```

---

## Usage

### Starting Traefik

```bash
# Start with the full stack
make up-stack

# Or start Traefik specifically
docker-compose -f docker-compose.stack.yml up traefik -d
```

### Accessing the Dashboard

Once running, access the Traefik dashboard at:
- **URL**: http://localhost:8080
- **Features**: View routers, services, middlewares, and active connections

### Service Discovery

Traefik automatically discovers services labeled with `traefik.enable=true`. Services are exposed based on their routing rules.

---

## Ports

| Port | Purpose |
|------|---------|
| `80` | HTTP entry point |
| `443` | HTTPS entry point |
| `8080` | Traefik dashboard |

---

## Health Check

Check Traefik health status:

```bash
curl http://localhost:8080/ping
```

---

## Troubleshooting

### View Traefik Logs
```bash
docker-compose -f docker-compose.stack.yml logs traefik
```

### Check Service Discovery
Visit the dashboard at http://localhost:8080 and navigate to:
- **HTTP Routers** - See all registered routes
- **Services** - View backend services and their health

### Common Issues

1. **Service not routing**: Check that Docker labels are correctly set
2. **Port conflicts**: Ensure ports 80, 443, and 8080 are available
3. **Docker socket permission**: Traefik needs access to `/var/run/docker.sock`

---

## See Also

- [Gateway Overview](../README.md)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Provider Configuration](https://doc.traefik.io/traefik/providers/docker/)
- [Operations Guide](../../../docs/OPERATIONS.md)

