# Deployments

Environment-specific infrastructure definitions.

## Structure

### `docker/`

Compose files broken down by responsibility:

- `docker-compose.base.yml` – Shared volumes, networks, and extension blocks
- `docker-compose.core.yml` – Required core services (Traefik, Postgres, Redis, NATS, Pulsar, Infisical, Unleash, OpenTelemetry Collector)
- `docker-compose.observability.yml` – Observability stack (Loki, Prometheus, Jaeger, Grafana)
- `docker-compose.security.yml` – Security plugins (Kratos)
- `docker-compose.services.yml` – Application workloads (currently the toolbox utility)

Combine these files through the provided Make targets or by composing them manually. Examples:

```bash
# Minimal core footprint (~2 GB RAM)
make up-minimal

# Core + observability stack
make up-observability

# Full platform (core + observability + security + services)
make up
```

### `kubernetes/`

Reserved for future Kubernetes manifests (empty placeholder).

### `terraform/`

Reserved for Infrastructure-as-Code definitions (empty placeholder).

## Tips

- Use `make info` after starting the stack to view service URLs and credentials.
- Override environment variables via `.env` or `ENV_FILE` before launching compose bundles.
- See `deployments/docker/README.md` for deep dives into each profile and resource footprint.
